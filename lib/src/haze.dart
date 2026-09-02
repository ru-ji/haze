import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Which edge of the [Haze] rectangle the blur is strongest at.
enum HazeEdge { top, bottom, left, right }

/// A progressive (gradient) blur: a Gaussian over the backdrop, full strength
/// at one edge and dissolving to nothing at the other — plus an optional tint
/// wash on the exact same falloff.
///
/// The blur is untouched from 0.1.1 — cosine falloff, linear sigma, 3-sigma
/// radius, one tap per texel. Several "improvements" were measured against it
/// (a plateau, a smootherstep tail, exponential shaping of sigma, bilinear
/// tap pairing, cross-fading a fixed blur) and every one of them was worse in
/// the hand.
///
/// Only the TINT's shape changed: it takes an optional [plateau] at full
/// strength before its fade. An alpha can sit at full and then drop away with
/// nothing to give the drop away; a blur held at full radius has to shed all
/// of it in what is left of the span, and the moment the heavy blur ends
/// becomes an edge of its own. What makes an alpha fade invisible is not what
/// makes a radius ramp invisible.
///
/// This is iOS 26's "scroll edge effect" as a standalone widget: put it in a
/// [Stack] over an image, a scrolling list, or behind a navigation bar.
///
/// ```dart
/// Stack(children: [
///   Image.network(url, fit: BoxFit.cover),
///   Positioned(left: 0, right: 0, bottom: 0, height: 140,
///     child: Haze(
///       edge: HazeEdge.bottom,
///       sigma: 20,
///       tint: CupertinoColors.black,
///       tintOpacity: 0.45,
///       child: Padding(padding: EdgeInsets.all(20), child: Text('Big Sur')),
///     )),
/// ])
/// ```
///
/// Under the hood two [BackdropFilter] layers run a separable fragment
/// shader ([ui.ImageFilter.shader]); sampling is bounded to the widget's own
/// rectangle so nothing outside it can smear in. On platforms without shader
/// image filters (non-Impeller), stacked fixed-sigma blurs approximate the
/// falloff instead.
class Haze extends StatefulWidget {
  const Haze({
    super.key,
    this.edge = HazeEdge.top,
    this.sigma = 12,
    this.tint,
    this.tintOpacity = 0.4,
    this.falloff = 1.5,
    this.plateau = 0.0,
    this.extent = 0.97,
    this.borderRadius,
    this.enabled = true,
    this.child,
  }) : assert(sigma >= 0),
       assert(falloff > 0),
       assert(plateau >= 0 && plateau < 1),
       assert(extent > 0 && extent <= 1),
       assert(tintOpacity >= 0 && tintOpacity <= 1);

  /// The edge the blur (and tint) is strongest at.
  final HazeEdge edge;

  /// Peak blur radius at [edge], in logical pixels. Falls to 0 along the
  /// falloff.
  final double sigma;

  /// Colour of the wash painted on top of the blur, on the same falloff.
  /// Null paints no tint (blur only).
  final Color? tint;

  /// Peak opacity of [tint] at [edge].
  final double tintOpacity;

  /// Falloff exponent. 1 is a plain cosine; higher values keep the blur
  /// tighter to [edge]; lower values spread it further in.
  final double falloff;

  /// Fraction of the span the TINT is held at full strength before it starts
  /// to fade, 0–1. This is the shape of iOS's scroll edge effect: constant
  /// over the bar itself, then a fade whose start is as undetectable as its
  /// end. 0 (the default) starts fading at the very edge.
  ///
  /// Tint only. The blur keeps the plain cosine falloff, and wants to: an
  /// alpha can sit at full strength and then drop away with nothing to give
  /// the drop away, but a blur held at full radius has to shed all of it in
  /// whatever span is left, and the moment the heavy blur ends becomes an
  /// edge of its own.
  final double plateau;

  /// Fraction of the widget the falloff spans, 0–1. 1 means the blur only
  /// reaches zero exactly at the far side; the default leaves a thin dead
  /// zone so the effect's boundary never coincides with a live blur (which
  /// shows up as a faint line).
  final double extent;

  /// Rounds the effect's own clip — match it to the card underneath.
  final BorderRadius? borderRadius;

  /// When false the widget paints [child] only. Cheaper than swapping the
  /// widget out, and keeps layout identical.
  final bool enabled;

  /// Painted above the effect, e.g. the text the blur exists to make legible.
  final Widget? child;

  @override
  State<Haze> createState() => _HazeState();
}

class _HazeState extends State<Haze> with SingleTickerProviderStateMixin {
  static const String _shaderAsset = 'packages/haze/shaders/haze.frag';

  static ui.FragmentProgram? _cachedProgram;
  static Future<ui.FragmentProgram?>? _programFuture;

  ui.FragmentShader? _horizontalPass;
  ui.FragmentShader? _verticalPass;
  ModalRoute<Object?>? _route;

  /// Reaches the blur render object so route transitions can repaint it: its
  /// sampling bounds are in screen coordinates and must track the sliding
  /// page — see [_onRouteTick].
  final GlobalKey _blurKey = GlobalKey();

  /// Ramps the sigma back up when a route transition ends, so the blur eases
  /// in instead of popping the moment the page lands.
  late final AnimationController _fadeIn;

  @override
  void initState() {
    super.initState();
    _fadeIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1,
    );
    final program = _cachedProgram;
    if (program != null) {
      _horizontalPass = program.fragmentShader();
      _verticalPass = program.fragmentShader();
    } else if (ui.ImageFilter.isShaderFilterSupported) {
      _loadProgram();
    }
  }

  void _loadProgram() {
    _programFuture ??= () async {
      try {
        return await ui.FragmentProgram.fromAsset(_shaderAsset);
      } catch (_) {
        try {
          // Running from within this package itself (tests).
          return await ui.FragmentProgram.fromAsset('shaders/haze.frag');
        } catch (_) {
          return null; // Fallback slices take over permanently.
        }
      }
    }();
    _programFuture!.then((program) {
      _cachedProgram = program;
      if (program == null || !mounted) return;
      setState(() {
        _horizontalPass = program.fragmentShader();
        _verticalPass = program.fragmentShader();
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (!identical(route, _route)) {
      _detachRouteListeners();
      _route = route;
      route?.animation?.addListener(_onRouteTick);
      route?.secondaryAnimation?.addListener(_onRouteTick);
    }
  }

  void _detachRouteListeners() {
    _route?.animation?.removeListener(_onRouteTick);
    _route?.secondaryAnimation?.removeListener(_onRouteTick);
  }

  /// Whether the enclosing route is mid-push/pop/back-swipe.
  bool _transitioning = false;

  static bool _moving(Animation<double>? a) =>
      a != null && a.value > 0 && a.value < 1;

  /// The enclosing route is sliding. The page's screen position changes
  /// without any layout, so the blur wouldn't repaint on its own — repaint it
  /// each tick to keep its bounds current.
  void _onRouteTick() {
    _blurKey.currentContext?.findRenderObject()?.markNeedsPaint();
    final transitioning =
        _moving(_route?.animation) || _moving(_route?.secondaryAnimation);
    if (transitioning != _transitioning && mounted) {
      setState(() => _transitioning = transitioning);
      if (transitioning) {
        _fadeIn.value = 0;
      } else {
        _fadeIn.forward();
      }
    }
  }

  @override
  void dispose() {
    _fadeIn.dispose();
    _detachRouteListeners();
    _horizontalPass?.dispose();
    _verticalPass?.dispose();
    super.dispose();
  }

  /// The TINT's curve: an optional plateau at full strength, then a
  /// smootherstep whose first and second derivatives are zero at both ends —
  /// neither where the fade begins nor where it dies is detectable.
  ///
  /// The blur runs the shader's cosine instead, unchanged from 0.1.1.
  static double falloffAt(double t, double plateau, double power) {
    final x = ((t - plateau) / math.max(1 - plateau, 1e-3)).clamp(0.0, 1.0);
    final s = 1 - x * x * x * (x * (x * 6 - 15) + 10);
    return math.pow(s, power).toDouble();
  }

  /// The tint wash: [plateau] then smootherstep, sharing the blur's exponent
  /// and extent so the two still die together.
  Widget? _buildWash() {
    final tint = widget.tint;
    if (tint == null || widget.tintOpacity == 0) return null;
    // Enough steps that the gradient's own quantisation can't reintroduce
    // the banding the curve exists to remove.
    const steps = 30;
    double alphaAt(double t) =>
        widget.tintOpacity * falloffAt(t, widget.plateau, widget.falloff);
    final (begin, end) = switch (widget.edge) {
      HazeEdge.top => (Alignment.topCenter, Alignment.bottomCenter),
      HazeEdge.bottom => (Alignment.bottomCenter, Alignment.topCenter),
      HazeEdge.left => (Alignment.centerLeft, Alignment.centerRight),
      HazeEdge.right => (Alignment.centerRight, Alignment.centerLeft),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors: [
            for (var i = 0; i <= steps; i++)
              tint.withValues(alpha: alphaAt(i / steps)),
            tint.withValues(alpha: 0),
          ],
          stops: [
            for (var i = 0; i <= steps; i++) (i / steps) * widget.extent,
            1.0,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child ?? const SizedBox.expand();

    final wash = _buildWash();
    final hPass = _horizontalPass;
    final vPass = _verticalPass;
    final blurred =
        widget.sigma > 0 &&
        !_transitioning &&
        ui.ImageFilter.isShaderFilterSupported &&
        hPass != null &&
        vPass != null;

    // While the route slides, the tint carries the effect alone: a backdrop
    // filter sampling a scene that is being transformed mid-flight picks up
    // the seam where the sliding page's backdrop ends — a hard line across
    // the effect. Nothing is scrolling during a transition anyway.
    // It eases back in over [_fadeIn] once the page lands, so it never pops.
    final content = Stack(
      fit: StackFit.expand,
      children: [
        if (blurred)
          AnimatedBuilder(
            animation: _fadeIn,
            builder: (context, _) => _ShaderHaze(
              key: _blurKey,
              horizontalPass: hPass,
              verticalPass: vPass,
              sigma: widget.sigma * _fadeIn.value,
              edge: widget.edge,
              falloff: widget.falloff,
              extent: widget.extent,
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            ),
          )
        else if (widget.sigma > 0 && !_transitioning)
          _SlicesFallback(
            sigma: widget.sigma,
            edge: widget.edge,
            falloff: widget.falloff,
            extent: widget.extent,
          ),
        if (wash != null) IgnorePointer(child: wash),
        if (widget.child != null) widget.child!,
      ],
    );

    final radius = widget.borderRadius;
    return radius == null
        ? ClipRect(child: content)
        : ClipRRect(borderRadius: radius, child: content);
  }
}

/// Pre-Impeller fallback: slices of increasing fixed backdrop blur toward the
/// edge approximate the shader's continuous falloff.
class _SlicesFallback extends StatelessWidget {
  const _SlicesFallback({
    required this.sigma,
    required this.edge,
    required this.falloff,
    required this.extent,
  });

  final double sigma;
  final HazeEdge edge;
  final double falloff;
  final double extent;

  static const int _slices = 8;

  @override
  Widget build(BuildContext context) {
    final vertical = edge == HazeEdge.top || edge == HazeEdge.bottom;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final span = vertical ? constraints.maxHeight : constraints.maxWidth;
          final sliceSize = span / _slices;
          return Stack(
            fit: StackFit.expand,
            children: [
              for (var i = 0; i < _slices; i++)
                Positioned(
                  top: edge == HazeEdge.bottom
                      ? null
                      : (vertical ? i * sliceSize : 0),
                  bottom: edge == HazeEdge.bottom
                      ? i * sliceSize
                      : (vertical ? null : 0),
                  left: edge == HazeEdge.right
                      ? null
                      : (vertical ? 0 : i * sliceSize),
                  right: edge == HazeEdge.right
                      ? i * sliceSize
                      : (vertical ? 0 : null),
                  height: vertical ? sliceSize + 0.5 : null,
                  width: vertical ? null : sliceSize + 0.5,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(
                        sigmaX: _sigmaFor(i),
                        sigmaY: _sigmaFor(i),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// The shader's cosine falloff sampled at the slice's center.
  double _sigmaFor(int i) {
    final t = ((i + 0.5) / _slices / extent).clamp(0.0, 1.0);
    return sigma * math.pow(math.cos(t * math.pi / 2), falloff).toDouble();
  }
}

/// The two-pass shader blur as a render object: the shader's sampling bounds
/// (screen coordinates) are computed in [paint], so they are correct on every
/// painted frame — while a header collapses under a scroll, and while the
/// page slides during a route transition — instead of freezing at whatever
/// they were on the last rebuild.
class _ShaderHaze extends LeafRenderObjectWidget {
  const _ShaderHaze({
    super.key,
    required this.horizontalPass,
    required this.verticalPass,
    required this.sigma,
    required this.edge,
    required this.falloff,
    required this.extent,
    required this.devicePixelRatio,
  });

  final ui.FragmentShader horizontalPass;
  final ui.FragmentShader verticalPass;
  final double sigma;
  final HazeEdge edge;
  final double falloff;
  final double extent;
  final double devicePixelRatio;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderShaderHaze(
    horizontalPass: horizontalPass,
    verticalPass: verticalPass,
    sigma: sigma,
    edge: edge,
    falloff: falloff,
    extent: extent,
    devicePixelRatio: devicePixelRatio,
  );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderShaderHaze renderObject,
  ) {
    renderObject
      ..horizontalPass = horizontalPass
      ..verticalPass = verticalPass
      ..sigma = sigma
      ..edge = edge
      ..falloff = falloff
      ..extent = extent
      ..devicePixelRatio = devicePixelRatio;
  }
}

class _RenderShaderHaze extends RenderBox {
  _RenderShaderHaze({
    required ui.FragmentShader horizontalPass,
    required ui.FragmentShader verticalPass,
    required double sigma,
    required HazeEdge edge,
    required double falloff,
    required double extent,
    required double devicePixelRatio,
  }) : _horizontalPass = horizontalPass,
       _verticalPass = verticalPass,
       _sigma = sigma,
       _edge = edge,
       _falloff = falloff,
       _extent = extent,
       _devicePixelRatio = devicePixelRatio;

  ui.FragmentShader _horizontalPass;
  set horizontalPass(ui.FragmentShader value) {
    if (identical(value, _horizontalPass)) return;
    _horizontalPass = value;
    markNeedsPaint();
  }

  ui.FragmentShader _verticalPass;
  set verticalPass(ui.FragmentShader value) {
    if (identical(value, _verticalPass)) return;
    _verticalPass = value;
    markNeedsPaint();
  }

  double _sigma;
  set sigma(double value) {
    if (value == _sigma) return;
    _sigma = value;
    markNeedsPaint();
  }

  HazeEdge _edge;
  set edge(HazeEdge value) {
    if (value == _edge) return;
    _edge = value;
    markNeedsPaint();
  }

  double _falloff;
  set falloff(double value) {
    if (value == _falloff) return;
    _falloff = value;
    markNeedsPaint();
  }

  double _extent;
  set extent(double value) {
    if (value == _extent) return;
    _extent = value;
    markNeedsPaint();
  }

  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  /// One retained layer per pass; the vertical pass samples the horizontal
  /// pass's output, composing a full 2D Gaussian. Held via [LayerHandle] —
  /// without one the framework disposes the layer whenever an ancestor drops
  /// its layer subtree (route transitions do), and the next paint would then
  /// write to a disposed layer.
  final LayerHandle<BackdropFilterLayer> _horizontalLayer =
      LayerHandle<BackdropFilterLayer>();
  final LayerHandle<BackdropFilterLayer> _verticalLayer =
      LayerHandle<BackdropFilterLayer>();

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty) return;
    // Screen-space rect of the effect, current for THIS frame (includes any
    // in-flight route-transition transform).
    final bounds = localToGlobal(Offset.zero) & size;
    _configure(_horizontalPass, 1, 0, bounds);
    _configure(_verticalPass, 0, 1, bounds);

    final horizontalLayer = _horizontalLayer.layer ??= BackdropFilterLayer();
    horizontalLayer.filter = ui.ImageFilter.shader(_horizontalPass);
    context.pushLayer(horizontalLayer, _paintNothing, offset);

    final verticalLayer = _verticalLayer.layer ??= BackdropFilterLayer();
    verticalLayer.filter = ui.ImageFilter.shader(_verticalPass);
    context.pushLayer(verticalLayer, _paintNothing, offset);
  }

  static void _paintNothing(PaintingContext context, Offset offset) {}

  void _configure(
    ui.FragmentShader shader,
    double dirX,
    double dirY,
    Rect bounds,
  ) {
    final dpr = _devicePixelRatio;
    // Floats 0,1 (u_size) and sampler 0 (the backdrop) are engine-filled.
    shader
      ..setFloat(2, _sigma * dpr)
      ..setFloat(3, dirX)
      ..setFloat(4, dirY)
      ..setFloat(5, bounds.left * dpr)
      ..setFloat(6, bounds.top * dpr)
      ..setFloat(7, bounds.width * dpr)
      ..setFloat(8, bounds.height * dpr)
      ..setFloat(9, _edge.index.toDouble())
      ..setFloat(10, _falloff)
      ..setFloat(11, _extent);
  }

  @override
  void dispose() {
    _horizontalLayer.layer = null;
    _verticalLayer.layer = null;
    super.dispose();
  }
}

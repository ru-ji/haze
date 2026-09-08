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
/// Sigma falls off on a smootherstep: full at [edge], zero at the inner
/// boundary with zero slope AND zero curvature there, so nothing marks where
/// the blur ends. The cosine it replaced (0.1.1) reached zero as well, but on
/// a straight slope — a text line crossing the last tenth of the span came
/// back blurred at the top and crisp at the bottom.
///
/// [plateau] holds BOTH the sigma and the tint alpha at full strength over
/// the first slice of the span before either starts to fade — one profile,
/// shared. The blur used to run without it, and the mismatch showed: the wash
/// sat flat over the bar while the radius was already shedding under it.
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
    this.tintAdaptivity = 0,
    this.blurPlateau,
    this.falloff = 1.5,
    this.plateau = 0.0,
    this.blurCurve = 2.0,
    this.borderRadius,
    this.enabled = true,
    this.child,
  }) : assert(sigma >= 0),
       assert(falloff > 0),
       assert(plateau >= 0 && plateau < 1),
       assert(blurCurve >= 1),
       assert(tintOpacity >= 0 && tintOpacity <= 1),
       assert(tintAdaptivity >= 0 && tintAdaptivity <= 1),
       assert(
         blurPlateau == null || (blurPlateau >= 0 && blurPlateau < 1),
       );

  /// The edge the blur (and tint) is strongest at.
  final HazeEdge edge;

  /// Peak blur radius at [edge], in logical pixels. Falls to 0 along the
  /// falloff.
  ///
  /// The rectangle has the last word: see [Haze.resolve]. A sigma whose reach
  /// exceeds the transition the rectangle can offer would draw a block with an
  /// edge, so [plateau] is pulled in first and the sigma itself capped after.
  final double sigma;

  /// Colour of the wash painted on top of the blur, on the same falloff.
  /// Null paints no tint (blur only).
  final Color? tint;

  /// Peak opacity of [tint] at [edge].
  final double tintOpacity;

  /// How much the scrim's alpha is derived from the backdrop instead of being
  /// flat. 0 (default) is the plain wash: [tintOpacity] everywhere the profile
  /// is at full. 1 is iOS 26's behaviour — the further the backdrop's
  /// luminance is from [tint]'s, the less it is covered, so a white page keeps
  /// far more of itself than a mid-grey one does under the same wash.
  ///
  /// Measured off the system effect; the fit and its samples are in
  /// `haze.frag`. Requires the shader path — the [LinearGradient] fallback
  /// cannot see the backdrop and ignores this.
  final double tintAdaptivity;

  /// [plateau] for the SIGMA alone, when the blur should stop holding before
  /// the scrim does. Null (default) keeps them on one plateau.
  ///
  /// They are separate because only one of them is measurable: the scrim's
  /// plateau can be read straight off a screenshot of the system effect, the
  /// blur's cannot. Holding the blur for the scrim's distance puts it at full
  /// sigma over more than twice the band, which reads as a much heavier blur
  /// though the sigma never moved.
  ///
  /// Free to be LONGER than [plateau], and measurement says it usually is:
  /// the two curves are shaped by different things. The blur holds further out
  /// but then dies fast, because [blurCurve] squares its profile; the scrim
  /// lets go sooner and trails all the way to the rectangle's edge. Whatever
  /// this is set to, the profile still reaches exactly zero inside the
  /// rectangle, so it cannot produce a hard edge.
  final double? blurPlateau;

  /// Shape of the fade: an exponent on the POSITION along the ramp. 1 is the
  /// bare smootherstep; higher values keep the blur tighter to [edge]; lower
  /// values spread it further in.
  ///
  /// Whatever it is set to, the ramp still dies at the far side of the
  /// rectangle with zero slope and zero curvature — no value of this can make
  /// the effect end on a visible line. That is the point of a progressive
  /// blur, and it is why the exponent is applied to the position rather than
  /// to the result.
  final double falloff;

  /// Fraction of the span the blur AND the tint are held at full strength
  /// before they start to fade, 0–1. This is the shape of iOS's scroll edge
  /// effect: constant over the bar itself, then a fade whose start is as
  /// undetectable as its end. 0 (the default) starts fading at the very edge.
  ///
  /// Read as a fraction of the room the rectangle actually has, not of the
  /// rectangle: asking for more plateau than the sigma leaves space to fade in
  /// gets a proportionally smaller one rather than a block with an edge. See
  /// [Haze.resolve].
  final double plateau;

  /// Perceptual exponent on the blur alone, 1 or more.
  ///
  /// The tint and the sigma share one profile, but the eye does not read them
  /// the same way. Alpha is roughly linear; apparent blurriness tracks the
  /// cutoff frequency, about `1/sigma`, so 40 to 20 is barely a change while 6
  /// to 0 is the whole change. Left at 1, everything noticeable about the blur
  /// happens in the last stretch of the ramp and the rest reads as a uniform
  /// slab. The default sheds the big sigmas early and spends the distance
  /// where the eye is looking.
  ///
  /// 1 is the raw profile, shared with the tint. Below 1 is rejected: it would
  /// put the vertical drop back at the far edge.
  final double blurCurve;

  /// Rounds the effect's own clip — match it to the card underneath.
  final BorderRadius? borderRadius;

  /// When false the widget paints [child] only. Cheaper than swapping the
  /// widget out, and keeps layout identical.
  final bool enabled;

  /// Painted above the effect, e.g. the text the blur exists to make legible.
  final Widget? child;

  /// The effect's profile at [t], 0 at [edge] to 1 at the far side: a
  /// [plateau] at full strength, then a smootherstep whose first and second
  /// derivatives are zero at both ends — neither where the fade begins nor
  /// where it dies is detectable. Returns 1 (full strength) down to 0.
  ///
  /// Both the sigma and the tint's alpha ride this, and the shader computes
  /// the same thing per pixel. Public so a caller can line something else up
  /// with the fade — a gradient, a stroke, an opacity — instead of
  /// eyeballing it.
  static double falloffAt(double t, double plateau, double power) {
    final d = ((t - plateau) / math.max(1 - plateau, 1e-3)).clamp(0.0, 1.0);
    // The exponent warps the position, not the result — see the shader: on the
    // result it would make any power below 1 end on a vertical drop.
    final x = math.pow(d, 1 / power).toDouble();
    return (1 - x * x * x * (x * (x * 6 - 15) + 10)).clamp(0.0, 1.0);
  }

  /// The adaptive scrim's alpha for a backdrop whose luminance sits
  /// [distance] away from the tint's, on 0..1.
  ///
  /// `1 - K * d^P`, fitted to measurements of iOS 26's own scroll edge effect;
  /// the samples and the fit are in `haze.frag`, which is where this actually
  /// runs. The copy here exists for the gradient fallback, which has no
  /// backdrop to read and so has to assume one.
  static double adaptiveAlphaAt(double distance) =>
      (1 - _tintK * math.pow(distance.clamp(0.0, 1.0), _tintP))
          .clamp(0.0, 1.0)
          .toDouble();

  static const double _tintK = 0.663;
  static const double _tintP = 0.7;

  /// The luminance distance the fallback assumes. Half the range: the wash it
  /// paints is one flat alpha over a backdrop it cannot see, so the honest
  /// choice is the middle of the law rather than either end — picking 0 would
  /// paint the tint solid, which is what a page mid-transition looked like.
  static const double _assumedDistance = 0.5;

  /// Where the profile crosses 0.9 and 0.1, as positions along the
  /// smootherstep — the visible transition is what lies between them, not the
  /// whole fade. The polynomial is symmetric, hence the pair summing to 1.
  static const double _in90 = 0.245439;
  static const double _in10 = 0.754561;

  /// The fraction of the rectangle over which the effect visibly goes from
  /// strong to gone, for a given [plateau] and [falloff].
  ///
  /// Not the same thing as `1 - plateau`, and the difference is the point: the
  /// FALLOFF squeezes the transition too. The factor peaks at 0.51 for
  /// `falloff: 1` and collapses at both ends — 0.33 at 0.4, 0.32 at 4 — so a
  /// low falloff produces the same hard-edged block a big plateau does.
  static double transitionFraction(double plateau, double falloff) =>
      (1 - plateau) *
      (math.pow(_in10, falloff) - math.pow(_in90, falloff)).toDouble();

  /// The largest [plateau] whose transition is still at least as wide as the
  /// blur's own reach, in [span] logical pixels. Comes out at or below 0 when
  /// the rectangle has no room for a plateau at all.
  ///
  /// A Gaussian of sigma s reaches about 3s. A transition narrower than that
  /// is narrower than the thing making it, and the eye reads a block with an
  /// edge — the one thing a progressive blur exists to avoid. Nothing here is
  /// a fixed distance: the constraint scales with the rectangle, and a
  /// rectangle with room to spare never comes near it.
  static double plateauCeiling(double span, double sigma, double falloff) {
    final width = math.max(span, 0) * transitionFraction(0, falloff);
    return width <= 0 ? 0 : 1 - 3 * sigma / width;
  }

  /// The largest sigma whose reach still fits the transition [plateau] and
  /// [falloff] leave in [span].
  ///
  /// The second lever, and the last resort: the plateau is rescaled into the
  /// safe range first, so only a rectangle too short even without a plateau
  /// gets here.
  static double sigmaCeiling(double span, double plateau, double falloff) =>
      math.max(span, 0) * transitionFraction(plateau, falloff) / 3;

  /// The sigma and plateau actually painted in [span] logical pixels.
  ///
  /// The PLATEAU yields first, and proportionally rather than by clamping: the
  /// caller's value is read as a fraction of the room there actually is, so
  /// 0.9 of a rectangle whose safe maximum is 0.8 lands at 0.72 — still the
  /// highest plateau of anyone who asked for a high one, still ordered, and
  /// never a block. Clamping instead collapses every value above the ceiling
  /// onto one result, and that ceiling is exactly where the edge starts to
  /// show.
  static (double sigma, double plateau) resolve(
    double span,
    double sigma,
    double plateau,
    double falloff,
  ) {
    final ceiling = plateauCeiling(span, sigma, falloff).clamp(0.0, 1.0);
    final p = plateau * ceiling;
    return (math.min(sigma, sigmaCeiling(span, p, falloff)), p);
  }

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
    } else {
      _warnOnce(
        'shader image filters are unavailable on this platform, so the '
        'progressive blur is running as stacked fixed-sigma BackdropFilters — '
        'which is what a banded, step-by-step blur looks like. Impeller is '
        'required. Check FLTEnableImpeller (iOS) or '
        'io.flutter.embedding.android.EnableImpeller (Android).',
      );
    }
  }

  /// The fallback is a legitimate degradation and must not throw, but it looks
  /// nothing like the shader — banded rather than continuous — so silently
  /// swapping to it turns a build problem into a design puzzle. Said once, in
  /// debug only.
  static bool _warned = false;
  static void _warnOnce(String message) {
    assert(() {
      if (!_warned) {
        _warned = true;
        debugPrint('Haze: $message');
      }
      return true;
    }());
  }

  void _loadProgram() {
    _programFuture ??= () async {
      try {
        return await ui.FragmentProgram.fromAsset(_shaderAsset);
      } catch (_) {
        try {
          // Running from within this package itself (tests).
          return await ui.FragmentProgram.fromAsset('shaders/haze.frag');
        } catch (error) {
          _warnOnce(
            'could not load the blur shader from either '
            '"packages/haze/shaders/haze.frag" or "shaders/haze.frag" '
            '($error). The effect is running as stacked fixed-sigma '
            'BackdropFilters instead, which looks banded and step-by-step. A '
            'full restart is needed after the shader changes — hot reload does '
            'not rebuild it.',
          );
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

  /// The tint wash: [plateau] then smootherstep, sharing the blur's exponent
  /// and dying at the far side of the rectangle.
  Widget? _buildWash(double plateau) {
    final tint = widget.tint;
    if (tint == null || widget.tintOpacity == 0) return null;
    // A gradient cannot sample what it covers, so full adaptivity here means
    // the law evaluated at [_assumedDistance] instead of per pixel.
    final peak =
        widget.tintOpacity *
        ui.lerpDouble(
          1,
          Haze.adaptiveAlphaAt(Haze._assumedDistance),
          widget.tintAdaptivity,
        )!;
    // Enough steps that the gradient's own quantisation can't reintroduce
    // the banding the curve exists to remove.
    const steps = 30;
    double alphaAt(double t) =>
        peak * Haze.falloffAt(t, plateau, widget.falloff);
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
          ],
          stops: [for (var i = 0; i <= steps; i++) i / steps],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child ?? const SizedBox.expand();

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
    // The CHILD sizes this, not the effect: the blur render object is
    // `sizedByParent` and takes `constraints.biggest`, so an expanding stack
    // asks it for an infinite height the moment the rectangle is unbounded —
    // which is the ordinary case of a bar that wants to be as tall as the row
    // inside it. So the child is the only non-positioned member and the effect
    // layers fill whatever it settles on. With no child there is nothing to
    // measure and the stack expands as before, which then does need bounded
    // constraints.
    final child = widget.child;
    // [Haze.resolve] needs the span, and both layers must agree on what it
    // gave back — a wash on the caller's plateau over a blur on the resolved
    // one is two different effects stacked. The LayoutBuilder sits under
    // Positioned.fill, where the constraints are the size the stack settled
    // on, so it sees the real rectangle even when the child is what sized it.
    final vertical =
        widget.edge == HazeEdge.top || widget.edge == HazeEdge.bottom;
    final effect = Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final (sigma, plateau) = Haze.resolve(
            vertical ? constraints.maxHeight : constraints.maxWidth,
            widget.sigma,
            widget.plateau,
            widget.falloff,
          );
          // The shader paints the scrim itself when it is running: per pixel,
          // on the same curve as the sigma, and able to read the backdrop.
          // The gradient below is the fallback's wash only.
          final wash = blurred ? null : _buildWash(plateau);
          return Stack(
            fit: StackFit.expand,
            children: [
              if (blurred)
                AnimatedBuilder(
                  animation: _fadeIn,
                  builder: (context, _) => _ShaderHaze(
                    key: _blurKey,
                    horizontalPass: hPass,
                    verticalPass: vPass,
                    sigma: sigma * _fadeIn.value,
                    edge: widget.edge,
                    falloff: widget.falloff,
                    plateau: plateau,
                    blurPlateau: widget.blurPlateau ?? plateau,
                    blurCurve: widget.blurCurve,
                    tint: widget.tint,
                    // NOT scaled by [_fadeIn]: the fade exists so the blur
                    // can come back without popping, and the scrim is what
                    // holds the effect together while it does. Riding it too
                    // leaves the first frames after a transition with
                    // neither.
                    tintOpacity: widget.tintOpacity,
                    tintAdaptivity: widget.tintAdaptivity,
                    devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                  ),
                )
              else if (sigma > 0 && !_transitioning)
                _SlicesFallback(
                  sigma: sigma,
                  edge: widget.edge,
                  falloff: widget.falloff,
                  plateau: plateau,
                  blurCurve: widget.blurCurve,
                ),
              if (wash != null) IgnorePointer(child: wash),
            ],
          );
        },
      ),
    );

    final content = Stack(
      fit: child == null ? StackFit.expand : StackFit.passthrough,
      children: [effect, ?child],
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
    required this.plateau,
    required this.blurCurve,
  });

  final double sigma;
  final HazeEdge edge;
  final double falloff;
  final double plateau;
  final double blurCurve;

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

  /// The shader's falloff sampled at the slice's center.
  double _sigmaFor(int i) {
    final t = (i + 0.5) / _slices;
    return sigma *
        math.pow(Haze.falloffAt(t, plateau, falloff), blurCurve).toDouble();
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
    required this.plateau,
    required this.blurPlateau,
    required this.blurCurve,
    required this.tint,
    required this.tintOpacity,
    required this.tintAdaptivity,
    required this.devicePixelRatio,
  });

  final ui.FragmentShader horizontalPass;
  final ui.FragmentShader verticalPass;
  final double sigma;
  final HazeEdge edge;
  final double falloff;
  final double plateau;
  final double blurPlateau;
  final double blurCurve;
  final Color? tint;
  final double tintOpacity;
  final double tintAdaptivity;
  final double devicePixelRatio;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderShaderHaze(
    horizontalPass: horizontalPass,
    verticalPass: verticalPass,
    sigma: sigma,
    edge: edge,
    falloff: falloff,
    plateau: plateau,
    blurPlateau: blurPlateau,
    blurCurve: blurCurve,
    tint: tint,
    tintOpacity: tintOpacity,
    tintAdaptivity: tintAdaptivity,
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
      ..plateau = plateau
      ..blurPlateau = blurPlateau
      ..blurCurve = blurCurve
      ..tint = tint
      ..tintOpacity = tintOpacity
      ..tintAdaptivity = tintAdaptivity
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
    required double plateau,
    required double blurPlateau,
    required double blurCurve,
    required Color? tint,
    required double tintOpacity,
    required double tintAdaptivity,
    required double devicePixelRatio,
  }) : _horizontalPass = horizontalPass,
       _verticalPass = verticalPass,
       _sigma = sigma,
       _edge = edge,
       _falloff = falloff,
       _plateau = plateau,
       _blurPlateau = blurPlateau,
       _blurCurve = blurCurve,
       _tint = tint,
       _tintOpacity = tintOpacity,
       _tintAdaptivity = tintAdaptivity,
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

  double _plateau;
  set plateau(double value) {
    if (value == _plateau) return;
    _plateau = value;
    markNeedsPaint();
  }

  double _blurCurve;
  set blurCurve(double value) {
    if (value == _blurCurve) return;
    _blurCurve = value;
    markNeedsPaint();
  }

  double _blurPlateau;
  set blurPlateau(double value) {
    if (value == _blurPlateau) return;
    _blurPlateau = value;
    markNeedsPaint();
  }

  Color? _tint;
  set tint(Color? value) {
    if (value == _tint) return;
    _tint = value;
    markNeedsPaint();
  }

  double _tintOpacity;
  set tintOpacity(double value) {
    if (value == _tintOpacity) return;
    _tintOpacity = value;
    markNeedsPaint();
  }

  double _tintAdaptivity;
  set tintAdaptivity(double value) {
    if (value == _tintAdaptivity) return;
    _tintAdaptivity = value;
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
    // The scrim goes on the VERTICAL pass alone: it is the last one, and on
    // the horizontal pass it would be laid down and then blurred by the pass
    // above it — and applied twice.
    _configure(_horizontalPass, 1, 0, bounds, scrim: false);
    _configure(_verticalPass, 0, 1, bounds, scrim: true);

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
    Rect bounds, {
    required bool scrim,
  }) {
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
      ..setFloat(11, _plateau)
      ..setFloat(12, _blurCurve);

    final tint = scrim ? _tint : null;
    shader
      ..setFloat(13, (tint?.r ?? 0) * 1.0)
      ..setFloat(14, (tint?.g ?? 0) * 1.0)
      ..setFloat(15, (tint?.b ?? 0) * 1.0)
      // Slot 16 is u_tint's own alpha channel: the peak. The colour's alpha
      // scales it, so `black.withValues(alpha: .5)` means here what it means
      // anywhere else in Flutter.
      ..setFloat(16, tint == null ? 0 : _tintOpacity * tint.a)
      ..setFloat(17, _tintAdaptivity)
      ..setFloat(18, _blurPlateau);
  }

  @override
  void dispose() {
    _horizontalLayer.layer = null;
    _verticalLayer.layer = null;
    super.dispose();
  }
}

import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:haze/haze.dart';

import 'photos.dart';
import 'profile_curve.dart';

void main() => runApp(const HazeStudioApp());

/// Widest the controls ever get — on the web the panel centres inside this
/// instead of stretching a phone layout across a desktop.
const double kPanelWidth = 560;

class HazeStudioApp extends StatelessWidget {
  const HazeStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Committed to dark: the whole point on screen is a light effect eating
    // into a photograph, and a light chrome competes with it.
    return const CupertinoApp(
      title: 'Haze',
      theme: CupertinoThemeData(brightness: Brightness.dark),
      home: StudioPage(),
    );
  }
}

/// Which technique paints the top band. The comparison is the example: both
/// sides get the same sigma and the same tint, and only one of them has an
/// edge you can find.
enum Technique { haze, plain }

class StudioPage extends StatefulWidget {
  const StudioPage({super.key});

  @override
  State<StudioPage> createState() => _StudioPageState();
}

class _StudioPageState extends State<StudioPage> {
  Technique _technique = Technique.haze;
  double _height = 200;
  double _sigma = 18;
  double _plateau = 0.18;
  double _falloff = 1.0;
  double _blurCurve = 2.0;
  double _tintOpacity = 0.5;
  int _photo = 0;

  @override
  Widget build(BuildContext context) {
    final tint = CupertinoColors.black;
    // What the widget will actually paint. Shown in the panel and plotted in
    // the curve, so the readout never claims something the rectangle refused.
    final (effectiveSigma, effectivePlateau) = Haze.resolve(
      _height,
      _sigma,
      _plateau,
      _falloff,
    );

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: Stack(
        children: [
          // The subject. Swipeable, because a single photo makes it too easy
          // to tune the effect to one image.
          PageView.builder(
            itemCount: photos.length,
            onPageChanged: (i) => setState(() => _photo = i),
            itemBuilder: (context, i) =>
                PhotoImage(photo: photos[i], fit: BoxFit.cover),
          ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _height,
            child: IgnorePointer(
              child: switch (_technique) {
                Technique.haze => Haze(
                  edge: HazeEdge.top,
                  sigma: _sigma,
                  plateau: _plateau,
                  falloff: _falloff,
                  blurCurve: _blurCurve,
                  tint: tint,
                  tintOpacity: _tintOpacity,
                  child: _Header(photo: photos[_photo]),
                ),
                // The ordinary way, for contrast: one uniform blur behind one
                // flat scrim, clipped. Same numbers, and the rectangle draws
                // itself across the photograph.
                Technique.plain => ClipRect(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: _sigma, sigmaY: _sigma),
                    child: ColoredBox(
                      color: tint.withValues(alpha: _tintOpacity),
                      child: _Header(photo: photos[_photo]),
                    ),
                  ),
                ),
              },
            ),
          ),

          // The controls ride a Haze of their own, so the panel is also a
          // second instance of the thing being tuned.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Haze(
              edge: HazeEdge.bottom,
              sigma: 22,
              plateau: 0.55,
              tint: CupertinoColors.black,
              tintOpacity: 0.62,
              child: SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: kPanelWidth),
                    child: _Panel(
                      technique: _technique,
                      height: _height,
                      sigma: _sigma,
                      effectiveSigma: effectiveSigma,
                      plateau: _plateau,
                      effectivePlateau: effectivePlateau,
                      falloff: _falloff,
                      blurCurve: _blurCurve,
                      tintOpacity: _tintOpacity,
                      onTechnique: (v) => setState(() => _technique = v),
                      onHeight: (v) => setState(() => _height = v),
                      onSigma: (v) => setState(() => _sigma = v),
                      onPlateau: (v) => setState(() => _plateau = v),
                      onFalloff: (v) => setState(() => _falloff = v),
                      onBlurCurve: (v) => setState(() => _blurCurve = v),
                      onTintOpacity: (v) => setState(() => _tintOpacity = v),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Title block inside the top band — text the effect exists to make legible.
class _Header extends StatelessWidget {
  const _Header({required this.photo});

  final Photo photo;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              photo.place.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w600,
                color: Color(0x8CFFFFFF),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              photo.title,
              style: const TextStyle(
                fontSize: 30,
                height: 1.05,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.6,
                color: CupertinoColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.technique,
    required this.height,
    required this.sigma,
    required this.effectiveSigma,
    required this.plateau,
    required this.effectivePlateau,
    required this.falloff,
    required this.blurCurve,
    required this.tintOpacity,
    required this.onTechnique,
    required this.onHeight,
    required this.onSigma,
    required this.onPlateau,
    required this.onFalloff,
    required this.onBlurCurve,
    required this.onTintOpacity,
  });

  final Technique technique;
  final double height;
  final double sigma;
  final double effectiveSigma;
  final double plateau;
  final double effectivePlateau;
  final double falloff;
  final double blurCurve;
  final double tintOpacity;
  final ValueChanged<Technique> onTechnique;
  final ValueChanged<double> onHeight;
  final ValueChanged<double> onSigma;
  final ValueChanged<double> onPlateau;
  final ValueChanged<double> onFalloff;
  final ValueChanged<double> onBlurCurve;
  final ValueChanged<double> onTintOpacity;

  @override
  Widget build(BuildContext context) {
    final capped =
        effectiveSigma < sigma - 0.01 || effectivePlateau < plateau - 0.005;
    final width = (height * Haze.transitionFraction(effectivePlateau, falloff))
        .round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<Technique>(
              groupValue: technique,
              backgroundColor: const Color(0x1FFFFFFF),
              thumbColor: const Color(0x40FFFFFF),
              onValueChanged: (v) => v == null ? null : onTechnique(v),
              children: const {
                Technique.haze: _Seg('Haze'),
                Technique.plain: _Seg('BackdropFilter'),
              },
            ),
          ),
          const SizedBox(height: 14),

          // The curve is the whole argument, so it is drawn rather than
          // described: where the plateau ends, how the fade leans, and that it
          // reaches zero flat against the far side.
          ProfileCurve(
            plateau: effectivePlateau,
            falloff: falloff,
            live: technique == Technique.haze,
          ),
          const SizedBox(height: 6),
          Text(
            technique == Technique.haze
                ? (capped
                      ? 'held back to plateau '
                            '${effectivePlateau.toStringAsFixed(2)} · sigma '
                            '${effectiveSigma.toStringAsFixed(1)} — '
                            '${width}pt of transition'
                      : '${width}pt of transition for '
                            '${(3 * effectiveSigma).round()}pt of blur reach')
                : 'one uniform blur, one flat scrim, one hard clip',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              letterSpacing: 0.1,
              color: capped && technique == Technique.haze
                  ? const Color(0xFFFFD37A)
                  : const Color(0x99FFFFFF),
            ),
          ),
          const SizedBox(height: 10),

          _Slider(
            label: 'height',
            value: height,
            min: 60,
            max: 420,
            unit: 'pt',
            decimals: 0,
            onChanged: onHeight,
          ),
          _Slider(
            label: 'sigma',
            value: sigma,
            min: 0,
            max: 40,
            decimals: 1,
            onChanged: onSigma,
          ),
          _Slider(
            // Free to the top: the ceiling is computed from the span, the
            // sigma and the falloff, so there is nothing for a slider bound to
            // second-guess. Push it to 0.99 and the readout shows what the
            // rectangle could actually give.
            label: 'plateau',
            value: plateau,
            min: 0,
            max: 0.99,
            decimals: 2,
            enabled: technique == Technique.haze,
            onChanged: onPlateau,
          ),
          _Slider(
            label: 'falloff',
            value: falloff,
            min: 0.4,
            max: 4,
            decimals: 2,
            enabled: technique == Technique.haze,
            onChanged: onFalloff,
          ),
          _Slider(
            // Blur only. 1 puts it back on the tint's curve, which reads as a
            // slab that suddenly clears — the point of the slider is to see
            // that.
            label: 'blur curve',
            value: blurCurve,
            min: 1,
            max: 4,
            decimals: 2,
            enabled: technique == Technique.haze,
            onChanged: onBlurCurve,
          ),
          _Slider(
            label: 'tint',
            value: tintOpacity,
            min: 0,
            max: 1,
            decimals: 2,
            onChanged: onTintOpacity,
          ),
        ],
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: CupertinoColors.white,
      ),
    ),
  );
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.decimals,
    required this.onChanged,
    this.unit = '',
    this.enabled = true,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int decimals;
  final String unit;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.35,
      duration: const Duration(milliseconds: 180),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: Color(0xB3FFFFFF)),
            ),
          ),
          Expanded(
            child: CupertinoSlider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              activeColor: CupertinoColors.white,
              onChanged: enabled ? onChanged : null,
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              '${value.toStringAsFixed(decimals)}$unit',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12.5,
                fontFeatures: [FontFeature.tabularFigures()],
                color: CupertinoColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Network photo with a coloured placeholder, so the layout never jumps and
/// the blur has something to chew on from the first frame.
class PhotoImage extends StatelessWidget {
  const PhotoImage({
    super.key,
    required this.photo,
    this.width = 1400,
    this.fit = BoxFit.cover,
  });

  final Photo photo;
  final double width;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: photo.placeholder,
      child: Image.network(
        photo.url(width),
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        frameBuilder: (context, child, frame, wasSync) => AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 260),
          child: child,
        ),
        errorBuilder: (context, _, _) => const SizedBox.expand(),
      ),
    );
  }
}

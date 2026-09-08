import 'package:flutter/cupertino.dart';
import 'package:haze/haze.dart';

/// The effect's own profile, plotted from [Haze.falloffAt] — the very function
/// the shader runs per pixel, not a lookalike, so the drawing cannot drift
/// from what is on screen.
///
/// Left edge is the hugged edge, right edge is the far side of the rectangle.
/// The shaded block is the plateau; the curve after it is the fade. What the
/// picture is for: the curve always arrives at the right-hand side flat, so
/// there is nothing at the boundary for the eye to catch.
class ProfileCurve extends StatelessWidget {
  const ProfileCurve({
    super.key,
    required this.plateau,
    required this.falloff,
    required this.live,
    this.height = 64,
  });

  final double plateau;
  final double falloff;

  /// False while the plain BackdropFilter is showing: the curve is then a
  /// step, and drawing it greyed says so better than hiding it.
  final bool live;

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _CurvePainter(
          plateau: plateau,
          falloff: falloff,
          live: live,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _CurvePainter extends CustomPainter {
  _CurvePainter({
    required this.plateau,
    required this.falloff,
    required this.live,
  });

  final double plateau;
  final double falloff;
  final bool live;

  /// Sampled finely enough that the polynomial's own shape, not the sampling,
  /// is what the eye reads.
  static const int _samples = 120;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = BorderRadius.circular(10);
    final rrect = radius.toRRect(rect);
    canvas.save();
    canvas.clipRRect(rrect);

    canvas.drawRRect(rrect, Paint()..color = const Color(0x14FFFFFF));

    double valueAt(double t) =>
        live ? Haze.falloffAt(t, plateau, falloff) : (t < 1 ? 1.0 : 0.0);

    // The plateau block, so where the fade starts is a place and not a number.
    if (live && plateau > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width * plateau, size.height),
        Paint()..color = const Color(0x14FFFFFF),
      );
    }

    final path = Path()..moveTo(0, size.height * (1 - valueAt(0)));
    for (var i = 1; i <= _samples; i++) {
      final t = i / _samples;
      path.lineTo(size.width * t, size.height * (1 - valueAt(t)));
    }

    // Filled under the curve: the area IS the effect, and the fill reads as
    // strength where a bare line reads as a graph.
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: live
              ? const [Color(0x59FFFFFF), Color(0x0DFFFFFF)]
              : const [Color(0x33FF9F0A), Color(0x1AFF9F0A)],
        ).createShader(rect),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = live ? CupertinoColors.white : const Color(0xFFFF9F0A),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_CurvePainter old) =>
      old.plateau != plateau || old.falloff != falloff || old.live != live;
}

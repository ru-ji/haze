import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haze/haze.dart';

Widget _wrap(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Stack(children: [const ColoredBox(color: Color(0xFF123456)), child]),
);

void main() {
  testWidgets('builds on every edge without throwing', (tester) async {
    for (final edge in HazeEdge.values) {
      await tester.pumpWidget(
        _wrap(Haze(edge: edge, sigma: 20, tint: const Color(0xFF000000))),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('disabled paints the child only', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const Haze(enabled: false, child: SizedBox(key: Key('c'))),
      ),
    );
    expect(find.byKey(const Key('c')), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('a child sizes the effect under unbounded constraints', (
    tester,
  ) async {
    // The ordinary case of a bar as tall as the row inside it. The blur render
    // object is sizedByParent, so an expanding stack would ask it for an
    // infinite height here.
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Haze(
            edge: HazeEdge.bottom,
            tint: Color(0xFF000000),
            child: SizedBox(height: 120, width: 300),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(Haze)).height, 120);
  });

  test('no combination of knobs can produce a hard-edged block', () {
    // The transition — 0.9 down to 0.1, not the nominal fade — must always
    // stay at least as wide as the blur's own 3-sigma reach.
    for (final span in [40.0, 200.0, 900.0]) {
      for (final sigma in [1.0, 18.0, 40.0]) {
        for (final falloff in [0.4, 1.0, 2.8, 4.0]) {
          for (final asked in [0.0, 0.4, 0.99]) {
            final (s, p, _) = Haze.resolve(span, sigma, asked, falloff);
            final width = span * Haze.transitionFraction(p, falloff);
            expect(
              width,
              greaterThanOrEqualTo(3 * s - 1e-9),
              reason: 'span $span sigma $sigma falloff $falloff plateau $asked',
            );
            expect(p, lessThanOrEqualTo(asked + 1e-9)); // never raised
          }
        }
      }
    }
  });

  test('a plateau is scaled into the room there is, not clamped', () {
    // Ordered rather than collapsed: two callers asking for different plateaus
    // above the ceiling must still get different ones.
    final (_, low, _) = Haze.resolve(200, 30, 0.5, 1);
    final (_, high, _) = Haze.resolve(200, 30, 0.9, 1);
    expect(low, lessThan(high));
    // Room to spare: the value passes through essentially untouched.
    final (sigma, p, _) = Haze.resolve(2000, 6, 0.5, 1);
    expect(sigma, 6);
    expect(p, closeTo(0.5, 0.01));
  });

  test('rejects out-of-range parameters', () {
    expect(() => Haze(plateau: 1.2), throwsAssertionError);
    expect(() => Haze(blurPlateau: -0.1), throwsAssertionError);
    expect(() => Haze(sigma: -1), throwsAssertionError);
    expect(() => Haze(tintOpacity: 1.5), throwsAssertionError);
    expect(() => Haze(tintAdaptivity: -0.1), throwsAssertionError);
    expect(() => Haze(tintAdaptivity: 1.1), throwsAssertionError);
  });

  test('blurPlateau cannot outrun the room the rectangle has', () {
    // The old hole: a caller asking the SIGMA to hold over 75% of a short band
    // got it, and the fade that was left was narrower than the blur itself.
    for (final span in [40.0, 60.0, 120.0, 300.0]) {
      final (sigma, _, bp) = Haze.resolve(span, 22, 0.5, 1.5, blurPlateau: 1);
      final width = span * Haze.transitionFraction(bp, 1.5);
      expect(width, greaterThanOrEqualTo(3 * sigma - 1e-6),
          reason: 'span $span: fade $width narrower than reach ${3 * sigma}');
    }
  });

  test('fadeRoom is exactly the span a full-strength chrome needs', () {
    for (final chrome in [44.0, 52.0, 118.0, 200.0]) {
      for (final sigma in [8.0, 18.0, 30.0]) {
        final span = chrome + Haze.fadeRoom(sigma);
        // 1 means "as much plateau as this rectangle can afford", and with
        // exactly [Haze.fadeRoom] of room that lands on the chrome's edge.
        final (s, p, _) = Haze.resolve(span, sigma, 1, 1.5);
        expect(s, closeTo(sigma, 1e-6), reason: 'sigma was cut');
        // The plateau lands on the chrome, so the chrome is uniformly blurred.
        expect(p * span, closeTo(chrome, 1e-3));
      }
    }
  });

  test('the curve is C2 where the plateau gives way to the fade', () {
    // The bug this guards: warping the position with pow() left a curvature
    // break exactly at the junction. C2 means the curvature GOES TO ZERO as
    // the junction is approached from the fade side; pow() left it at a
    // non-zero constant at the default falloff of 1.5 (about -19) and sent it
    // to infinity above that. The eye reads such a break as a line, right
    // where the effect starts to let go.
    //
    // Measured in the ramp's own units, so a plateau that shortens the ramp
    // does not look like a curvature change by itself.
    double curvature(double eps, double plateau, double falloff) {
      final scale = 1 - plateau;
      double at(double d) => Haze.falloffAt(plateau + d * scale, plateau, falloff);
      const h = 1e-5;
      return ((at(eps + h) - 2 * at(eps) + at(eps - h)) / (h * h)).abs();
    }

    for (final falloff in [0.4, 1.0, 1.5, 2.5, 4.0]) {
      for (final plateau in [0.0, 0.3, 0.7]) {
        final far = curvature(1e-2, plateau, falloff);
        final near = curvature(1e-4, plateau, falloff);
        expect(near, lessThan(far),
            reason: 'falloff $falloff, plateau $plateau: curvature is not '
                'dying at the junction');
        expect(near, lessThan(0.5),
            reason: 'falloff $falloff, plateau $plateau: curvature jump');
      }
    }
  });
}

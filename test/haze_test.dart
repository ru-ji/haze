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
            final (s, p) = Haze.resolve(span, sigma, asked, falloff);
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
    final (_, low) = Haze.resolve(200, 30, 0.5, 1);
    final (_, high) = Haze.resolve(200, 30, 0.9, 1);
    expect(low, lessThan(high));
    // Room to spare: the value passes through essentially untouched.
    final (sigma, p) = Haze.resolve(2000, 6, 0.5, 1);
    expect(sigma, 6);
    expect(p, closeTo(0.5, 0.01));
  });

  test('rejects out-of-range parameters', () {
    expect(() => Haze(plateau: 1), throwsAssertionError);
    expect(() => Haze(sigma: -1), throwsAssertionError);
    expect(() => Haze(tintOpacity: 1.5), throwsAssertionError);
    expect(() => Haze(tintAdaptivity: -0.1), throwsAssertionError);
    expect(() => Haze(tintAdaptivity: 1.1), throwsAssertionError);
  });
}

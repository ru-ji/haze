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

  test('rejects out-of-range parameters', () {
    expect(() => Haze(extent: 0), throwsAssertionError);
    expect(() => Haze(sigma: -1), throwsAssertionError);
    expect(() => Haze(tintOpacity: 1.5), throwsAssertionError);
  });
}

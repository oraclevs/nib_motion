import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/src/text/nib_text_gradient.dart';

Widget _wrap(Widget child) {
  return Directionality(
      textDirection: TextDirection.ltr, child: Center(child: child));
}

const _gradient =
    LinearGradient(colors: [Color(0xFF02569B), Color(0xFF54C5F8)]);

void main() {
  group('NibGradientText', () {
    testWidgets('builds and paints without throwing', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibGradientText(
            'Hello',
            gradient: _gradient,
            duration: Duration(milliseconds: 200),
          ),
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(NibGradientText), findsOneWidget);
    });

    testWidgets('advances the sweep over several ticks without throwing',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibGradientText(
            'Sweep',
            gradient: _gradient,
            duration: Duration(milliseconds: 100),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 25));
      await tester.pump(const Duration(milliseconds: 25));
      await tester.pump(const Duration(milliseconds: 25));
      await tester.pump(const Duration(milliseconds: 25));

      expect(tester.takeException(), isNull);
    });

    testWidgets('non-repeating sweep stops after one pass without throwing',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibGradientText(
            'Once',
            gradient: _gradient,
            duration: Duration(milliseconds: 50),
            repeat: false,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 60));

      expect(tester.takeException(), isNull);
    });

    testWidgets('supports right-to-left direction', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibGradientText(
            'RTL',
            gradient: _gradient,
            duration: Duration(milliseconds: 100),
            direction: TextDirection.rtl,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposes its ticker cleanly when removed', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibGradientText(
            'Bye',
            gradient: _gradient,
            duration: Duration(milliseconds: 100),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  });
}

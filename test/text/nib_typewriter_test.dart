import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/src/text/nib_typewriter.dart';

Widget _wrap(Widget child) {
  return Directionality(textDirection: TextDirection.ltr, child: Center(child: child));
}

void main() {
  group('NibTypewriter', () {
    testWidgets('reveals characters over time', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibTypewriter(
            'abc',
            speed: Duration(milliseconds: 10),
            cursor: null,
          ),
        ),
      );

      // Nothing revealed yet on the very first frame.
      await tester.pump();
      var textWidget = tester.widget<Text>(find.byType(Text));
      expect(textWidget.data, '');

      await tester.pump(const Duration(milliseconds: 10));
      textWidget = tester.widget<Text>(find.byType(Text));
      expect(textWidget.data, 'a');

      await tester.pump(const Duration(milliseconds: 10));
      textWidget = tester.widget<Text>(find.byType(Text));
      expect(textWidget.data, 'ab');

      await tester.pump(const Duration(milliseconds: 10));
      textWidget = tester.widget<Text>(find.byType(Text));
      expect(textWidget.data, 'abc');
    });

    testWidgets('calls onComplete exactly once after the full text is revealed', (tester) async {
      var completeCount = 0;
      await tester.pumpWidget(
        _wrap(
          NibTypewriter(
            'ab',
            speed: const Duration(milliseconds: 10),
            cursor: null,
            onComplete: () => completeCount++,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 10)); // reveals 'a'
      await tester.pump(const Duration(milliseconds: 10)); // reveals 'ab'
      await tester.pump(const Duration(milliseconds: 10)); // detects completion
      expect(completeCount, 1);

      // Further pumps without repeat should not call onComplete again.
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 10));
      expect(completeCount, 1);
    });

    testWidgets('respects an initial delay before typing starts', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibTypewriter(
            'a',
            speed: Duration(milliseconds: 10),
            delay: Duration(milliseconds: 50),
            cursor: null,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 10));
      var textWidget = tester.widget<Text>(find.byType(Text));
      expect(textWidget.data, '');

      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 10));
      textWidget = tester.widget<Text>(find.byType(Text));
      expect(textWidget.data, 'a');
    });

    testWidgets('shows a blinking cursor via a rich text span', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibTypewriter(
            'a',
            speed: Duration(milliseconds: 10),
            cursor: '|',
            cursorBlinkInterval: Duration(milliseconds: 20),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(Text), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.takeException(), isNull);
    });

    testWidgets('repeat clears and retypes after completing', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibTypewriter(
            'ab',
            speed: Duration(milliseconds: 10),
            deleteSpeed: Duration(milliseconds: 10),
            cursor: null,
            repeat: true,
          ),
        ),
      );

      // Tick 1 (t=10ms): reveals "a". Tick 2 (t=20ms): reveals "ab".
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 10));
      var textWidget = tester.widget<Text>(find.byType(Text));
      expect(textWidget.data, 'ab');

      // Tick 3 (t=30ms): detects completion, schedules a one-shot timer that
      // fires `_startDeleting` after one more `speed` interval.
      await tester.pump(const Duration(milliseconds: 10));
      // That one-shot timer fires (t=40ms), starting the delete periodic
      // timer — no character removed yet on this pump.
      await tester.pump(const Duration(milliseconds: 10));
      textWidget = tester.widget<Text>(find.byType(Text));
      expect(textWidget.data, 'ab');

      // First delete tick (t=50ms): "ab" -> "a".
      await tester.pump(const Duration(milliseconds: 10));
      textWidget = tester.widget<Text>(find.byType(Text));
      expect(textWidget.data, 'a');

      // Second delete tick (t=60ms): "a" -> "".
      await tester.pump(const Duration(milliseconds: 10));
      textWidget = tester.widget<Text>(find.byType(Text));
      expect(textWidget.data, '');

      // Next delete tick (t=70ms) finds revealedCount <= 0, cancels the
      // delete timer, and restarts typing — no character revealed yet.
      await tester.pump(const Duration(milliseconds: 10));
      textWidget = tester.widget<Text>(find.byType(Text));
      expect(textWidget.data, '');

      // First tick of the new typing cycle (t=80ms): reveals "a" again.
      await tester.pump(const Duration(milliseconds: 10));
      textWidget = tester.widget<Text>(find.byType(Text));
      expect(textWidget.data, 'a');
    });
  });
}

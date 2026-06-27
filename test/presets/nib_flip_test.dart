import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/src/presets/nib_flip.dart';

Widget _wrap(Widget child) {
  return Directionality(textDirection: TextDirection.ltr, child: Center(child: child));
}

/// Builds a `NibFlip` whose [front]/[back] are tappable buttons, so the
/// currently-visible (hit-testable) face can be asserted via [WidgetTester.tap]
/// rather than [find.text] — both faces stay in the element tree at all
/// times (only one is painted/hit-testable), so `find.text` can't
/// distinguish them.
Widget _flip({
  required bool isFlipped,
  required Duration duration,
  required VoidCallback onFrontTap,
  required VoidCallback onBackTap,
  Axis flipAxis = Axis.horizontal,
}) {
  return _wrap(
    NibFlip(
      isFlipped: isFlipped,
      duration: duration,
      flipAxis: flipAxis,
      front: GestureDetector(
        onTap: onFrontTap,
        child: const SizedBox(width: 100, height: 100, child: Text('Front')),
      ),
      back: GestureDetector(
        onTap: onBackTap,
        child: const SizedBox(width: 100, height: 100, child: Text('Back')),
      ),
    ),
  );
}

void main() {
  group('NibFlip', () {
    testWidgets('shows front initially and back after toggling isFlipped past the midpoint', (tester) async {
      var frontTaps = 0;
      var backTaps = 0;

      await tester.pumpWidget(
        _flip(
          isFlipped: false,
          duration: const Duration(milliseconds: 200),
          onFrontTap: () => frontTaps++,
          onBackTap: () => backTaps++,
        ),
      );

      await tester.tap(find.byType(NibFlip));
      expect(frontTaps, 1);
      expect(backTaps, 0);

      await tester.pumpWidget(
        _flip(
          isFlipped: true,
          duration: const Duration(milliseconds: 200),
          onFrontTap: () => frontTaps++,
          onBackTap: () => backTaps++,
        ),
      );

      // Immediately after toggling, progress hasn't reached the 0.5 midpoint
      // yet, so the front face should still be the hit-testable one.
      await tester.tap(find.byType(NibFlip));
      expect(frontTaps, 2);
      expect(backTaps, 0);

      // Advance partway past the midpoint of the flip.
      await tester.pump(const Duration(milliseconds: 110));

      await tester.tap(find.byType(NibFlip));
      expect(frontTaps, 2);
      expect(backTaps, 1);

      await tester.pumpAndSettle();
      await tester.tap(find.byType(NibFlip));
      expect(backTaps, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('toggling back to isFlipped: false reveals front again', (tester) async {
      var frontTaps = 0;
      var backTaps = 0;

      await tester.pumpWidget(
        _flip(
          isFlipped: true,
          duration: const Duration(milliseconds: 100),
          onFrontTap: () => frontTaps++,
          onBackTap: () => backTaps++,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NibFlip));
      expect(backTaps, 1);
      expect(frontTaps, 0);

      await tester.pumpWidget(
        _flip(
          isFlipped: false,
          duration: const Duration(milliseconds: 100),
          onFrontTap: () => frontTaps++,
          onBackTap: () => backTaps++,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(NibFlip));
      expect(frontTaps, 1);
      expect(backTaps, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('supports vertical flipAxis without throwing', (tester) async {
      var backTaps = 0;

      await tester.pumpWidget(
        _flip(
          isFlipped: false,
          duration: const Duration(milliseconds: 100),
          flipAxis: Axis.vertical,
          onFrontTap: () {},
          onBackTap: () => backTaps++,
        ),
      );

      await tester.pumpWidget(
        _flip(
          isFlipped: true,
          duration: const Duration(milliseconds: 100),
          flipAxis: Axis.vertical,
          onFrontTap: () {},
          onBackTap: () => backTaps++,
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byType(NibFlip));
      expect(backTaps, 1);
      expect(tester.takeException(), isNull);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/src/path/nib_path_motion.dart';
import 'package:nib_motion/src/values/motion_value.dart';

Path _straightLine() {
  return Path()
    ..moveTo(0, 0)
    ..lineTo(100, 0);
}

void main() {
  group('NibPathMotion', () {
    testWidgets('builds without throwing', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: NibPathMotion(
            path: _straightLine(),
            child: const SizedBox(width: 10, height: 10),
          ),
        ),
      );
      expect(find.byType(NibPathMotion), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets(
      'autoPlay drives progress from 0 toward 1 over duration, moving the child',
      (tester) async {
        const duration = Duration(milliseconds: 1000);
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: NibPathMotion(
                path: _straightLine(),
                duration: duration,
                curve: Curves.linear,
                child: const SizedBox(
                    width: 10, height: 10, key: ValueKey('child')),
              ),
            ),
          ),
        );

        await tester.pump();
        final initialPosition =
            tester.getTopLeft(find.byKey(const ValueKey('child')));

        await tester.pump(const Duration(milliseconds: 500));
        final midPosition =
            tester.getTopLeft(find.byKey(const ValueKey('child')));
        expect(midPosition, isNot(equals(initialPosition)));

        await tester.pumpAndSettle();
        final finalPosition =
            tester.getTopLeft(find.byKey(const ValueKey('child')));
        // End of a straight line from (0,0) to (100,0).
        expect(finalPosition.dx, closeTo(initialPosition.dx + 100, 1.0));
      },
    );

    testWidgets('repeat:true keeps animating past one cycle', (tester) async {
      const duration = Duration(milliseconds: 200);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: NibPathMotion(
              path: _straightLine(),
              duration: duration,
              curve: Curves.linear,
              repeat: true,
              child:
                  const SizedBox(width: 10, height: 10, key: ValueKey('child')),
            ),
          ),
        ),
      );

      await tester.pump();
      // Run past two full cycles; with repeat:true the ticker should still
      // be active (pumpAndSettle would hang/timeout if it weren't bounded),
      // so drive a fixed number of frames instead of calling pumpAndSettle.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Widget is still alive and painting without throwing.
      expect(find.byKey(const ValueKey('child')), findsOneWidget);

      // Tear down cleanly (replace the tree) to stop the repeating ticker
      // before the test ends, avoiding a Ticker leak.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets(
      'external progress MotionValue overrides autonomous driving',
      (tester) async {
        final progress = MotionValue<double>(0.0);
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: NibPathMotion(
                path: _straightLine(),
                progress: progress,
                child: const SizedBox(
                    width: 10, height: 10, key: ValueKey('child')),
              ),
            ),
          ),
        );

        await tester.pump();
        final atZero = tester.getTopLeft(find.byKey(const ValueKey('child')));

        progress.value = 1.0;
        await tester.pump();
        final atOne = tester.getTopLeft(find.byKey(const ValueKey('child')));
        expect(atOne.dx, closeTo(atZero.dx + 100, 1.0));

        // No internal ticker should be fighting this: holding still after
        // several frames keeps the externally-set value.
        await tester.pump(const Duration(milliseconds: 200));
        final stillAtOne =
            tester.getTopLeft(find.byKey(const ValueKey('child')));
        expect(stillAtOne, equals(atOne));

        progress.value = 0.5;
        await tester.pump();
        final atHalf = tester.getTopLeft(find.byKey(const ValueKey('child')));
        expect(atHalf.dx, closeTo(atZero.dx + 50, 1.0));
      },
    );

    testWidgets('disposes cleanly with no Ticker leaks', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: NibPathMotion(
            path: _straightLine(),
            duration: const Duration(milliseconds: 100),
            child: const SizedBox(width: 10, height: 10),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Unmount mid-animation; State.dispose must stop and dispose its
      // Ticker, or flutter_test fails the test with a leaked-Ticker error.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('controller.restart() restarts traversal from progress 0', (
      tester,
    ) async {
      final controller = NibPathMotionController();
      const duration = Duration(milliseconds: 200);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: NibPathMotion(
              path: _straightLine(),
              duration: duration,
              curve: Curves.linear,
              controller: controller,
              child:
                  const SizedBox(width: 10, height: 10, key: ValueKey('child')),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();
      final endPosition =
          tester.getTopLeft(find.byKey(const ValueKey('child')));

      controller.restart();
      await tester.pump();
      final restartedPosition =
          tester.getTopLeft(find.byKey(const ValueKey('child')));
      expect(restartedPosition.dx, lessThan(endPosition.dx));

      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('rotate:true rotates the child to follow the path tangent', (
      tester,
    ) async {
      final progress = MotionValue<double>(0.0);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: NibPathMotion(
            path: _straightLine(),
            progress: progress,
            rotate: true,
            child: const SizedBox(width: 10, height: 10),
          ),
        ),
      );
      await tester.pump();
      progress.value = 0.5;
      await tester.pump();
      // Painting succeeded without throwing for a rotated child.
      expect(find.byType(NibPathMotion), findsOneWidget);
    });
  });
}

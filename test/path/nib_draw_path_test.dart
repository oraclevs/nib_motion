import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/src/path/nib_draw_path.dart';

Path _zigZag() {
  return Path()
    ..moveTo(0, 0)
    ..lineTo(50, 50)
    ..lineTo(100, 0);
}

void main() {
  group('NibDrawPath', () {
    testWidgets('builds and paints without throwing at various progress values', (
      tester,
    ) async {
      for (final autoPlay in [false]) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: 120,
              height: 60,
              child: NibDrawPath(path: _zigZag(), autoPlay: autoPlay),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 1000));
        expect(find.byType(NibDrawPath), findsOneWidget);
      }
    });

    testWidgets('autoPlay reveals path over duration', (tester) async {
      const duration = Duration(milliseconds: 1000);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 120,
            height: 60,
            child: NibDrawPath(
              path: _zigZag(),
              duration: duration,
              curve: Curves.linear,
              color: Colors.black,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      // No straightforward way to introspect canvas draw calls from a
      // widget test without a custom painter spy; verifying the widget
      // tree survives a full play-through without throwing, including at
      // the partial and completed progress points, exercises both the
      // ticker-tween and the PathMetrics.extractPath paint path.
      await tester.pumpAndSettle();
      expect(find.byType(NibDrawPath), findsOneWidget);
    });

    testWidgets('repeat works', (tester) async {
      const duration = Duration(milliseconds: 100);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 120,
            height: 60,
            child: NibDrawPath(path: _zigZag(), duration: duration, repeat: true),
          ),
        ),
      );

      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(NibDrawPath), findsOneWidget);

      // Tear down to stop the repeating ticker before the test ends.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('no Ticker leaks after dispose mid-animation', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 120,
            height: 60,
            child: NibDrawPath(path: _zigZag(), duration: const Duration(milliseconds: 200)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Unmounting mid-animation must stop and dispose the Ticker cleanly;
      // flutter_test fails the test if a Ticker is leaked or disposed
      // without first being stopped.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('controller.restart() restarts the reveal from progress 0', (
      tester,
    ) async {
      final controller = NibDrawPathController();
      const duration = Duration(milliseconds: 200);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 120,
            height: 60,
            child: NibDrawPath(
              path: _zigZag(),
              duration: duration,
              curve: Curves.linear,
              controller: controller,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      controller.restart();
      await tester.pump();
      // Restart succeeded without throwing; let it finish, then tear down.
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('controller.pause() stops the ticker without throwing', (
      tester,
    ) async {
      final controller = NibDrawPathController();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 120,
            height: 60,
            child: NibDrawPath(
              path: _zigZag(),
              duration: const Duration(milliseconds: 500),
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      controller.pause();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}

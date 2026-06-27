import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  group('NibParallax', () {
    testWidgets('translates child vertically by scrollDelta * factor',
        (tester) async {
      final controller = ScrollController();
      const factor = 0.5;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: controller,
              child: Column(
                children: [
                  NibParallax(
                    scrollController: controller,
                    factor: factor,
                    child: const SizedBox(height: 100, width: 100),
                  ),
                  const SizedBox(height: 2000),
                ],
              ),
            ),
          ),
        ),
      );

      RenderNibMotion render() =>
          tester.renderObject<RenderNibMotion>(find.byType(NibMotion));

      expect(render().translateY.value, closeTo(0, 1e-9),
          reason: 'no parallax offset before any scroll');

      controller.jumpTo(200);
      await tester.pump();

      expect(
        render().translateY.value,
        closeTo(200 * factor, 1e-9),
        reason: 'translateY tracks scrollOffset * factor',
      );

      controller.jumpTo(50);
      await tester.pump();

      expect(render().translateY.value, closeTo(50 * factor, 1e-9),
          reason: 'updates again on further scroll');
    });

    testWidgets('factor 0 keeps child stationary regardless of scroll',
        (tester) async {
      final controller = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: controller,
              child: Column(
                children: [
                  NibParallax(
                    scrollController: controller,
                    factor: 0,
                    child: const SizedBox(height: 100, width: 100),
                  ),
                  const SizedBox(height: 2000),
                ],
              ),
            ),
          ),
        ),
      );

      RenderNibMotion render() =>
          tester.renderObject<RenderNibMotion>(find.byType(NibMotion));

      controller.jumpTo(400);
      await tester.pump();

      expect(render().translateY.value, closeTo(0, 1e-9),
          reason: 'factor 0 never moves the child');
    });

    testWidgets(
        'horizontal axis translates child by scrollDelta * factor along x',
        (tester) async {
      final controller = ScrollController();
      const factor = 0.5;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: controller,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  NibParallax(
                    scrollController: controller,
                    factor: factor,
                    axis: Axis.horizontal,
                    child: const SizedBox(height: 100, width: 100),
                  ),
                  const SizedBox(width: 2000),
                ],
              ),
            ),
          ),
        ),
      );

      RenderNibMotion render() =>
          tester.renderObject<RenderNibMotion>(find.byType(NibMotion));

      controller.jumpTo(300);
      await tester.pump();

      expect(render().translateX.value, closeTo(300 * factor, 1e-9));
      expect(render().translateY.value, closeTo(0, 1e-9));
    });

    testWidgets('disposes its scroll bridge without throwing when removed',
        (tester) async {
      final controller = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: controller,
              child: NibParallax(
                scrollController: controller,
                child: const SizedBox(height: 100, width: 100),
              ),
            ),
          ),
        ),
      );

      // Removing the widget tears down its ScrollMotionBridge and derived
      // MotionValue; this must not throw.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}

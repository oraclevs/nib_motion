import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  group('NibMotion.whileInView', () {
    testWidgets('animates when scrolled into view and reverts when scrolled out', (tester) async {
      final controller = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: NibMotionConfig(
            entranceWarmup: Duration.zero,
            child: Scaffold(
              body: SingleChildScrollView(
                controller: controller,
                child: Column(
                  children: [
                    const SizedBox(height: 700),
                    NibMotion(
                      initial: const NibAnim(opacity: 0),
                      whileInView: const NibAnim(opacity: 1),
                      transition: const NibTransition(duration: Duration(milliseconds: 200)),
                      child: const SizedBox(height: 100, width: 100),
                    ),
                    const SizedBox(height: 700),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      RenderNibMotion render() => tester.renderObject<RenderNibMotion>(find.byType(NibMotion));

      expect(render().opacity.value, closeTo(0, 1e-9), reason: 'starts at initial while off-screen');

      controller.jumpTo(300);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(render().opacity.value, closeTo(1, 1e-9), reason: 'animates to whileInView once scrolled into view');

      controller.jumpTo(0);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(render().opacity.value, closeTo(0, 1e-9), reason: 'reverts to initial once scrolled out of view');
    });

    testWidgets('viewport.once prevents reverting after the widget leaves the viewport', (tester) async {
      final controller = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: NibMotionConfig(
            entranceWarmup: Duration.zero,
            child: Scaffold(
              body: SingleChildScrollView(
                controller: controller,
                child: Column(
                  children: [
                    const SizedBox(height: 700),
                    NibMotion(
                      initial: const NibAnim(opacity: 0),
                      whileInView: const NibAnim(opacity: 1),
                      viewport: const NibInViewConfig(once: true),
                      transition: const NibTransition(duration: Duration(milliseconds: 200)),
                      child: const SizedBox(height: 100, width: 100),
                    ),
                    const SizedBox(height: 700),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      RenderNibMotion render() => tester.renderObject<RenderNibMotion>(find.byType(NibMotion));

      controller.jumpTo(300);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(render().opacity.value, closeTo(1, 1e-9), reason: 'animates to whileInView once scrolled into view');

      controller.jumpTo(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        render().opacity.value,
        closeTo(1, 1e-9),
        reason: 'stays at whileInView after leaving the viewport with once: true',
      );
    });

    testWidgets('animates when a non-nearest ancestor scroll view brings the widget into view', (tester) async {
      // Regression test: a `whileInView` widget inside a horizontal list
      // nested in a vertical scroll view must react to the *outer* scroll
      // view moving it on screen, even though its nearest `Scrollable` (the
      // horizontal list) never scrolls.
      final outerController = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: NibMotionConfig(
            entranceWarmup: Duration.zero,
            child: Scaffold(
              body: SingleChildScrollView(
                controller: outerController,
                child: Column(
                  children: [
                    const SizedBox(height: 700),
                    SizedBox(
                      height: 100,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          NibMotion(
                            initial: const NibAnim(opacity: 0),
                            whileInView: const NibAnim(opacity: 1),
                            viewport: const NibInViewConfig(once: false, amount: 0.5),
                            transition: const NibTransition(duration: Duration(milliseconds: 200)),
                            child: const SizedBox(height: 100, width: 100),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 700),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      RenderNibMotion render() => tester.renderObject<RenderNibMotion>(find.byType(NibMotion));

      expect(render().opacity.value, closeTo(0, 1e-9), reason: 'starts at initial while off-screen');

      outerController.jumpTo(300);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        render().opacity.value,
        closeTo(1, 1e-9),
        reason: 'animates to whileInView once the outer scroll view reveals it',
      );
    });

    testWidgets('animates immediately when already in view on first frame', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NibMotionConfig(
            entranceWarmup: Duration.zero,
            child: NibMotion(
              initial: const NibAnim(opacity: 0),
              whileInView: const NibAnim(opacity: 1),
              transition: const NibTransition(duration: Duration(milliseconds: 200)),
              child: const SizedBox(height: 100, width: 100),
            ),
          ),
        ),
      );

      RenderNibMotion render() => tester.renderObject<RenderNibMotion>(find.byType(NibMotion));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(render().opacity.value, closeTo(1, 1e-9), reason: 'animates to whileInView when visible on mount');
    });
  });
}

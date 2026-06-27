import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  group('NibScrollReveal', () {
    testWidgets('starts at initial (hidden) while off-screen', (tester) async {
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
                    NibScrollReveal(
                      transition: const NibTransition(
                          duration: Duration(milliseconds: 200)),
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

      RenderNibMotion render() =>
          tester.renderObject<RenderNibMotion>(find.byType(NibMotion));

      await tester.pump();
      expect(render().opacity.value, closeTo(0, 1e-9),
          reason: 'NibScrollReveal default initial is opacity 0');
      expect(render().translateY.value, closeTo(32, 1e-9),
          reason: 'NibScrollReveal default initial offsets y by 32');
    });

    testWidgets('reveals (animates to animate target) once scrolled into view',
        (tester) async {
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
                    NibScrollReveal(
                      transition: const NibTransition(
                          duration: Duration(milliseconds: 200)),
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

      RenderNibMotion render() =>
          tester.renderObject<RenderNibMotion>(find.byType(NibMotion));

      controller.jumpTo(300);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(render().opacity.value, closeTo(1, 1e-9),
          reason: 'reveals to full opacity once scrolled into view');
      expect(render().translateY.value, closeTo(0, 1e-9),
          reason: 'reveals to natural position once in view');
    });

    testWidgets('once: true keeps the reveal after scrolling back out of view',
        (tester) async {
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
                    NibScrollReveal(
                      transition: const NibTransition(
                          duration: Duration(milliseconds: 200)),
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

      RenderNibMotion render() =>
          tester.renderObject<RenderNibMotion>(find.byType(NibMotion));

      controller.jumpTo(300);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(render().opacity.value, closeTo(1, 1e-9),
          reason: 'revealed once visible');

      controller.jumpTo(0);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        render().opacity.value,
        closeTo(1, 1e-9),
        reason:
            'once: true (the default) keeps the reveal after scrolling back out of view',
      );
    });

    testWidgets(
        'once: false reverts toward initial after scrolling back out of view',
        (tester) async {
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
                    NibScrollReveal(
                      once: false,
                      transition: const NibTransition(
                          duration: Duration(milliseconds: 200)),
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

      RenderNibMotion render() =>
          tester.renderObject<RenderNibMotion>(find.byType(NibMotion));

      controller.jumpTo(300);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(render().opacity.value, closeTo(1, 1e-9),
          reason: 'revealed once visible');

      controller.jumpTo(0);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        render().opacity.value,
        closeTo(0, 1e-9),
        reason:
            'once: false reverts to initial after scrolling back out of view',
      );
    });
  });
}

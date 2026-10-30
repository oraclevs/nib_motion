import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets('loop scale shorthand and explicit axes (reduced: $reduced)',
        (tester) async {
      final controller = NibMotionController();
      addTearDown(controller.dispose);
      Widget scene(bool enabled) => NibMotionConfig(
          entranceWarmup: Duration.zero,
          reducedMotion: reduced,
          child: TickerMode(
              enabled: enabled,
              child: NibMotion(
                  controller: controller,
                  initial: const NibAnim(scale: .8),
                  animate: const NibAnim(scale: 1.2, scaleY: 1.4),
                  loopPhase: .25,
                  repeatAnimationInLoop: true,
                  transition: const NibTransition(
                      duration: Duration(seconds: 1), curve: Curves.linear),
                  child: const SizedBox(width: 20, height: 20))));
      void expectScale(double x, double y) {
        expect(controller.motionValueOf(NibProperty.scaleX)!.value,
            closeTo(x, .001));
        expect(controller.motionValueOf(NibProperty.scaleY)!.value,
            closeTo(y, .001));
      }

      await tester.pumpWidget(scene(true));
      await tester.pump();
      expectScale(reduced ? 1.2 : .9, reduced ? 1.4 : .95);
      await tester.pump(const Duration(milliseconds: 250));
      expectScale(reduced ? 1.2 : 1, reduced ? 1.4 : 1.1);
      await tester.pumpWidget(scene(false));
      await tester.pump(const Duration(seconds: 2));
      expectScale(reduced ? 1.2 : 1, reduced ? 1.4 : 1.1);
      await tester.pumpWidget(scene(true));
      await tester.pump();
      expectScale(reduced ? 1.2 : .9, reduced ? 1.4 : .95);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('phase starts in-cycle, wraps forward and responds to updates',
      (tester) async {
    final controller = NibMotionController();
    addTearDown(controller.dispose);
    Widget scene(double phase) => NibMotionConfig(
        entranceWarmup: Duration.zero,
        child: Directionality(
            textDirection: TextDirection.ltr,
            child: NibMotion(
                controller: controller,
                initial: const NibAnim(x: 0),
                animate: const NibAnim(x: 100),
                loopPhase: phase,
                loopMode: NibLoopMode.restart,
                repeatAnimationInLoop: true,
                transition: const NibTransition(
                    duration: Duration(seconds: 1), curve: Curves.linear),
                child: const SizedBox(width: 20, height: 20))));
    await tester.pumpWidget(scene(.4));
    await tester.pump();
    expect(controller.motionValueOf(NibProperty.x)!.value, closeTo(40, .01));
    await tester.pump(const Duration(milliseconds: 700));
    expect(controller.motionValueOf(NibProperty.x)!.value, closeTo(10, .01));
    await tester.pumpWidget(scene(.7));
    await tester.pump();
    expect(controller.motionValueOf(NibProperty.x)!.value, closeTo(70, .01));
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion completes once despite the starting phase',
      (tester) async {
    final controller = NibMotionController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(NibMotionConfig(
        reducedMotion: true,
        child: Directionality(
            textDirection: TextDirection.ltr,
            child: NibMotion(
                controller: controller,
                loopPhase: .5,
                repeatAnimationInLoop: true,
                initial: const NibAnim(x: 0),
                animate: const NibAnim(x: 100),
                child: const SizedBox()))));
    expect(controller.motionValueOf(NibProperty.x)!.value, 100);
    await tester.pump(const Duration(seconds: 2));
    expect(controller.motionValueOf(NibProperty.x)!.value, 100);
  });
}

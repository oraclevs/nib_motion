import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _host({
  required bool reduced,
  required Widget child,
}) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    );

RenderNibMotion _render(WidgetTester tester) {
  RenderNibMotion? found;
  void visit(RenderObject o) {
    if (o is RenderNibMotion) found ??= o;
    o.visitChildren(visit);
  }

  tester.binding.rootElement!.renderObject!.visitChildren(visit);
  return found!;
}

void main() {
  tearDown(() => NibMotionConfig.setReducedMotion(null));

  testWidgets('turning reduced motion on finishes an in-flight spring',
      (tester) async {
    final controller = NibMotionController();
    Widget build(bool reduced) => _host(
          reduced: reduced,
          child: NibMotion(
            controller: controller,
            transition: NibTransition.springGentle,
            child: const SizedBox(width: 10, height: 10),
          ),
        );
    await tester.pumpWidget(build(false));
    var done = false;
    controller.start(target: const NibAnim(x: 100, opacity: 0.5)).then((_) {
      done = true;
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(_render(tester).translateX.value, inExclusiveRange(1.0, 99.0));
    expect(done, isFalse);

    await tester.pumpWidget(build(true));
    await tester.pump();
    expect(_render(tester).translateX.value, 100);
    expect(_render(tester).opacity.value, 0.5);
    expect(done, isTrue, reason: 'the in-flight future resolves');
    expect(tester.binding.transientCallbackCount, 0,
        reason: 'no ticker keeps running');
  });

  testWidgets('turning reduced motion on finishes an in-flight tween',
      (tester) async {
    final controller = NibMotionController();
    Widget build(bool reduced) => _host(
          reduced: reduced,
          child: NibMotion(
            controller: controller,
            transition: const NibTransition(duration: Duration(seconds: 2)),
            child: const SizedBox(width: 10, height: 10),
          ),
        );
    await tester.pumpWidget(build(false));
    controller.start(target: const NibAnim(x: 60));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_render(tester).translateX.value, inExclusiveRange(1.0, 59.0));
    await tester.pumpWidget(build(true));
    await tester.pump();
    expect(_render(tester).translateX.value, 60);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('turning reduced motion on stops a repeat loop', (tester) async {
    Widget build(bool reduced) => _host(
          reduced: reduced,
          child: NibMotionConfig(
            entranceWarmup: Duration.zero,
            child: const NibMotion(
              initial: NibAnim(x: 0),
              animate: NibAnim(x: 100),
              repeatAnimationInLoop: true,
              transition: NibTransition(
                  duration: Duration(seconds: 1), curve: Curves.linear),
              child: SizedBox(width: 10, height: 10),
            ),
          ),
        );
    await tester.pumpWidget(build(false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpWidget(build(true));
    await tester.pump();
    final x = _render(tester).translateX.value;
    expect(x, 100, reason: 'jumps to the end of the cycle');
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pump(const Duration(seconds: 3));
    expect(_render(tester).translateX.value, 100);
  });

  testWidgets('turning reduced motion on finishes keyframes', (tester) async {
    Widget build(bool reduced) => _host(
          reduced: reduced,
          child: NibMotionConfig(
            entranceWarmup: Duration.zero,
            child: const NibMotion(
              keyframes: [
                NibKeyframe(at: 0, value: NibAnim(x: 0)),
                NibKeyframe(at: 1, value: NibAnim(x: 80)),
              ],
              transition: NibTransition(
                  duration: Duration(seconds: 2), curve: Curves.linear),
              child: SizedBox(width: 10, height: 10),
            ),
          ),
        );
    await tester.pumpWidget(build(false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_render(tester).translateX.value, inExclusiveRange(1.0, 79.0));
    await tester.pumpWidget(build(true));
    await tester.pump();
    expect(_render(tester).translateX.value, 80);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('NibMotionConfig(reducedMotion:) changes apply mid-flight too',
      (tester) async {
    final controller = NibMotionController();
    Widget build(bool? reduced) => Directionality(
          textDirection: TextDirection.ltr,
          child: NibMotionConfig(
            reducedMotion: reduced,
            child: Align(
              alignment: Alignment.topLeft,
              child: NibMotion(
                controller: controller,
                transition: const NibTransition(duration: Duration(seconds: 2)),
                child: const SizedBox(width: 10, height: 10),
              ),
            ),
          ),
        );
    await tester.pumpWidget(build(false));
    controller.start(target: const NibAnim(x: 50));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(build(true));
    await tester.pump();
    expect(_render(tester).translateX.value, 50);
  });

  testWidgets('turning it off again does not restart anything', (tester) async {
    final controller = NibMotionController();
    Widget build(bool reduced) => _host(
          reduced: reduced,
          child: NibMotion(
            controller: controller,
            child: const SizedBox(width: 10, height: 10),
          ),
        );
    await tester.pumpWidget(build(true));
    controller.start(target: const NibAnim(x: 30));
    await tester.pump();
    expect(_render(tester).translateX.value, 30);
    await tester.pumpWidget(build(false));
    await tester.pump(const Duration(seconds: 1));
    expect(_render(tester).translateX.value, 30);
    expect(tester.binding.transientCallbackCount, 0);
  });
}

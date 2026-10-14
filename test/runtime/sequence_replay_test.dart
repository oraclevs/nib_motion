import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  testWidgets('play() while already playing does not start a second run',
      (tester) async {
    final controller = NibMotionController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: NibMotion(
        controller: controller,
        transition: const NibTransition(duration: Duration(milliseconds: 100)),
        child: const SizedBox(width: 10, height: 10),
      ),
    ));

    var calls = 0;
    final sequence = NibAnimationSequence(controller)
        .animate(const NibAnim(x: 50))
        .call(() => calls++);
    addTearDown(sequence.dispose);

    var firstDone = false;
    var secondDone = false;
    sequence.play().then((_) => firstDone = true);
    await tester.pump(const Duration(milliseconds: 20));
    sequence.play().then((_) => secondDone = true);
    await tester.pumpAndSettle();

    expect(calls, 1, reason: 'the sequence ran once, not once per play() call');
    expect(firstDone, isTrue);
    expect(secondDone, isTrue,
        reason: 'the second future tracks the in-progress run');
  });

  testWidgets('stop() then play() restarts cleanly with a single run',
      (tester) async {
    final controller = NibMotionController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: NibMotion(
        controller: controller,
        transition: const NibTransition(duration: Duration(milliseconds: 100)),
        child: const SizedBox(width: 10, height: 10),
      ),
    ));
    var calls = 0;
    final sequence = NibAnimationSequence(controller)
        .animate(const NibAnim(x: 50))
        .call(() => calls++);
    addTearDown(sequence.dispose);

    sequence.play();
    await tester.pump(const Duration(milliseconds: 20));
    sequence.stop();
    var done = false;
    sequence.play().then((_) => done = true);
    await tester.pumpAndSettle();
    expect(calls, 1, reason: 'the stopped run must not resume alongside');
    expect(done, isTrue);
  });
}

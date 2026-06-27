import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _wrap(Widget child) {
  return Directionality(
      textDirection: TextDirection.ltr, child: Center(child: child));
}

RenderNibMotion _findRenderNibMotion(WidgetTester tester) {
  RenderNibMotion? found;
  void visit(RenderObject object) {
    if (object is RenderNibMotion) {
      found = object;
      return;
    }
    object.visitChildren(visit);
  }

  tester.binding.rootElement!.renderObject!.visitChildren(visit);
  return found!;
}

void main() {
  group('NibAnimationSequence', () {
    testWidgets(
        'animate -> wait -> animate -> call runs in order and completes',
        (tester) async {
      final controller = NibMotionController();
      addTearDown(controller.dispose);

      const transition = NibTransition(duration: Duration(milliseconds: 20));

      await tester.pumpWidget(
        _wrap(
          NibMotion(
            initial: const NibAnim(opacity: 0.0, x: 0.0),
            controller: controller,
            transition: transition,
            child: const SizedBox(width: 20, height: 20),
          ),
        ),
      );

      final render = _findRenderNibMotion(tester);

      var callbackRan = false;
      var doneFired = false;

      final sequence = NibAnimationSequence(controller)
          .animate(const NibAnim(opacity: 1.0))
          .wait(const Duration(milliseconds: 30))
          .animate(const NibAnim(x: 50.0))
          .call(() => callbackRan = true);
      addTearDown(sequence.dispose);

      sequence.play().then((_) => doneFired = true);

      // Step 1 (animate opacity) runs first; x must not have moved yet.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(render.opacity.value, closeTo(1.0, 0.01));
      expect(render.translateX.value, closeTo(0.0, 0.01));
      expect(callbackRan, isFalse);

      // Still inside the `.wait(30ms)` — x must not have moved.
      await tester.pump(const Duration(milliseconds: 10));
      expect(render.translateX.value, closeTo(0.0, 0.01));
      expect(callbackRan, isFalse);

      // Past the wait; step 3 (animate x) runs. The wait's Timer fires
      // mid-pump, so the tween it starts needs an extra pump cycle beyond
      // its nominal duration before it's actually ticked to completion.
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));
      expect(render.translateX.value, closeTo(50.0, 0.01));

      await tester.pumpAndSettle();
      expect(callbackRan, isTrue);
      expect(doneFired, isTrue);
    });

    testWidgets('loop(2) runs the recorded steps twice then completes',
        (tester) async {
      final controller = NibMotionController();
      addTearDown(controller.dispose);

      const transition = NibTransition(duration: Duration(milliseconds: 10));

      await tester.pumpWidget(
        _wrap(
          NibMotion(
            initial: const NibAnim(opacity: 0.0),
            controller: controller,
            transition: transition,
            child: const SizedBox(width: 20, height: 20),
          ),
        ),
      );

      var runCount = 0;

      final sequence = NibAnimationSequence(controller)
          .animate(const NibAnim(opacity: 1.0))
          .call(() => runCount++)
          .animate(const NibAnim(opacity: 0.0))
          .loop(2);
      addTearDown(sequence.dispose);

      var doneFired = false;
      sequence.play().then((_) => doneFired = true);

      // Pump enough virtual time for both repetitions' animations to finish.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pump();

      expect(runCount, 2);
      expect(doneFired, isTrue);
    });

    testWidgets('stop halts a forever loop', (tester) async {
      final controller = NibMotionController();
      addTearDown(controller.dispose);

      const transition = NibTransition(duration: Duration(milliseconds: 10));

      await tester.pumpWidget(
        _wrap(
          NibMotion(
            initial: const NibAnim(opacity: 0.0),
            controller: controller,
            transition: transition,
            child: const SizedBox(width: 20, height: 20),
          ),
        ),
      );

      var runCount = 0;

      final sequence = NibAnimationSequence(controller)
          .animate(const NibAnim(opacity: 1.0))
          .call(() => runCount++)
          .animate(const NibAnim(opacity: 0.0))
          .loop();
      addTearDown(sequence.dispose);

      var doneFired = false;
      sequence.play().then((_) => doneFired = true);

      // Let a few iterations run.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      final countBeforeStop = runCount;
      expect(countBeforeStop, greaterThan(0));

      sequence.stop();

      // Advance well beyond what further iterations would need; the count
      // must not increase, and play()'s future never completes.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(runCount, countBeforeStop);
      expect(doneFired, isFalse);
    });
  });
}

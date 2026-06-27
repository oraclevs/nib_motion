import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _wrap(Widget child) {
  return Directionality(textDirection: TextDirection.ltr, child: Center(child: child));
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

List<RenderNibMotion> _findAllRenderNibMotion(WidgetTester tester) {
  final found = <RenderNibMotion>[];
  void visit(RenderObject object) {
    if (object is RenderNibMotion) {
      found.add(object);
    }
    object.visitChildren(visit);
  }

  tester.binding.rootElement!.renderObject!.visitChildren(visit);
  return found;
}

void main() {
  group('NibMotionController', () {
    testWidgets('start animates the attached NibMotion to the target', (tester) async {
      final controller = NibMotionController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          NibMotion(
            initial: const NibAnim(opacity: 1.0),
            controller: controller,
            transition: const NibTransition(duration: Duration(milliseconds: 50)),
            child: const SizedBox(width: 50, height: 50),
          ),
        ),
      );

      final renderObject = _findRenderNibMotion(tester);
      expect(renderObject.opacity.value, 1.0);

      controller.start(target: const NibAnim(opacity: 0.0));
      await tester.pumpAndSettle();

      expect(renderObject.opacity.value, closeTo(0.0, 0.01));
    });

    testWidgets('start() with no arguments replays the entrance animation', (tester) async {
      final controller = NibMotionController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          NibMotion(
            initial: const NibAnim(opacity: 0.0),
            animate: const NibAnim(opacity: 1.0),
            controller: controller,
            transition: const NibTransition(duration: Duration(milliseconds: 50)),
            child: const SizedBox(width: 50, height: 50),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final renderObject = _findRenderNibMotion(tester);
      expect(renderObject.opacity.value, closeTo(1.0, 0.01));

      controller.start();
      await tester.pump();

      // The entrance animation reset jumps opacity back toward `initial`
      // before re-animating toward `animate`.
      expect(renderObject.opacity.value, closeTo(0.0, 0.01));

      await tester.pumpAndSettle();
      expect(renderObject.opacity.value, closeTo(1.0, 0.01));
    });

    testWidgets('start(keyframes: ...) plays the keyframe sequence once', (tester) async {
      final controller = NibMotionController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          NibMotion(
            initial: const NibAnim(opacity: 1.0),
            controller: controller,
            transition: const NibTransition(duration: Duration(milliseconds: 50)),
            child: const SizedBox(width: 50, height: 50),
          ),
        ),
      );

      final renderObject = _findRenderNibMotion(tester);
      expect(renderObject.opacity.value, closeTo(1.0, 0.01));

      controller.start(
        keyframes: const [
          NibKeyframe(at: 0.0, value: NibAnim(opacity: 0.0)),
          NibKeyframe(at: 1.0, value: NibAnim(opacity: 1.0)),
        ],
      );

      await tester.pump();
      expect(renderObject.opacity.value, closeTo(0.0, 0.01));

      await tester.pumpAndSettle();
      expect(renderObject.opacity.value, closeTo(1.0, 0.01));
    });

    test('start asserts when both target and keyframes are provided', () {
      final controller = NibMotionController();
      addTearDown(controller.dispose);

      expect(
        () => controller.start(
          target: const NibAnim(opacity: 1.0),
          keyframes: const [NibKeyframe(at: 0.0, value: NibAnim.identity)],
        ),
        throwsAssertionError,
      );
    });

    testWidgets('set jumps instantly without animating', (tester) async {
      final controller = NibMotionController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          NibMotion(
            initial: const NibAnim(opacity: 1.0),
            controller: controller,
            transition: const NibTransition(duration: Duration(milliseconds: 200)),
            child: const SizedBox(width: 50, height: 50),
          ),
        ),
      );

      final renderObject = _findRenderNibMotion(tester);

      controller.set(const NibAnim(opacity: 0.0));

      expect(renderObject.opacity.value, 0.0);
    });

    testWidgets('stop freezes MotionValues at their current value', (tester) async {
      final controller = NibMotionController();
      addTearDown(controller.dispose);

      const spring = NibTransition(spring: NibSpringDescription(stiffness: 50, damping: 4));

      await tester.pumpWidget(
        _wrap(
          NibMotion(
            initial: const NibAnim(x: 0.0),
            controller: controller,
            transition: spring,
            child: const SizedBox(width: 50, height: 50),
          ),
        ),
      );

      final renderObject = _findRenderNibMotion(tester);

      controller.start(target: const NibAnim(x: 1000.0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final valueAtStop = renderObject.translateX.value;
      expect(valueAtStop, isNot(0.0));

      controller.stop();
      await tester.pump(const Duration(milliseconds: 50));

      expect(renderObject.translateX.value, valueAtStop);
    });

    testWidgets('sequence runs steps in order, waiting for each to complete', (tester) async {
      final controller = NibMotionController();
      addTearDown(controller.dispose);

      const transition = NibTransition(duration: Duration(milliseconds: 50));

      await tester.pumpWidget(
        _wrap(
          NibMotion(
            initial: const NibAnim(opacity: 1.0, x: 0.0),
            controller: controller,
            transition: transition,
            child: const SizedBox(width: 50, height: 50),
          ),
        ),
      );

      final renderObject = _findRenderNibMotion(tester);

      controller.sequence(const [
        NibMotionSequenceStep(target: NibAnim(opacity: 0.0)),
        NibMotionSequenceStep(target: NibAnim(x: 100.0)),
      ]);

      // Before step 1 completes, step 2 must not have started.
      await tester.pump(const Duration(milliseconds: 40));
      expect(renderObject.translateX.value, 0.0);

      await tester.pumpAndSettle();

      expect(renderObject.opacity.value, closeTo(0.0, 0.01));
      expect(renderObject.translateX.value, closeTo(100.0, 0.01));
    });

    testWidgets('disposing the NibMotion detaches without error', (tester) async {
      final controller = NibMotionController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          NibMotion(
            initial: const NibAnim(opacity: 1.0),
            controller: controller,
            child: const SizedBox(width: 50, height: 50),
          ),
        ),
      );

      await tester.pumpWidget(const SizedBox());

      expect(tester.takeException(), isNull);

      controller.set(const NibAnim(opacity: 0.0));
      controller.start(target: const NibAnim(opacity: 1.0));
      controller.stop();

      expect(tester.takeException(), isNull);
    });

    testWidgets('multiple NibMotion instances attached to one controller all respond to start', (tester) async {
      final controller = NibMotionController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NibMotion(
                initial: const NibAnim(opacity: 1.0),
                controller: controller,
                transition: const NibTransition(duration: Duration(milliseconds: 50)),
                child: const SizedBox(width: 50, height: 50),
              ),
              NibMotion(
                initial: const NibAnim(opacity: 1.0),
                controller: controller,
                transition: const NibTransition(duration: Duration(milliseconds: 50)),
                child: const SizedBox(width: 50, height: 50),
              ),
            ],
          ),
        ),
      );

      final renderObjects = _findAllRenderNibMotion(tester);
      expect(renderObjects, hasLength(2));

      controller.start(target: const NibAnim(opacity: 0.0));
      await tester.pumpAndSettle();

      for (final renderObject in renderObjects) {
        expect(renderObject.opacity.value, closeTo(0.0, 0.01));
      }
    });
  });
}

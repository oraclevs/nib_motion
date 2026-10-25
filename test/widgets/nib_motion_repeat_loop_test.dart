import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _wrap(Widget child) {
  return NibMotionConfig(
    entranceWarmup: Duration.zero,
    child: Directionality(
        textDirection: TextDirection.ltr, child: Center(child: child)),
  );
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
  group('NibMotion.repeatAnimationInLoop', () {
    testWidgets('restarting during entrance warmup ignores the old loop',
        (tester) async {
      NibMotionConfig.resetAppStartTime();
      NibMotionGate.reset();
      final controller = NibMotionController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        NibMotionConfig(
          entranceWarmup: const Duration(milliseconds: 400),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: NibMotion(
              controller: controller,
              initial: const NibAnim(opacity: 0),
              animate: const NibAnim(opacity: 1),
              repeatAnimationInLoop: true,
              transition:
                  const NibTransition(duration: Duration(milliseconds: 100)),
              child: const SizedBox(width: 50, height: 50),
            ),
          ),
        ),
      );

      // Replaces the controller while its first warmup callback is pending.
      controller.repeat();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(_findRenderNibMotion(tester).opacity.value, closeTo(1, 0.05));
    });

    testWidgets('stopping during entrance warmup never starts the loop',
        (tester) async {
      NibMotionConfig.resetAppStartTime();
      NibMotionGate.reset();
      final controller = NibMotionController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        NibMotionConfig(
          entranceWarmup: const Duration(milliseconds: 400),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: NibMotion(
              controller: controller,
              initial: const NibAnim(opacity: 0),
              animate: const NibAnim(opacity: 1),
              repeatAnimationInLoop: true,
              transition:
                  const NibTransition(duration: Duration(milliseconds: 100)),
              child: const SizedBox(width: 50, height: 50),
            ),
          ),
        ),
      );

      controller.repeat(false);
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      expect(_findRenderNibMotion(tester).opacity.value, 0);
    });

    testWidgets('scrolling a warming loop out of a list disposes safely',
        (tester) async {
      NibMotionConfig.resetAppStartTime();
      NibMotionGate.reset();
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        NibMotionConfig(
          entranceWarmup: const Duration(milliseconds: 400),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: ListView.builder(
              controller: scrollController,
              itemExtent: 100,
              itemCount: 30,
              itemBuilder: (context, index) => index == 0
                  ? const NibMotion(
                      key: ValueKey('warming-loop'),
                      initial: NibAnim(opacity: 0),
                      animate: NibAnim(opacity: 1),
                      repeatAnimationInLoop: true,
                      child: SizedBox(height: 100),
                    )
                  : const SizedBox(height: 100),
            ),
          ),
        ),
      );

      scrollController.jumpTo(1500);
      await tester.pump();
      expect(find.byKey(const ValueKey('warming-loop')), findsNothing);
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
    });

    testWidgets('ping-pongs opacity between initial and animate forever',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibMotion(
            initial: const NibAnim(opacity: 0.0),
            animate: const NibAnim(opacity: 1.0),
            repeatAnimationInLoop: true,
            transition:
                const NibTransition(duration: Duration(milliseconds: 100)),
            child: const SizedBox(width: 50, height: 50),
          ),
        ),
      );

      // Let the entrance gate / warmup resolve and the loop start.
      await tester.pump();

      final renderObject = _findRenderNibMotion(tester);
      expect(renderObject.opacity.value, closeTo(0.0, 0.05));

      await tester.pump(const Duration(milliseconds: 100));
      expect(renderObject.opacity.value, closeTo(1.0, 0.05));

      await tester.pump(const Duration(milliseconds: 100));
      expect(renderObject.opacity.value, closeTo(0.0, 0.05));

      await tester.pump(const Duration(milliseconds: 100));
      expect(renderObject.opacity.value, closeTo(1.0, 0.05));
    });

    testWidgets(
        'NibMotionController.repeat() starts the loop on a widget with repeatAnimationInLoop: false',
        (
      tester,
    ) async {
      final controller = NibMotionController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          NibMotion(
            initial: const NibAnim(opacity: 0.0),
            animate: const NibAnim(opacity: 1.0),
            controller: controller,
            transition:
                const NibTransition(duration: Duration(milliseconds: 100)),
            child: const SizedBox(width: 50, height: 50),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final renderObject = _findRenderNibMotion(tester);
      expect(renderObject.opacity.value, closeTo(1.0, 0.01));

      controller.repeat();
      await tester.pump(const Duration(milliseconds: 100));
      expect(renderObject.opacity.value, closeTo(0.0, 0.05));

      await tester.pump(const Duration(milliseconds: 100));
      expect(renderObject.opacity.value, closeTo(1.0, 0.05));

      controller.repeat(false);
      final valueAtStop = renderObject.opacity.value;
      await tester.pump(const Duration(milliseconds: 100));
      expect(renderObject.opacity.value, valueAtStop);
    });
  });
}

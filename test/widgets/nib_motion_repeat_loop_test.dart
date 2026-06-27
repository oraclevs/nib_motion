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

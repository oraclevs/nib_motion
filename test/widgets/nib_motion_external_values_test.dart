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

void main() {
  group('NibMotion.motionValues', () {
    testWidgets('an externally-provided MotionValue drives the render object directly', (tester) async {
      final opacity = MotionValue<double>(1.0);

      await tester.pumpWidget(
        _wrap(
          NibMotion(
            motionValues: NibMotionValues(opacity: opacity),
            child: const SizedBox(width: 50, height: 50),
          ),
        ),
      );

      final renderObject = _findRenderNibMotion(tester);
      expect(renderObject.opacity, same(opacity));

      opacity.value = 0.25;
      expect(renderObject.opacity.value, 0.25);
    });

    testWidgets('disposing NibMotion does not dispose an externally-provided MotionValue', (tester) async {
      final opacity = MotionValue<double>(1.0);
      addTearDown(opacity.dispose);

      await tester.pumpWidget(
        _wrap(
          NibMotion(
            motionValues: NibMotionValues(opacity: opacity),
            child: const SizedBox(width: 50, height: 50),
          ),
        ),
      );

      await tester.pumpWidget(_wrap(const SizedBox(width: 50, height: 50)));

      expect(() => opacity.value = 0.5, returnsNormally);
      expect(opacity.value, 0.5);
    });
  });
}

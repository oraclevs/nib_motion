import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _wrap(Widget child) {
  return NibMotionConfig(
    entranceWarmup: Duration.zero,
    child: Directionality(textDirection: TextDirection.ltr, child: Center(child: child)),
  );
}

RenderNibMotion _findRenderNibMotion(WidgetTester tester) {
  RenderNibMotion? found;
  void visit(RenderObject object) {
    if (object is RenderNibMotion) found = object;
    object.visitChildren(visit);
  }

  tester.binding.rootElement!.renderObject!.visitChildren(visit);
  return found!;
}

void main() {
  group('NibMotion keyframes', () {
    testWidgets('animates opacity through each keyframe over the transition duration', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibMotion(
            keyframes: const [
              NibKeyframe(at: 0.0, value: NibAnim(opacity: 0)),
              NibKeyframe(at: 0.5, value: NibAnim(opacity: 1)),
              NibKeyframe(at: 1.0, value: NibAnim(opacity: 0)),
            ],
            transition: const NibTransition(duration: Duration(milliseconds: 100), curve: Curves.linear),
            child: const SizedBox(width: 10, height: 10),
          ),
        ),
      );

      final render = _findRenderNibMotion(tester);
      expect(render.opacity.value, closeTo(0.0, 0.001));

      await tester.pump(const Duration(milliseconds: 50));
      expect(render.opacity.value, closeTo(1.0, 0.001));

      await tester.pump(const Duration(milliseconds: 50));
      expect(render.opacity.value, closeTo(0.0, 0.001));
    });
  });
}

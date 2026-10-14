import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  testWidgets('animating never rebuilds the child subtree', (tester) async {
    var childBuilds = 0;
    final controller = NibMotionController();
    final child = Builder(builder: (context) {
      childBuilds++;
      return const SizedBox(width: 20, height: 20);
    });

    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: NibMotion(
        controller: controller,
        initial: const NibAnim(opacity: 0, x: -50),
        animate: const NibAnim(opacity: 1, x: 0),
        child: child,
      ),
    ));
    final buildsAfterMount = childBuilds;

    controller.start(
        target: const NibAnim(x: 100, scale: 1.5, rotate: 0.25, opacity: 0.5),
        transition: NibTransition.springWobbly);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    controller.start(
        target: const NibAnim(x: 0),
        transition: const NibTransition(duration: Duration(milliseconds: 300)));
    await tester.pumpAndSettle();

    expect(childBuilds, buildsAfterMount,
        reason: 'MotionValue changes must repaint, never rebuild');
  });
}

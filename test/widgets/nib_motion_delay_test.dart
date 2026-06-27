import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  testWidgets(
      'NibTransition.delay is honored before the initial enter animation starts',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NibMotionConfig(
          entranceWarmup: Duration.zero,
          child: NibMotion(
            initial: const NibAnim(x: -100),
            animate: const NibAnim(x: 0),
            transition: const NibTransition(
              delay: Duration(milliseconds: 300),
              duration: Duration(milliseconds: 200),
            ),
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      ),
    );

    RenderNibMotion render() =>
        tester.renderObject<RenderNibMotion>(find.byType(NibMotion));

    expect(render().translateX.value, closeTo(-100, 1e-9),
        reason: 'starts at initial');

    await tester.pump(const Duration(milliseconds: 299));
    expect(render().translateX.value, closeTo(-100, 1e-9),
        reason: 'stays at initial until delay elapses');

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 200));
    expect(render().translateX.value, closeTo(0, 1e-9),
        reason: 'reaches animate after delay + duration');
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  group('SpringSolver', () {
    testWidgets(
      'gentle spring from 0 to 100 reaches within 1.0 of target within 2 seconds',
      (WidgetTester tester) async {
        await tester.pumpWidget(const SizedBox());
        final value = MotionValue<double>(0.0);
        final solver = SpringSolver(
          vsync: const TestVSync(),
          value: value,
          spring: NibSpringDescription.gentle,
        );

        solver.animateTo(target: 100.0);
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));

        expect((value.value - 100.0).abs(), lessThan(1.0));

        solver.dispose();
      },
    );

    testWidgets(
      'wobbly spring with high initial velocity overshoots target then settles',
      (WidgetTester tester) async {
        await tester.pumpWidget(const SizedBox());
        final value = MotionValue<double>(0.0);
        final solver = SpringSolver(
          vsync: const TestVSync(),
          value: value,
          spring: NibSpringDescription.wobbly,
        );

        solver.animateTo(target: 100.0, initialVelocity: 1000.0);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        expect(value.value, greaterThan(100.0));

        await tester.pump(const Duration(seconds: 3));

        expect((value.value - 100.0).abs(), lessThan(1.0));

        solver.dispose();
      },
    );

    testWidgets('stop() halts the animation at its current value', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const SizedBox());
      final value = MotionValue<double>(0.0);
      final solver = SpringSolver(
        vsync: const TestVSync(),
        value: value,
        spring: NibSpringDescription.gentle,
      );

      solver.animateTo(target: 100.0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final valueAtStop = value.value;
      expect(valueAtStop, isNot(0.0));
      expect(valueAtStop, isNot(100.0));

      solver.stop();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      expect(value.value, valueAtStop);

      solver.dispose();
    });

    testWidgets(
      'a second animateTo call carries over the velocity of the first',
      (WidgetTester tester) async {
        await tester.pumpWidget(const SizedBox());
        final value = MotionValue<double>(0.0);
        final solver = SpringSolver(
          vsync: const TestVSync(),
          value: value,
          spring: NibSpringDescription.gentle,
        );

        solver.animateTo(target: 100.0);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final velocityBeforeInterrupt = solver.velocity;
        expect(velocityBeforeInterrupt, isNot(0.0));

        solver.animateTo(target: 200.0);

        expect(solver.velocity, closeTo(velocityBeforeInterrupt, 0.001));

        solver.dispose();
      },
    );

    testWidgets('dispose() after animateTo does not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const SizedBox());
      final value = MotionValue<double>(0.0);
      final solver = SpringSolver(
        vsync: const TestVSync(),
        value: value,
        spring: NibSpringDescription.snappy,
      );

      solver.animateTo(target: 100.0);
      await tester.pump();

      expect(() => solver.dispose(), returnsNormally);
    });
  });
}

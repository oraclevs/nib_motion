import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _wrap(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: child),
    );

RenderNibMotion _render(WidgetTester tester) {
  RenderNibMotion? found;
  void visit(RenderObject o) {
    if (o is RenderNibMotion) found ??= o;
    o.visitChildren(visit);
  }

  tester.binding.rootElement!.renderObject!.visitChildren(visit);
  return found!;
}

void main() {
  group('NibSpringDescription validation', () {
    test('rejects non-positive or non-finite mass/stiffness, bad damping', () {
      expect(() => NibSpringDescription(mass: 0), throwsAssertionError);
      expect(() => NibSpringDescription(mass: -1), throwsAssertionError);
      expect(() => NibSpringDescription(stiffness: 0), throwsAssertionError);
      expect(() => NibSpringDescription(damping: -0.1), throwsAssertionError);
      expect(
          () => NibSpringDescription(mass: double.nan), throwsAssertionError);
      expect(() => NibSpringDescription(stiffness: double.infinity),
          throwsAssertionError);
      expect(() => NibSpringDescription(damping: double.nan),
          throwsAssertionError);
      // Valid edge: zero damping is an undamped spring.
      expect(NibSpringDescription(damping: 0).damping, 0);
    });

    test('unchecked descriptions are sanitised before reaching the simulation',
        () {
      const bad = NibSpringDescription.unchecked(
          mass: 0, stiffness: double.nan, damping: double.infinity);
      final flutterSpring = bad.toFlutter();
      expect(flutterSpring.mass, greaterThan(0));
      expect(flutterSpring.mass.isFinite, isTrue);
      expect(flutterSpring.stiffness, greaterThan(0));
      expect(flutterSpring.stiffness.isFinite, isTrue);
      expect(flutterSpring.damping.isFinite, isTrue);
      expect(flutterSpring.damping, greaterThanOrEqualTo(0));
    });

    testWidgets('a zero-mass spring (release path) cannot poison the value',
        (tester) async {
      final value = MotionValue<double>(0);
      final solver = SpringSolver(
        vsync: const TestVSync(),
        value: value,
        spring: const NibSpringDescription.unchecked(mass: 0),
      );
      solver.animateTo(target: 100);
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(value.value.isFinite, isTrue, reason: 'frame $i');
      }
      await tester.pump(const Duration(seconds: 10));
      expect(value.value, closeTo(100, 0.01));
      solver.dispose();
    });
  });

  group('NibTransition validation', () {
    test('validate() rejects negative durations, delays and staggers', () {
      const negative = Duration(milliseconds: -1);
      expect(() => const NibTransition(duration: negative).validate(),
          throwsArgumentError);
      expect(() => const NibTransition(delay: negative).validate(),
          throwsArgumentError);
      expect(() => const NibTransition(staggerChildren: negative).validate(),
          throwsArgumentError);
      expect(() => const NibTransition(delayChildren: negative).validate(),
          throwsArgumentError);
      const NibTransition(duration: Duration.zero).validate();
      NibTransition.springGentle.validate();
    });

    testWidgets('NibMotion refuses a negative-duration transition',
        (tester) async {
      final controller = NibMotionController();
      await tester.pumpWidget(_wrap(NibMotion(
        controller: controller,
        child: const SizedBox(width: 10, height: 10),
      )));
      expect(
          () => controller.start(
                target: const NibAnim(x: 10),
                transition:
                    const NibTransition(duration: Duration(milliseconds: -5)),
              ),
          throwsArgumentError);
      expect(_render(tester).translateX.value, 0);
    });
  });

  group('drivers reject non-finite input', () {
    testWidgets('SpringSolver NaN / infinite target', (tester) async {
      final value = MotionValue<double>(5);
      final solver = SpringSolver(
          vsync: const TestVSync(),
          value: value,
          spring: NibSpringDescription.gentle);
      expect(() => solver.animateTo(target: double.nan), throwsArgumentError);
      expect(
          () => solver.animateTo(target: double.infinity), throwsArgumentError);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(value.value, 5, reason: 'rejected targets never start anything');
      solver.dispose();
    });

    testWidgets('SpringSolver non-finite initial velocity', (tester) async {
      final value = MotionValue<double>(0);
      final solver = SpringSolver(
          vsync: const TestVSync(),
          value: value,
          spring: NibSpringDescription.gentle);
      expect(() => solver.animateTo(target: 10, initialVelocity: double.nan),
          throwsArgumentError);
      solver.dispose();
    });

    testWidgets('InertiaSolver NaN velocity / bounds', (tester) async {
      final value = MotionValue<double>(0);
      final solver = InertiaSolver(vsync: const TestVSync(), value: value);
      expect(() => solver.animateTo(velocity: double.nan), throwsArgumentError);
      expect(() => solver.animateTo(velocity: 10, max: double.nan),
          throwsArgumentError);
      solver.dispose();
    });

    testWidgets('MultiSpringSolver non-finite channel target', (tester) async {
      final value = MotionValue<Offset>(Offset.zero);
      final solver = MultiSpringSolver<Offset>(
        vsync: const TestVSync(),
        value: value,
        converter: MotionConverter.offset,
        spring: NibSpringDescription.gentle,
      );
      expect(() => solver.animateTo(const Offset(double.nan, 1)),
          throwsArgumentError);
      expect(value.value, Offset.zero);
      solver.dispose();
    });

    test('MotionValue.update rejects non-finite doubles, keeps the old value',
        () {
      final v = MotionValue<double>(3);
      expect(() => v.update(double.nan), throwsArgumentError);
      expect(() => v.update(double.infinity), throwsArgumentError);
      expect(() => v.value = double.negativeInfinity, throwsArgumentError);
      expect(v.value, 3);
      var notified = 0;
      v.addListener(() => notified++);
      v.update(4, velocity: double.nan);
      expect(v.value, 4);
      expect(v.velocity, 0, reason: 'a non-finite velocity is dropped');
      expect(notified, 1);
    });

    testWidgets('NibSimulationDriver stays finite for a NaN simulation',
        (tester) async {
      final value = MotionValue<double>(1);
      final driver =
          NibSimulationDriver(vsync: const TestVSync(), value: value);
      driver.run(_NanSimulation());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(value.value, 1, reason: 'NaN position must not be written');
      expect(tester.takeException(), isA<ArgumentError>(),
          reason: 'debug builds report the bad simulation loudly');
      driver.stop();
    });
  });

  group('NibMotion rejects non-finite targets', () {
    testWidgets('animateTo NaN x', (tester) async {
      final controller = NibMotionController();
      await tester.pumpWidget(_wrap(NibMotion(
        controller: controller,
        child: const SizedBox(width: 10, height: 10),
      )));
      expect(() => controller.start(target: const NibAnim(x: double.nan)),
          throwsArgumentError);
      expect(() => controller.set(const NibAnim(opacity: double.infinity)),
          throwsArgumentError);
      await tester.pumpAndSettle();
      expect(_render(tester).translateX.value, 0);
      expect(_render(tester).opacity.value, 1);
    });

    testWidgets('a finite target after a rejected one still works',
        (tester) async {
      final controller = NibMotionController();
      await tester.pumpWidget(_wrap(NibMotion(
        controller: controller,
        transition: NibTransition.springSnappy,
        child: const SizedBox(width: 10, height: 10),
      )));
      expect(() => controller.start(target: const NibAnim(x: double.nan)),
          throwsArgumentError);
      controller.start(target: const NibAnim(x: 40));
      await tester.pumpAndSettle();
      expect(_render(tester).translateX.value, 40);
    });
  });
}

class _NanSimulation extends Simulation {
  @override
  double x(double time) => double.nan;
  @override
  double dx(double time) => 0;
  @override
  bool isDone(double time) => false;
}

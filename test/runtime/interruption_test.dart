import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _wrap(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: child),
    );

double _translateX(WidgetTester tester) {
  RenderNibMotion? render;
  void visit(RenderObject o) {
    if (o is RenderNibMotion) render = o;
    o.visitChildren(visit);
  }

  tester.binding.rootElement!.renderObject!.visitChildren(visit);
  return render!.translateX.value;
}

void main() {
  group('MotionValue velocity', () {
    test('update publishes velocity, plain assignment resets it', () {
      final v = MotionValue<double>(0);
      expect(v.velocity, 0);
      v.update(5, velocity: 2);
      expect(v.value, 5);
      expect(v.velocity, 2);
      v.value = 6;
      expect(v.velocity, 0, reason: 'a jump carries no momentum');
    });

    test('update with unchanged value still records velocity, no notify', () {
      final v = MotionValue<double>(1);
      var notified = 0;
      v.addListener(() => notified++);
      v.update(1, velocity: 3);
      expect(v.velocity, 3);
      expect(notified, 0);
    });

    test('mapRange scales source velocity by the segment slope', () {
      final source = MotionValue<double>(0);
      final mapped = source.mapRange([0, 100], [0, 1]);
      source.update(50, velocity: 200);
      expect(mapped.value, closeTo(0.5, 1e-9));
      expect(mapped.velocity, closeTo(2.0, 1e-9));
    });
  });

  group('driver velocity handoff', () {
    testWidgets('spring interrupted by stop() keeps its momentum on restart',
        (tester) async {
      final value = MotionValue<double>(0);
      final solver = SpringSolver(
        vsync: const TestVSync(),
        value: value,
        spring: NibSpringDescription.gentle,
      );
      solver.animateTo(target: 100);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(value.velocity, greaterThan(0));

      solver.stop();
      final atStop = value.value;
      final speedAtStop = value.velocity;
      expect(speedAtStop, greaterThan(0));

      // Retarget backwards: must start from the frozen position AND velocity.
      solver.animateTo(target: 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 8));
      expect(value.value, greaterThan(atStop),
          reason: 'forward momentum carries on for a moment before turning');
      solver.dispose();
    });

    testWidgets('spring starts from MotionValue.velocity set by another driver',
        (tester) async {
      final value = MotionValue<double>(50);
      value.update(50, velocity: 400);
      final solver = SpringSolver(
        vsync: const TestVSync(),
        value: value,
        spring: NibSpringDescription.gentle,
      );
      solver.animateTo(target: 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 8));
      expect(value.value, greaterThan(50));
      solver.dispose();
    });

    testWidgets('spring settles exactly on target with zero velocity',
        (tester) async {
      final value = MotionValue<double>(0);
      final solver = SpringSolver(
        vsync: const TestVSync(),
        value: value,
        spring: NibSpringDescription.snappy,
      );
      solver.animateTo(target: 42);
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      expect(value.value, 42);
      expect(value.velocity, 0);
      solver.dispose();
    });

    testWidgets('spring ignores stale velocity after the value was jumped',
        (tester) async {
      final value = MotionValue<double>(0);
      value.update(10, velocity: 999);
      value.value = 20; // jump
      final solver = SpringSolver(
        vsync: const TestVSync(),
        value: value,
        spring: NibSpringDescription.stiff,
      );
      solver.animateTo(target: 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 8));
      expect(value.value, lessThan(20));
      solver.dispose();
    });

    testWidgets('inertia publishes velocity for a following spring',
        (tester) async {
      final value = MotionValue<double>(0);
      final inertia = InertiaSolver(vsync: const TestVSync(), value: value);
      inertia.animateTo(velocity: 1000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(value.velocity, greaterThan(0));
      inertia.stop();
      expect(value.velocity, greaterThan(0));
      inertia.dispose();
    });
  });

  group('interrupted animation futures resolve', () {
    testWidgets('spring superseded by a new spring', (tester) async {
      final controller = NibMotionController();
      await tester.pumpWidget(_wrap(NibMotion(
        controller: controller,
        transition: NibTransition.springGentle,
        child: const SizedBox(width: 10, height: 10),
      )));
      var first = false;
      controller.start(target: const NibAnim(x: 100)).then((_) => first = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(first, isFalse);
      controller.start(target: const NibAnim(x: 0));
      await tester.pump();
      expect(first, isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('tween superseded by a spring', (tester) async {
      final controller = NibMotionController();
      await tester.pumpWidget(_wrap(NibMotion(
        controller: controller,
        child: const SizedBox(width: 10, height: 10),
      )));
      var first = false;
      controller
          .start(
            target: const NibAnim(x: 100),
            transition: const NibTransition(duration: Duration(seconds: 1)),
          )
          .then((_) => first = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(first, isFalse);
      controller.start(
          target: const NibAnim(x: 0), transition: NibTransition.springSnappy);
      await tester.pump();
      expect(first, isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('delayed animation superseded before its delay elapses',
        (tester) async {
      final controller = NibMotionController();
      await tester.pumpWidget(_wrap(NibMotion(
        controller: controller,
        child: const SizedBox(width: 10, height: 10),
      )));
      var first = false;
      controller
          .start(
            target: const NibAnim(x: 100),
            transition: const NibTransition(delay: Duration(seconds: 1)),
          )
          .then((_) => first = true);
      await tester.pump(const Duration(milliseconds: 100));
      controller.start(target: const NibAnim(x: 30));
      await tester.pump();
      expect(first, isTrue);
      await tester.pumpAndSettle();
      expect(_translateX(tester), closeTo(30, 0.01),
          reason: 'the stale delayed target must not fire later');
    });

    testWidgets('stop() resolves in-flight futures', (tester) async {
      final controller = NibMotionController();
      await tester.pumpWidget(_wrap(NibMotion(
        controller: controller,
        transition: NibTransition.springGentle,
        child: const SizedBox(width: 10, height: 10),
      )));
      var done = false;
      controller.start(target: const NibAnim(x: 100)).then((_) => done = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      controller.stop();
      await tester.pump();
      expect(done, isTrue);
    });
  });
}

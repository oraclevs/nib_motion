import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Future<List<double>> _run(
  WidgetTester tester,
  InertiaSolver solver,
  MotionValue<double> value, {
  int frames = 700,
}) async {
  final trace = <double>[];
  await tester.pump();
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    trace.add(value.value);
  }
  return trace;
}

void main() {
  group('InertiaSolver', () {
    testWidgets('unbounded: coasts forward and rests', (tester) async {
      final value = MotionValue<double>(0);
      final solver = InertiaSolver(vsync: const TestVSync(), value: value);
      var done = false;
      solver.animateTo(velocity: 1000).then((_) => done = true);
      final trace = await _run(tester, solver, value);
      expect(trace.last, greaterThan(100));
      expect(trace.last, closeTo(trace[trace.length - 2], 0.01));
      expect(done, isTrue);
      expect(value.velocity, 0);
      solver.dispose();
    });

    testWidgets('max bound: overshoots, springs back, rests exactly on bound',
        (tester) async {
      final value = MotionValue<double>(0);
      final solver = InertiaSolver(vsync: const TestVSync(), value: value);
      solver.animateTo(velocity: 3000, max: 100);
      final trace = await _run(tester, solver, value);
      expect(trace.reduce((a, b) => a > b ? a : b), greaterThan(100),
          reason: 'elastic overshoot past the bound');
      expect(trace.last, 100);
      expect(value.velocity, 0);
      expect(trace.every((v) => v.isFinite), isTrue);
      solver.dispose();
    });

    testWidgets('min bound mirrors max bound', (tester) async {
      final value = MotionValue<double>(0);
      final solver = InertiaSolver(vsync: const TestVSync(), value: value);
      solver.animateTo(velocity: -3000, min: -50);
      final trace = await _run(tester, solver, value);
      expect(trace.reduce((a, b) => a < b ? a : b), lessThan(-50));
      expect(trace.last, -50);
      solver.dispose();
    });

    testWidgets('velocity that never reaches the bound stops short of it',
        (tester) async {
      final value = MotionValue<double>(0);
      final solver = InertiaSolver(vsync: const TestVSync(), value: value);
      solver.animateTo(velocity: 100, max: 1000);
      final trace = await _run(tester, solver, value);
      expect(trace.last, lessThan(1000));
      expect(trace.reduce((a, b) => a > b ? a : b), lessThan(1000));
      solver.dispose();
    });

    testWidgets('starting outside the bound springs back to it',
        (tester) async {
      final value = MotionValue<double>(160);
      final solver = InertiaSolver(vsync: const TestVSync(), value: value);
      solver.animateTo(velocity: 0, max: 100);
      final trace = await _run(tester, solver, value);
      expect(trace.last, 100);
      solver.dispose();
    });

    testWidgets('a spring takes over inertia momentum', (tester) async {
      final value = MotionValue<double>(0);
      final inertia = InertiaSolver(vsync: const TestVSync(), value: value);
      final spring = SpringSolver(
          vsync: const TestVSync(),
          value: value,
          spring: NibSpringDescription.gentle);
      inertia.animateTo(velocity: 2000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      inertia.stop();
      final at = value.value;
      spring.animateTo(target: 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 8));
      expect(value.value, greaterThan(at),
          reason: 'momentum carries into the spring');
      inertia.dispose();
      spring.dispose();
    });
  });
}

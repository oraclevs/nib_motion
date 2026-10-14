import 'package:flutter/physics.dart' as fp;
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  testWidgets('runs gravity, publishes velocity, ends on the floor',
      (tester) async {
    final y = MotionValue<double>(0);
    final d = NibSimulationDriver(vsync: const TestVSync(), value: y);
    var ended = 0;
    d.onComplete = () => ended++;
    var done = false;
    d.run(fp.GravitySimulation(1000, 0, 200, 0)).then((_) => done = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(y.value, greaterThan(0));
    expect(y.velocity, greaterThan(0));
    expect(d.isRunning, isTrue);
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(y.value, closeTo(200, 30),
        reason: 'ends within one frame of travel past the floor');
    expect(y.velocity, 0);
    expect(done, isTrue);
    expect(ended, 1);
    expect(d.isRunning, isFalse);
    d.dispose();
  });

  testWidgets('a spring takes over the simulation momentum', (tester) async {
    final y = MotionValue<double>(0);
    final d = NibSimulationDriver(vsync: const TestVSync(), value: y);
    final spring = SpringSolver(
        vsync: const TestVSync(),
        value: y,
        spring: NibSpringDescription.gentle);
    d.run(fp.GravitySimulation(3000, 0, 10000, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    d.stop();
    final at = y.value;
    expect(y.velocity, greaterThan(0));
    spring.animateTo(target: 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 8));
    expect(y.value, greaterThan(at));
    d.dispose();
    spring.dispose();
  });

  testWidgets('superseding, stopping and disposing resolve futures',
      (tester) async {
    final y = MotionValue<double>(0);
    final d = NibSimulationDriver(vsync: const TestVSync(), value: y);
    var a = false, b = false, c = false;
    var ended = 0;
    d.onComplete = () => ended++;
    d.run(fp.GravitySimulation(100, 0, 1e6, 0)).then((_) => a = true);
    await tester.pump();
    d.run(fp.GravitySimulation(100, 0, 1e6, 0)).then((_) => b = true);
    await tester.pump();
    expect(a, isTrue);
    d.stop();
    await tester.pump();
    expect(b, isTrue);
    d.run(fp.GravitySimulation(100, 0, 1e6, 0)).then((_) => c = true);
    await tester.pump();
    d.dispose();
    await tester.pump();
    expect(c, isTrue);
    expect(ended, 0, reason: 'onComplete only fires on natural completion');
  });

  testWidgets('works with a friction simulation too', (tester) async {
    final x = MotionValue<double>(0);
    final d = NibSimulationDriver(vsync: const TestVSync(), value: x);
    d.run(fp.FrictionSimulation(0.135, 0, 1000));
    await tester.pump();
    for (var i = 0; i < 700; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(x.value, closeTo(fp.FrictionSimulation(0.135, 0, 1000).finalX, 1));
    d.dispose();
  });
}

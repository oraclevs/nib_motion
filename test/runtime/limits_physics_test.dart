import 'package:flutter/physics.dart' as fp;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  group('NibSimulationDriver final frame', () {
    testWidgets('lands exactly on the simulation end, not past it',
        (tester) async {
      final y = MotionValue<double>(0);
      final d = NibSimulationDriver(vsync: const TestVSync(), value: y);
      d.run(fp.GravitySimulation(1000, 0, 200, 0));
      await tester.pump();
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(y.value, closeTo(200, 0.5),
          reason: 'clamped to the crossing point, not one frame past');
      expect(y.velocity, 0);
      d.dispose();
    });

    testWidgets('a simulation that is done at t=0 writes its start',
        (tester) async {
      final y = MotionValue<double>(5);
      final d = NibSimulationDriver(vsync: const TestVSync(), value: y);
      var done = false;
      d.run(fp.GravitySimulation(1000, 500, 200, 0)).then((_) => done = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(done, isTrue);
      expect(y.value, closeTo(500, 0.5));
      d.dispose();
    });
  });

  group('NibValueBuilder', () {
    testWidgets('child passthrough: the static subtree is not rebuilt',
        (tester) async {
      var childBuilds = 0;
      var builderCalls = 0;
      // One instance, as app code would hold it (e.g. a const or a field).
      final child = Builder(builder: (_) {
        childBuilds++;
        return const SizedBox(width: 10, height: 10);
      });
      Widget host(double target) => Directionality(
            textDirection: TextDirection.ltr,
            child: NibValueBuilder<double>.withChild(
              target: target,
              child: child,
              childBuilder: (context, value, child) {
                builderCalls++;
                return Padding(
                    padding: EdgeInsets.only(left: value), child: child);
              },
            ),
          );
      await tester.pumpWidget(host(0));
      await tester.pumpWidget(host(100));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(builderCalls, greaterThan(5));
      expect(childBuilds, 1, reason: 'child built once, passed through');
      await tester.pumpAndSettle();
    });

    testWidgets('tween transition animates linearly over its duration',
        (tester) async {
      final seen = <double>[];
      Widget host(double target) => Directionality(
            textDirection: TextDirection.ltr,
            child: NibValueBuilder<double>(
              target: target,
              transition: const NibTransition(
                  duration: Duration(milliseconds: 1000), curve: Curves.linear),
              builder: (context, v) {
                seen.add(v);
                return const SizedBox();
              },
            ),
          );
      await tester.pumpWidget(host(0));
      await tester.pumpWidget(host(100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(seen.last, closeTo(50, 2));
      await tester.pump(const Duration(milliseconds: 600));
      expect(seen.last, 100);
      // Linear tween, no overshoot ever.
      expect(seen.every((v) => v <= 100 + 1e-9), isTrue);
    });

    testWidgets('tween works for Color and retargets from the current value',
        (tester) async {
      Color? last;
      Widget host(Color target) => Directionality(
            textDirection: TextDirection.ltr,
            child: NibValueBuilder<Color>(
              target: target,
              transition: const NibTransition(
                  duration: Duration(milliseconds: 1000), curve: Curves.linear),
              builder: (context, v) {
                last = v;
                return const SizedBox();
              },
            ),
          );
      await tester.pumpWidget(host(const Color(0xFF000000)));
      await tester.pumpWidget(host(const Color(0xFFFFFFFF)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final mid = last!;
      expect((mid.r * 255).round(), inInclusiveRange(120, 135));
      await tester.pumpWidget(host(const Color(0xFF000000)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect((last!.r * 255).round(), closeTo((mid.r * 255).round(), 4),
          reason: 'retarget starts from the painted colour, no jump');
      await tester.pumpAndSettle();
    });

    testWidgets('a spring transition still works through `transition:`',
        (tester) async {
      double? last;
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: NibValueBuilder<double>(
          target: 0,
          transition: NibTransition.springSnappy,
          builder: (context, v) {
            last = v;
            return const SizedBox();
          },
        ),
      ));
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: NibValueBuilder<double>(
          target: 50,
          transition: NibTransition.springSnappy,
          builder: (context, v) {
            last = v;
            return const SizedBox();
          },
        ),
      ));
      await tester.pumpAndSettle();
      expect(last, 50);
    });
  });

  group('NibSpringTuner plot geometry', () {
    test('starts at 0, ends on the 1.0 line, peak matches the curve', () {
      final curve = NibSpringCurve(NibSpringDescription.wobbly);
      const size = Size(200, 100);
      final plot = nibSpringPlotPoints(curve, size);
      expect(plot.points.first.dx, 0);
      expect(plot.points.last.dx, size.width);
      // y of value 1.0 equals the last point (curve ends exactly on 1).
      expect(plot.points.last.dy, closeTo(plot.targetY, 1e-6));
      // First point is the value 0 baseline (bottom of the plot).
      expect(plot.points.first.dy, closeTo(size.height, 1e-6));
      // Overshoot: some point is above the target line (smaller y).
      final peak = plot.points.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
      expect(peak, lessThan(plot.targetY));
      final maxValue = [for (var i = 0; i <= 120; i++) curve.transform(i / 120)]
          .reduce((a, b) => a > b ? a : b);
      expect(plot.peakValue, closeTo(maxValue, 1e-9));
    });

    test('a critically damped spring never rises above the target line', () {
      final curve = NibSpringCurve(NibSpringDescription.fromDuration(
          duration: const Duration(milliseconds: 400), bounce: 0));
      final plot = nibSpringPlotPoints(curve, const Size(100, 100));
      for (final p in plot.points) {
        expect(p.dy, greaterThanOrEqualTo(plot.targetY - 1e-6));
      }
    });
  });
}

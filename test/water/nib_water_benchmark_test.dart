import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/src/water/nib_water_controller.dart';

// Reproducible CPU processing workload, not a frame-rate or memory benchmark.
// Run without other Flutter builds for a less noisy host measurement:
// flutter test --no-pub --reporter expanded test/water/nib_water_benchmark_test.dart
void main() {
  test('water controller CPU batches: 1, 2, 5 and 10 constituents', () {
    final rows = <Map<String, Object>>[];
    for (final count in [1, 2, 5, 10]) {
      final value = NibWaterController(
        drops: List.generate(
            count,
            (i) => NibWaterDrop(
                  id: i,
                  center: Offset(100 + i * 150.0, 100),
                  radius: 32,
                )),
      );
      final mass = value.massProxy;
      final elapsed = <int>[];
      final solver = <int>[];
      final idle = <int>[];
      var observedNotifications = 0;
      value.addListener(() => observedNotifications++);
      for (var batch = -5; batch < 20; batch++) {
        value.reset();
        final watch = Stopwatch()..start();
        var solverMicros = 0;
        value.beginDrag(1, value.drops.first.center);
        value.dragTo(1, value.drops.first.center + const Offset(40, 40));
        for (var frame = 0; frame < 120; frame++) {
          if (frame == 40) {
            value.endDrag(1);
            value.merge();
          }
          if (frame == 80) value.split();
          if (frame % 10 == 0) value.disturb(const Offset(200, 100));
          value.advance(1 / 60);
          solverMicros += value.lastStepMicros;
        }
        watch.stop();
        expect(value.massProxy, mass);
        expect(value.impulses.length, lessThanOrEqualTo(12));
        if (batch >= 0) {
          elapsed.add(watch.elapsedMicroseconds);
          solver.add(solverMicros);
        }
      }
      value.reset();
      final beforeIdle = observedNotifications;
      final timeBeforeIdle = value.simulationTime;
      for (var batch = 0; batch < 20; batch++) {
        final watch = Stopwatch()..start();
        for (var frame = 0; frame < 120; frame++) {
          value.advance(1 / 60);
        }
        watch.stop();
        idle.add(watch.elapsedMicroseconds);
      }
      expect(observedNotifications, beforeIdle);
      expect(value.simulationTime, timeBeforeIdle);
      value.dispose();
      expect(value.drops, isEmpty);
      expect(value.impulses, isEmpty);
      rows.add({
        'constituents': count,
        'active_batch_wall_us': elapsed,
        'active_batch_solver_us': solver,
        'idle_batch_wall_us': idle,
        'active_batch_mean_us':
            elapsed.reduce((a, b) => a + b) / elapsed.length,
        'active_batch_max_us': elapsed.reduce(math.max),
        'idle_notifications': observedNotifications - beforeIdle,
      });
    }
    // 200 independently owned sessions must explicitly clear every exposed
    // retained collection. This is lifecycle evidence, not a heap measurement.
    for (var i = 0; i < 200; i++) {
      final session = NibWaterController(drops: const [
        NibWaterDrop(id: 0, center: Offset(100, 100)),
      ]);
      session.beginDrag(0, const Offset(100, 100));
      session.dragTo(0, const Offset(150, 150));
      session.disturb(const Offset(100, 100));
      session.advance(1 / 60);
      session.dispose();
      expect(session.activeInputs, 0);
      expect(session.drops, isEmpty);
      expect(session.impulses, isEmpty);
    }
    // Machine-readable raw batches retained in the command's durable log.
    // ignore: avoid_print
    print('WATER_CPU_BENCHMARK ${jsonEncode({
          'dart': Platform.version,
          'os': Platform.operatingSystem,
          'processors': Platform.numberOfProcessors,
          'mode': 'flutter_test debug VM, controller CPU only',
          'scope':
              'No background capture, shader, layout, raster, display or heap measurement',
          'warmup_batches': 5,
          'measured_batches': 20,
          'frames_per_batch': 120,
          'simulation_frame_seconds': 1 / 60,
          'workload':
              'reset outside timing, drag first constituent, merge at40, split at80, disturb every10 frames; notifications included in batch wall time',
          'cleanup_sessions': 200,
          'rows': rows,
        })}');
  });
}

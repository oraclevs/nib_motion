// Run: flutter test benchmark/motion_benchmarks.dart
//
// These measure CPU cost of the reactive/physics runtime in the Dart VM
// (no raster). They are for *relative* before/after comparisons on one
// machine, not absolute frame-time claims: raster cost needs a device lane
// (see doc/performance.md).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void _report(String name, Stopwatch sw, int ops, [String extra = '']) {
  final perOp = sw.elapsedMicroseconds / ops;
  // ignore: avoid_print
  print('BENCH $name: ${sw.elapsedMilliseconds} ms total, '
      '${perOp.toStringAsFixed(3)} us/op $extra');
}

void main() {
  test('reactive: plain MotionValue set with one listener', () {
    final v = MotionValue<double>(0);
    var sink = 0.0;
    v.addListener(() => sink += v.value);
    const n = 2000000;
    final sw = Stopwatch()..start();
    for (var i = 1; i <= n; i++) {
      v.value = i.toDouble();
    }
    sw.stop();
    _report('set+notify (1 listener)', sw, n, 'sink=$sink');
  });

  test('reactive: driver-style update with velocity', () {
    final v = MotionValue<double>(0);
    var sink = 0.0;
    v.addListener(() => sink += v.value);
    const n = 2000000;
    final sw = Stopwatch()..start();
    for (var i = 1; i <= n; i++) {
      v.update(i.toDouble(), velocity: 1.0);
    }
    sw.stop();
    _report('update(velocity)+notify', sw, n, 'sink=$sink');
  });

  test('reactive: 1000 sources x mapRange derived fan-out', () {
    final sources = [for (var i = 0; i < 1000; i++) MotionValue<double>(0)];
    final derived = [
      for (final s in sources) s.mapRange([0, 100], [0, 1]),
    ];
    var sink = 0.0;
    for (final d in derived) {
      d.addListener(() => sink += d.value);
    }
    const frames = 200;
    final sw = Stopwatch()..start();
    for (var f = 1; f <= frames; f++) {
      for (final s in sources) {
        s.update(f.toDouble(), velocity: 60);
      }
    }
    sw.stop();
    _report('1000 mapRange fan-out per frame', sw, frames,
        '(per-frame; sink=$sink)');
  });

  test('reactive: computed value over 8 dependencies, read at paint', () {
    final deps = [for (var i = 0; i < 8; i++) MotionValue<double>(0)];
    final c = MotionValue.computed(
        deps, () => deps.fold<double>(0, (a, d) => a + d.value));
    var sink = 0.0;
    c.addListener(() {});
    const frames = 100000;
    final sw = Stopwatch()..start();
    for (var f = 1; f <= frames; f++) {
      for (final d in deps) {
        d.value = f.toDouble();
      }
      sink += c.value; // one read per "frame"
    }
    sw.stop();
    _report('computed(8 deps): 8 writes + 1 read', sw, frames, 'sink=$sink');
  });

  testWidgets('physics: 500 concurrent springs stepping 60 frames',
      (tester) async {
    final values = [for (var i = 0; i < 500; i++) MotionValue<double>(0)];
    final solvers = [
      for (final v in values)
        SpringSolver(
            vsync: const TestVSync(),
            value: v,
            spring: NibSpringDescription.wobbly),
    ];
    var notifications = 0;
    for (final v in values) {
      v.addListener(() => notifications++);
    }
    for (final s in solvers) {
      s.animateTo(target: 300);
    }
    await tester.pump();
    final sw = Stopwatch()..start();
    for (var f = 0; f < 60; f++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    sw.stop();
    _report('500 springs, 60 frames', sw, 60,
        '(per-frame incl. test harness; notifications=$notifications)');
    for (final s in solvers) {
      s.dispose();
    }
  });

  testWidgets('widgets: 200 NibMotion springing, rebuild count',
      (tester) async {
    var builds = 0;
    final controllers = [for (var i = 0; i < 200; i++) NibMotionController()];
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Wrap(children: [
        for (final c in controllers)
          NibMotion(
            controller: c,
            child: Builder(builder: (_) {
              builds++;
              return const SizedBox(width: 10, height: 10);
            }),
          ),
      ]),
    ));
    final mounted = builds;
    for (final c in controllers) {
      c.start(target: const NibAnim(x: 40, scale: 1.4));
    }
    final sw = Stopwatch()..start();
    for (var f = 0; f < 60; f++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    sw.stop();
    _report('200 NibMotion, 60 frames', sw, 60,
        '(per-frame incl. harness; rebuilds during animation=${builds - mounted})');
    expect(builds - mounted, 0);
  });

  testWidgets('presence: 100 items x 40 rapid toggles', (tester) async {
    Widget item(int i) => NibMotion(
          key: ValueKey(i),
          initial: const NibAnim(opacity: 0),
          animate: const NibAnim(opacity: 1),
          exit: const NibAnim(opacity: 0),
          child: const SizedBox(width: 10, height: 10),
        );
    Widget host(bool on) => Directionality(
          textDirection: TextDirection.ltr,
          child: NibPresence(
              children: [for (var i = 0; i < (on ? 100 : 20); i++) item(i)]),
        );
    await tester.pumpWidget(host(true));
    final sw = Stopwatch()..start();
    for (var i = 0; i < 40; i++) {
      await tester.pumpWidget(host(i.isOdd));
      await tester.pump(const Duration(milliseconds: 16));
    }
    sw.stop();
    _report('presence churn (pumpWidget+frame)', sw, 40);
    await tester.pumpAndSettle();
  });
}

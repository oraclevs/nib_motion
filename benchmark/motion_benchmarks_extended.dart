// Run: flutter test benchmark/motion_benchmarks_extended.dart
//
// Companion to motion_benchmarks.dart. Every benchmark is run 3 times and the
// MEDIAN is reported (`BENCH2 name: median X us/unit [runs: a b c]`).
// CPU only, in a debug-mode `flutter test` (fake clock, no raster): use for
// relative comparisons on one machine, not as absolute frame times.
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

double _median(List<double> v) {
  final s = List<double>.of(v)..sort();
  return s[s.length ~/ 2];
}

Future<double> _median3(Future<double> Function() run) async {
  final runs = <double>[];
  for (var i = 0; i < 3; i++) {
    runs.add(await run());
  }
  return _median(runs);
}

void _report(String name, List<double> runs, String unit, [String extra = '']) {
  // ignore: avoid_print
  print('BENCH2 $name: median ${_median(runs).toStringAsFixed(2)} $unit '
      '[runs: ${runs.map((r) => r.toStringAsFixed(2)).join(' ')}] $extra');
}

Future<List<double>> _three(Future<double> Function() run) async {
  final runs = <double>[];
  for (var i = 0; i < 3; i++) {
    runs.add(await run());
  }
  return runs;
}

int _layerCount(Layer root) {
  var n = 1;
  if (root is ContainerLayer) {
    Layer? c = root.firstChild;
    while (c != null) {
      n += _layerCount(c);
      c = c.nextSibling;
    }
  }
  return n;
}

int _countLayers<T extends Layer>(Layer root) {
  var n = root is T ? 1 : 0;
  if (root is ContainerLayer) {
    Layer? c = root.firstChild;
    while (c != null) {
      n += _countLayers<T>(c);
      c = c.nextSibling;
    }
  }
  return n;
}

Future<double> _pumpFrames(WidgetTester tester, int frames) async {
  final sw = Stopwatch()..start();
  for (var f = 0; f < frames; f++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  sw.stop();
  return sw.elapsedMicroseconds / frames;
}

// --- (1) AnimationController baseline -------------------------------------

class _CtlItem extends StatefulWidget {
  const _CtlItem({required this.onBuild});
  final VoidCallback onBuild;
  @override
  State<_CtlItem> createState() => _CtlItemState();
}

class _CtlItemState extends State<_CtlItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800))
    ..forward();
  late final Animation<double> _x =
      Tween<double>(begin: 0, end: 40).animate(_c);
  late final Animation<double> _o =
      Tween<double>(begin: 0.2, end: 1).animate(_c);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Idiomatic baseline: transform+opacity driven by AnimatedBuilder; the
    // static child is passed through so it is not rebuilt.
    return AnimatedBuilder(
      animation: _c,
      child: Builder(builder: (_) {
        widget.onBuild();
        return const SizedBox(width: 10, height: 10);
      }),
      builder: (context, child) => Opacity(
        opacity: _o.value,
        child: Transform.translate(offset: Offset(_x.value, 0), child: child),
      ),
    );
  }
}

void main() {
  const n = 300;

  testWidgets('1. AnimationController+AnimatedBuilder vs NibMotion spring',
      (tester) async {
    Future<double> ctl() async {
      var builds = 0;
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Wrap(children: [
          for (var i = 0; i < n; i++) _CtlItem(onBuild: () => builds++),
        ]),
      ));
      final mounted = builds;
      final t = await _pumpFrames(tester, 50);
      final ticking = tester.binding.transientCallbackCount;
      // ignore: avoid_print
      print('   ctl: child rebuilds=${builds - mounted} '
          'transientCallbacks(active tickers)=$ticking');
      await tester.pumpWidget(const SizedBox());
      return t / n;
    }

    Future<double> nib() async {
      var builds = 0;
      final controllers = [for (var i = 0; i < n; i++) NibMotionController()];
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Wrap(children: [
          for (final c in controllers)
            NibMotion(
              controller: c,
              initial: const NibAnim(opacity: 0.2),
              child: Builder(builder: (_) {
                builds++;
                return const SizedBox(width: 10, height: 10);
              }),
            ),
        ]),
      ));
      final mounted = builds;
      for (final c in controllers) {
        c.start(
            target: const NibAnim(x: 40, opacity: 1),
            transition: NibTransition.springSnappy);
      }
      final t = await _pumpFrames(tester, 50);
      // ignore: avoid_print
      print('   nib: child rebuilds=${builds - mounted} '
          'transientCallbacks(active tickers)=${tester.binding.transientCallbackCount}');
      await tester.pumpWidget(const SizedBox());
      return t / n;
    }

    _report('AnimationController x300 (us/frame/widget)', await _three(ctl),
        'us/frame/widget');
    _report('NibMotion spring x300 (us/frame/widget)', await _three(nib),
        'us/frame/widget');
  });

  // --- (2) blur / tint ------------------------------------------------------
  testWidgets('2. blur/tint cost, 100 animating NibMotion', (tester) async {
    Future<double> run(NibAnim target, {bool count = false}) async {
      final controllers = [for (var i = 0; i < 100; i++) NibMotionController()];
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Wrap(children: [
          for (final c in controllers)
            NibMotion(
                controller: c, child: const SizedBox(width: 20, height: 20)),
        ]),
      ));
      for (final c in controllers) {
        c.start(
            target: target,
            transition: const NibTransition(
                duration: Duration(seconds: 2), curve: Curves.linear));
      }
      await tester.pump();
      final t = await _pumpFrames(tester, 50);
      if (count) {
        final root = RendererBinding.instance.renderViews.first.debugLayer!;
        // ignore: avoid_print
        print('   layers total=${_layerCount(root)} '
            'imageFilter=${_countLayers<ImageFilterLayer>(root)} '
            'colorFilter=${_countLayers<ColorFilterLayer>(root)}');
      }
      await tester.pumpWidget(const SizedBox());
      return t / 100;
    }

    _report(
        'animate x only (baseline)',
        await _three(() => run(const NibAnim(x: 30), count: true)),
        'us/frame/widget');
    _report(
        'animate x + blur 8',
        await _three(() => run(const NibAnim(x: 30, blur: 8), count: true)),
        'us/frame/widget');
    _report(
        'animate x + tint',
        await _three(() =>
            run(const NibAnim(x: 30, tint: Color(0x80FF0000)), count: true)),
        'us/frame/widget');
  });

  // --- (3) layout FLIP ------------------------------------------------------
  testWidgets('3. layout FLIP reorder of 200 items', (tester) async {
    final order = List<int>.generate(200, (i) => i);
    var builds = 0;
    Widget item(int i, NibLayout layout) => NibMotion(
          key: ValueKey(i),
          layout: layout,
          layoutTransition: NibTransition.springGentle,
          child: Builder(builder: (_) {
            builds++;
            return SizedBox(width: 20 + (i % 3) * 5.0, height: 20);
          }),
        );

    Future<double> wrapRun(NibLayout layout) async {
      final rnd = math.Random(7);
      final ids = List<int>.of(order);
      builds = 0;
      Widget host() => Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
                width: 400,
                child: Wrap(children: [for (final i in ids) item(i, layout)])),
          );
      await tester.pumpWidget(host());
      final sw = Stopwatch()..start();
      const rounds = 10;
      for (var r = 0; r < rounds; r++) {
        ids.shuffle(rnd);
        await tester.pumpWidget(host());
        for (var f = 0; f < 5; f++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      }
      sw.stop();
      final per = sw.elapsedMicroseconds / (rounds * 6);
      // ignore: avoid_print
      print('   $layout: child builds over $rounds reorders = $builds '
          '(200 items; rebuilds come from the reorder itself, not animation)');
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      return per;
    }

    _report('Wrap 200, layout: none (reorder+5 frames, us/frame)',
        await _three(() => wrapRun(NibLayout.none)), 'us/frame');
    _report('Wrap 200, layout: position',
        await _three(() => wrapRun(NibLayout.position)), 'us/frame');
    _report('Wrap 200, layout: both',
        await _three(() => wrapRun(NibLayout.both)), 'us/frame');

    Future<double> groupRun() async {
      final rnd = math.Random(7);
      final ids = List<int>.of(order.take(200));
      Widget host() => Directionality(
            textDirection: TextDirection.ltr,
            child: SingleChildScrollView(
              child: NibLayoutGroup(children: [
                for (final i in ids)
                  SizedBox(key: ValueKey(i), width: 20, height: 20),
              ]),
            ),
          );
      await tester.pumpWidget(host());
      final sw = Stopwatch()..start();
      const rounds = 10;
      for (var r = 0; r < rounds; r++) {
        ids.shuffle(rnd);
        await tester.pumpWidget(host());
        for (var f = 0; f < 5; f++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      }
      sw.stop();
      final per = sw.elapsedMicroseconds / (rounds * 6);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      return per;
    }

    _report('NibLayoutGroup Column 200 (reorder+5 frames, us/frame)',
        await _three(groupRun), 'us/frame');
  });

  // --- (4) presence churn ---------------------------------------------------
  testWidgets('4. presence churn attribution', (tester) async {
    Widget item(int i) => NibMotion(
          key: ValueKey(i),
          initial: const NibAnim(opacity: 0),
          animate: const NibAnim(opacity: 1),
          exit: const NibAnim(opacity: 0),
          child: const SizedBox(width: 10, height: 10),
        );
    Widget plainItem(int i) => NibMotion(
          key: ValueKey(i),
          child: const SizedBox(width: 10, height: 10),
        );

    Future<double> churn(Widget Function(bool on) host) async {
      await tester.pumpWidget(host(true));
      final sw = Stopwatch()..start();
      for (var i = 0; i < 40; i++) {
        await tester.pumpWidget(host(i.isOdd));
      }
      sw.stop();
      final per = sw.elapsedMicroseconds / 40;
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      return per;
    }

    Widget presence(bool on) => Directionality(
        textDirection: TextDirection.ltr,
        child: NibPresence(
            children: [for (var i = 0; i < (on ? 100 : 20); i++) item(i)]));
    Widget stackNoPresence(bool on) => Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(children: [
          for (var i = 0; i < (on ? 100 : 20); i++) item(i),
        ]));
    Widget stackPlain(bool on) => Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(children: [
          for (var i = 0; i < (on ? 100 : 20); i++) plainItem(i),
        ]));
    Widget presencePlain(bool on) => Directionality(
        textDirection: TextDirection.ltr,
        child: NibPresence(children: [
          for (var i = 0; i < (on ? 100 : 20); i++) plainItem(i),
        ]));

    _report('NibPresence + enter/exit anims (pumpWidget only, no frames)',
        await _three(() => churn(presence)), 'us/toggle');
    _report('Stack of same NibMotions (no presence; mount/unmount)',
        await _three(() => churn(stackNoPresence)), 'us/toggle');
    _report('Stack of plain NibMotions (no enter/exit props)',
        await _three(() => churn(stackPlain)), 'us/toggle');
    _report('NibPresence of plain NibMotions (orchestration only)',
        await _three(() => churn(presencePlain)), 'us/toggle');
  });

  testWidgets(
      '4b. presence wrapper cost (Ignore+ExcludeSemantics+ExcludeFocus)',
      (tester) async {
    Widget item(int i) => NibMotion(
          key: ValueKey(i),
          child: const SizedBox(width: 10, height: 10),
        );
    Widget wrapped(int i) => IgnorePointer(
        key: ValueKey('w$i'),
        ignoring: false,
        child: ExcludeSemantics(
            excluding: false,
            child: ExcludeFocus(excluding: false, child: item(i))));
    Future<double> churn(Widget Function(int) build) async {
      Widget host(bool on) => Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(children: [
            for (var i = 0; i < (on ? 100 : 20); i++) build(i),
          ]));
      await tester.pumpWidget(host(true));
      final sw = Stopwatch()..start();
      for (var i = 0; i < 40; i++) {
        await tester.pumpWidget(host(i.isOdd));
      }
      sw.stop();
      await tester.pumpWidget(const SizedBox());
      return sw.elapsedMicroseconds / 40;
    }

    _report('Stack plain NibMotion (no wrappers)',
        await _three(() => churn(item)), 'us/toggle');
    _report('Stack plain NibMotion + 3 presence wrappers',
        await _three(() => churn(wrapped)), 'us/toggle');
  });

  // --- (5) fan-out at sizes ---------------------------------------------------
  test('5. mapRange / computed fan-out by node count', () {
    for (final size in [1, 10, 100, 500, 1000]) {
      double mapRangeRun() {
        final sources = [for (var i = 0; i < size; i++) MotionValue<double>(0)];
        final derived = [
          for (final s in sources) s.mapRange([0, 100], [0, 1]),
        ];
        var sink = 0.0;
        for (final d in derived) {
          d.addListener(() => sink += d.value);
        }
        final frames = math.max(20, 20000 ~/ size);
        final sw = Stopwatch()..start();
        for (var f = 1; f <= frames; f++) {
          for (final s in sources) {
            s.update(f.toDouble(), velocity: 60);
          }
        }
        sw.stop();
        if (sink.isNaN) throw StateError('x');
        return sw.elapsedMicroseconds / frames;
      }

      double computedRun() {
        final sources = [for (var i = 0; i < size; i++) MotionValue<double>(0)];
        final c = MotionValue.computed(
            sources, () => sources.fold<double>(0, (a, s) => a + s.value));
        c.addListener(() {});
        var sink = 0.0;
        final frames = math.max(20, 20000 ~/ size);
        final sw = Stopwatch()..start();
        for (var f = 1; f <= frames; f++) {
          for (final s in sources) {
            s.value = f.toDouble();
          }
          sink += c.value;
        }
        sw.stop();
        if (sink.isNaN) throw StateError('x');
        return sw.elapsedMicroseconds / frames;
      }

      _report(
          'mapRange fan-out, $size nodes',
          [
            mapRangeRun(),
            mapRangeRun(),
            mapRangeRun(),
          ],
          'us/frame');
      _report(
          'computed over $size deps (writes + 1 read)',
          [
            computedRun(),
            computedRun(),
            computedRun(),
          ],
          'us/frame');
    }
  });

  // --- (6) MultiSpringSolver vs N SpringSolver --------------------------------
  testWidgets('6. MultiSpringSolver(Offset) vs 2 SpringSolvers',
      (tester) async {
    const count = 300;
    Future<double> multi() async {
      final values = [
        for (var i = 0; i < count; i++) MotionValue<Offset>(Offset.zero)
      ];
      final solvers = [
        for (final v in values)
          MultiSpringSolver<Offset>(
              vsync: const TestVSync(),
              value: v,
              converter: MotionConverter.offset,
              spring: NibSpringDescription.wobbly),
      ];
      var notes = 0;
      for (final v in values) {
        v.addListener(() => notes++);
      }
      for (final s in solvers) {
        s.animateTo(const Offset(200, 100));
      }
      await tester.pump();
      final t = await _pumpFrames(tester, 50);
      // ignore: avoid_print
      print('   multi: notifications=$notes');
      for (final s in solvers) {
        s.dispose();
      }
      return t / count;
    }

    Future<double> separate() async {
      final xs = [for (var i = 0; i < count; i++) MotionValue<double>(0)];
      final ys = [for (var i = 0; i < count; i++) MotionValue<double>(0)];
      final solvers = <SpringSolver>[
        for (var i = 0; i < count; i++) ...[
          SpringSolver(
              vsync: const TestVSync(),
              value: xs[i],
              spring: NibSpringDescription.wobbly),
          SpringSolver(
              vsync: const TestVSync(),
              value: ys[i],
              spring: NibSpringDescription.wobbly),
        ],
      ];
      var notes = 0;
      for (final v in [...xs, ...ys]) {
        v.addListener(() => notes++);
      }
      for (var i = 0; i < count; i++) {
        solvers[2 * i].animateTo(target: 200);
        solvers[2 * i + 1].animateTo(target: 100);
      }
      await tester.pump();
      final t = await _pumpFrames(tester, 50);
      // ignore: avoid_print
      print('   separate: notifications=$notes');
      for (final s in solvers) {
        s.dispose();
      }
      return t / count;
    }

    _report('MultiSpringSolver<Offset> x300', await _three(multi),
        'us/frame/solver');
    _report(
        '2x SpringSolver x300 pairs', await _three(separate), 'us/frame/pair');
  });

  // keep helper referenced (median helper for ad-hoc use)
  test('helper sanity', () async {
    expect(await _median3(() async => 1.0), 1.0);
  });
}

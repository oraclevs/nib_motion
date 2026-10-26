// Real-frame performance harness for nib_motion.
//
// Run (profile mode, real GPU):
//   flutter run --profile -d linux -t perf/perf_main.dart
// or build once and run the bundle:
//   flutter build linux --profile -t perf/perf_main.dart
//   ./build/linux/x64/profile/bundle/nib_motion_example
//
// Each scenario runs for [_scenarioSeconds] after a short warm-up, collects
// FrameTiming from the engine (build / raster / total), prints one JSON line
// per scenario prefixed with `PERF_RESULT`, and the app exits at the end.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:math' show Random;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:nib_motion/nib_motion.dart';

const int _scenarioSeconds = 6;
const Duration _warmup = Duration(milliseconds: 1500);

class _Scenario {
  const _Scenario(this.name, this.build);
  final String name;
  final Widget Function() build;
}

final List<_Scenario> _scenarios = <_Scenario>[
  _Scenario('01_nibmotion_300_springs_x_opacity', () => const _Springs(300)),
  _Scenario('02_animationcontroller_300_baseline', () => const _Baseline(300)),
  _Scenario('03_nibmotion_100_x_only', () => const _Effects(100, _Effect.none)),
  _Scenario('04_nibmotion_100_blur', () => const _Effects(100, _Effect.blur)),
  _Scenario('05_nibmotion_100_tint', () => const _Effects(100, _Effect.tint)),
  _Scenario(
      '06_nibmotion_100_rotateY', () => const _Effects(100, _Effect.rotateY)),
  _Scenario('07_wrap_200_flip_off', () => const _WrapFlip(200, false)),
  _Scenario('08_wrap_200_flip_position', () => const _WrapFlip(200, true)),
  _Scenario('09_presence_100_churn', () => const _PresenceChurn()),
  _Scenario('10_fanout_500_mapRange', () => const _FanOut(500)),
  _Scenario('11_shimmer_fullscreen', () => const _Shimmer()),
  _Scenario('12_glass_over_gradient', () => const _Glass()),
];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: _Runner()),
  ));
}

class _Runner extends StatefulWidget {
  const _Runner();
  @override
  State<_Runner> createState() => _RunnerState();
}

class _RunnerState extends State<_Runner> {
  int _index = -1;
  final List<FrameTiming> _timings = <FrameTiming>[];
  bool _recording = false;
  void _callback(List<FrameTiming> list) {
    if (_recording) _timings.addAll(list);
  }

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_callback);
    WidgetsBinding.instance.addPostFrameCallback((_) => _next());
  }

  Future<void> _next() async {
    if (_index >= 0) {
      _recording = false;
      _report(_scenarios[_index].name);
    }
    _timings.clear();
    if (_index + 1 >= _scenarios.length) {
      stdout.writeln('PERF_DONE');
      await stdout.flush();
      exit(0);
    }
    setState(() => _index++);
    await Future<void>.delayed(_warmup);
    _timings.clear();
    _recording = true;
    Timer(const Duration(seconds: _scenarioSeconds), _next);
  }

  double _pct(List<double> sorted, double p) {
    if (sorted.isEmpty) return 0;
    final i = ((sorted.length - 1) * p).round();
    return sorted[i];
  }

  void _report(String name) {
    double ms(Duration d) => d.inMicroseconds / 1000.0;
    final build = _timings.map((t) => ms(t.buildDuration)).toList()..sort();
    final raster = _timings.map((t) => ms(t.rasterDuration)).toList()..sort();
    final total = _timings.map((t) => ms(t.totalSpan)).toList()..sort();
    final dropped = total.where((v) => v > 16.7).length;
    final result = <String, Object>{
      'scenario': name,
      'frames': _timings.length,
      'build_ms': {
        'p50': _pct(build, .5),
        'p90': _pct(build, .9),
        'p99': _pct(build, .99)
      },
      'raster_ms': {
        'p50': _pct(raster, .5),
        'p90': _pct(raster, .9),
        'p99': _pct(raster, .99)
      },
      'total_ms': {
        'p50': _pct(total, .5),
        'p90': _pct(total, .9),
        'p99': _pct(total, .99)
      },
      'dropped_over_16_7ms': dropped,
    };
    stdout.writeln('PERF_RESULT ${jsonEncode(result)}');
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_callback);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_index < 0) return const SizedBox.shrink();
    return KeyedSubtree(
      key: ValueKey(_index),
      child: _scenarios[_index].build(),
    );
  }
}

// ---------------------------------------------------------------------------

class _Grid extends StatelessWidget {
  const _Grid({required this.count, required this.item});
  final int count;
  final Widget Function(int) item;
  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [for (var i = 0; i < count; i++) item(i)],
      );
}

const Widget _box = SizedBox(
  width: 40,
  height: 40,
  child: DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [Color(0xFF02569B), Color(0xFF54C5F8)]),
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
  ),
);

/// Re-targets every controller every 700 ms so springs are always in flight.
class _Springs extends StatefulWidget {
  const _Springs(this.count);
  final int count;
  @override
  State<_Springs> createState() => _SpringsState();
}

class _SpringsState extends State<_Springs> {
  late final List<NibMotionController> _c = [
    for (var i = 0; i < widget.count; i++) NibMotionController()
  ];
  Timer? _t;
  bool _flip = false;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 700), (_) {
      _flip = !_flip;
      for (final c in _c) {
        c.start(
          target: NibAnim(x: _flip ? 40 : 0, opacity: _flip ? 0.4 : 1),
          transition: NibTransition.springWobbly,
        );
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    for (final c in _c) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Grid(
        count: widget.count,
        item: (i) => NibMotion(controller: _c[i], child: _box),
      );
}

/// The same workload with raw AnimationController + Transform + Opacity.
class _Baseline extends StatefulWidget {
  const _Baseline(this.count);
  final int count;
  @override
  State<_Baseline> createState() => _BaselineState();
}

class _BaselineState extends State<_Baseline> with TickerProviderStateMixin {
  late final List<AnimationController> _c = [
    for (var i = 0; i < widget.count; i++)
      AnimationController(
          vsync: this, duration: const Duration(milliseconds: 600))
  ];
  Timer? _t;
  bool _flip = false;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 700), (_) {
      _flip = !_flip;
      for (final c in _c) {
        _flip ? c.forward() : c.reverse();
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    for (final c in _c) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Grid(
        count: widget.count,
        item: (i) => AnimatedBuilder(
          animation: _c[i],
          child: _box,
          builder: (context, child) => Opacity(
            opacity: 1 - 0.6 * Curves.easeInOut.transform(_c[i].value),
            child: Transform.translate(
              offset: Offset(40 * Curves.easeInOut.transform(_c[i].value), 0),
              child: child,
            ),
          ),
        ),
      );
}

enum _Effect { none, blur, tint, rotateY }

class _Effects extends StatefulWidget {
  const _Effects(this.count, this.effect);
  final int count;
  final _Effect effect;
  @override
  State<_Effects> createState() => _EffectsState();
}

class _EffectsState extends State<_Effects> {
  late final List<NibMotionController> _c = [
    for (var i = 0; i < widget.count; i++) NibMotionController()
  ];
  Timer? _t;
  bool _flip = false;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 700), (_) {
      _flip = !_flip;
      final target = switch (widget.effect) {
        _Effect.none => NibAnim(x: _flip ? 40 : 0),
        _Effect.blur => NibAnim(x: _flip ? 40 : 0, blur: _flip ? 8 : 0),
        _Effect.tint => NibAnim(
            x: _flip ? 40 : 0,
            tint: _flip ? const Color(0x8800AAFF) : const Color(0x0000AAFF)),
        _Effect.rotateY => NibAnim(x: _flip ? 40 : 0, rotateY: _flip ? 0.2 : 0),
      };
      for (final c in _c) {
        c.start(target: target, transition: NibTransition.springGentle);
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    for (final c in _c) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Grid(
        count: widget.count,
        item: (i) => NibMotion(controller: _c[i], child: _box),
      );
}

class _WrapFlip extends StatefulWidget {
  const _WrapFlip(this.count, this.flip);
  final int count;
  final bool flip;
  @override
  State<_WrapFlip> createState() => _WrapFlipState();
}

class _WrapFlipState extends State<_WrapFlip> {
  late List<int> _order = List<int>.generate(widget.count, (i) => i);
  Timer? _t;
  int _round = 0;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      _round++;
      setState(() {
        _order = List<int>.of(_order)..shuffle(Random(_round));
      });
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => NibLayoutScope(
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final i in _order)
              NibMotion(
                key: ValueKey(i),
                layout: widget.flip ? NibLayout.position : NibLayout.none,
                layoutTransition: NibTransition.springGentle,
                child: _box,
              ),
          ],
        ),
      );
}

class _PresenceChurn extends StatefulWidget {
  const _PresenceChurn();
  @override
  State<_PresenceChurn> createState() => _PresenceChurnState();
}

class _PresenceChurnState extends State<_PresenceChurn> {
  bool _many = true;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 700), (_) {
      setState(() => _many = !_many);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = _many ? 100 : 20;
    return SingleChildScrollView(
      child: NibPresence.layout(
        axis: NibPresenceAxis.wrap,
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var i = 0; i < n; i++)
            NibMotion(
              key: ValueKey(i),
              initial: const NibAnim(opacity: 0, scale: 0.6),
              animate: const NibAnim(opacity: 1, scale: 1),
              exit: const NibAnim(opacity: 0, scale: 0.6),
              child: _box,
            ),
        ],
      ),
    );
  }
}

class _FanOut extends StatefulWidget {
  const _FanOut(this.count);
  final int count;
  @override
  State<_FanOut> createState() => _FanOutState();
}

class _FanOutState extends State<_FanOut> with SingleTickerProviderStateMixin {
  late final List<MotionValue<double>> _sources = [
    for (var i = 0; i < widget.count; i++) MotionValue<double>(0)
  ];
  late final List<MotionValue<double>> _derived = [
    for (final s in _sources) s.mapRange([0, 1], [0, 60])
  ];
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final t = elapsed.inMicroseconds / 1e6;
      for (var i = 0; i < _sources.length; i++) {
        _sources[i].value = 0.5 + 0.5 * math.sin(t * 2 + i * 0.05);
      }
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    for (final d in _derived) {
      d.dispose();
    }
    for (final s in _sources) {
      s.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Grid(
        count: widget.count,
        item: (i) => NibMotion(
          motionValues: NibMotionValues(translateX: _derived[i]),
          child: _box,
        ),
      );
}

class _Shimmer extends StatelessWidget {
  const _Shimmer();
  @override
  Widget build(BuildContext context) => NibShimmer(
        child: Container(
          color: const Color(0xFFE0E0E0),
          child: const SizedBox.expand(),
        ),
      );
}

class _Glass extends StatelessWidget {
  const _Glass();
  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Color(0xFF02569B),
                Color(0xFFE91E63),
                Color(0xFFFFC107)
              ]),
            ),
          ),
          Center(
            child: NibMotion(
              initial: const NibAnim(x: -200),
              animate: const NibAnim(x: 200),
              repeatAnimationInLoop: true,
              transition: const NibTransition(
                  duration: Duration(seconds: 2), curve: Curves.easeInOut),
              child: const NibGlass(
                child: SizedBox(width: 260, height: 260),
              ),
            ),
          ),
        ],
      );
}

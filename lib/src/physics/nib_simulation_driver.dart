import 'package:flutter/physics.dart' as flutter_physics;
import 'package:flutter/scheduler.dart';

import '../values/motion_value.dart';
import 'driver_completer.dart';

/// Runs any Flutter [flutter_physics.Simulation] (gravity, clamping scroll,
/// a custom decay…) on a [MotionValue<double>].
///
/// It follows the same contract as `SpringSolver`/`InertiaSolver`: it
/// publishes [MotionValue.velocity] every frame so a driver that takes over
/// continues the motion, and its future completes when the simulation is done
/// *or* superseded/stopped.
///
/// ```dart
/// final driver = NibSimulationDriver(vsync: this, value: y);
/// await driver.run(GravitySimulation(2000, y.value, 600, 0));
/// ```
class NibSimulationDriver {
  /// Creates a driver writing to [value], ticking via [vsync].
  NibSimulationDriver({
    required TickerProvider vsync,
    required MotionValue<double> value,
    this.onComplete,
  })  : _vsync = vsync,
        _value = value;

  final TickerProvider _vsync;
  final MotionValue<double> _value;

  /// Called when a simulation finishes on its own (not when superseded).
  void Function()? onComplete;

  final DriverCompleter _completer = DriverCompleter();
  Ticker? _ticker;
  flutter_physics.Simulation? _simulation;
  double _lastT = 0.0;

  /// Whether a simulation is currently running.
  bool get isRunning => _ticker?.isActive ?? false;

  /// Starts [simulation], replacing any running one. Simulation time starts at
  /// `0` on the first frame.
  Future<void> run(flutter_physics.Simulation simulation) {
    _ticker?.stop();
    final future = _completer.begin();
    _simulation = simulation;
    _lastT = 0.0;
    (_ticker ??= _vsync.createTicker(_onTick)).start();
    return future;
  }

  void _onTick(Duration elapsed) {
    final simulation = _simulation!;
    final t = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    if (simulation.isDone(t)) {
      _ticker?.stop();
      // The frame that notices "done" is usually past the end (a falling ball
      // a few pixels under the floor). Find when it actually finished and
      // settle there.
      _value.update(simulation.x(_firstDoneTime(simulation, _lastT, t)));
      _completer.resolve();
      onComplete?.call();
      return;
    }
    _lastT = t;
    _value.update(simulation.x(t), velocity: simulation.dx(t));
  }

  /// Bisects `(lo, hi]` for the first time `isDone` holds, assuming it flips
  /// once (true for every stock Flutter simulation).
  static double _firstDoneTime(
      flutter_physics.Simulation simulation, double lo, double hi) {
    if (simulation.isDone(lo)) return lo;
    for (var i = 0; i < 40; i++) {
      final mid = (lo + hi) / 2;
      if (simulation.isDone(mid)) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    return hi;
  }

  /// Freezes the value; velocity is kept for a following driver. The pending
  /// future completes.
  void stop() {
    _ticker?.stop();
    _completer.resolve();
  }

  /// Stops and disposes the ticker. Safe to call more than once.
  void dispose() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
    _completer.resolve();
  }
}

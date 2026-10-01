import 'package:flutter/physics.dart' as flutter_physics;
import 'package:flutter/scheduler.dart';

import '../values/motion_value.dart';
import 'driver_completer.dart';
import 'spring_description.dart';

/// Drives a [MotionValue<double>] toward a target using real spring physics.
///
/// `SpringSolver` runs a [flutter_physics.SpringSimulation] on a [Ticker] and
/// writes the simulated position to [value] on every tick. Because
/// `MotionValue.value` notifies listeners directly (and `RenderNibMotion`
/// responds by calling `markNeedsPaint()`), this entire chain runs without
/// `setState` or widget rebuilds.
class SpringSolver {
  /// Creates a solver that animates [value] using [spring] physics, ticking
  /// via a [Ticker] obtained from [vsync].
  SpringSolver({
    required TickerProvider vsync,
    required MotionValue<double> value,
    required this.spring,
    this.onComplete,
  })  : _vsync = vsync,
        _value = value;

  final TickerProvider _vsync;
  final MotionValue<double> _value;

  /// The physics parameters used for subsequent [animateTo] calls.
  NibSpringDescription spring;

  /// Called when the running simulation settles within tolerance.
  VoidCallback? onComplete;

  final DriverCompleter _completer = DriverCompleter();
  Ticker? _ticker;
  flutter_physics.SpringSimulation? _simulation;
  double _elapsedSeconds = 0.0;
  double _target = 0.0;

  /// The instantaneous velocity of the current simulation, in units per
  /// second. Returns `0.0` if no simulation has been started.
  double get velocity => _simulation?.dx(_elapsedSeconds) ?? 0.0;

  /// Starts (or restarts) the spring simulation toward [target].
  ///
  /// The simulation starts from the current [MotionValue] position and
  /// [MotionValue.velocity], so a spring taking over from any other driver
  /// (a previous spring, a tween, inertia, a drag) continues that motion
  /// instead of restarting from rest. Pass [from] to start elsewhere (with
  /// zero velocity) and [initialVelocity] to override the inherited velocity.
  ///
  /// The returned future completes when the spring settles, or when this
  /// animation is superseded by another [animateTo] or by [stop]/[dispose].
  Future<void> animateTo({
    required double target,
    double? from,
    double initialVelocity = 0,
  }) {
    final startPosition = from ?? _value.value;
    final startVelocity = initialVelocity != 0
        ? initialVelocity
        : (from == null ? _value.velocity : 0.0);

    _ticker?.stop();
    final future = _completer.begin();
    _target = target;
    _simulation = flutter_physics.SpringSimulation(
      spring.toFlutter(),
      startPosition,
      target,
      startVelocity,
    );
    _elapsedSeconds = 0.0;
    (_ticker ??= _vsync.createTicker(_onTick)).start();
    return future;
  }

  void _onTick(Duration elapsed) {
    final simulation = _simulation!;
    _elapsedSeconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    if (simulation.isDone(_elapsedSeconds)) {
      _ticker?.stop();
      _value.update(_target);
      _completer.resolve();
      onComplete?.call();
      return;
    }
    _value.update(
      simulation.x(_elapsedSeconds),
      velocity: simulation.dx(_elapsedSeconds),
    );
  }

  /// Stops the simulation immediately, freezing [value] at its current
  /// position. [MotionValue.velocity] is left intact so a driver that takes
  /// over continues the motion; the pending [animateTo] future completes.
  void stop() {
    _ticker?.stop();
    _completer.resolve();
  }

  /// Stops and disposes the underlying [Ticker]. Safe to call whether or not
  /// an animation is running.
  void dispose() {
    _ticker?.stop();
    _ticker?.dispose();
    _completer.resolve();
  }
}

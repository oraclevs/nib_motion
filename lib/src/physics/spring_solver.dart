import 'package:flutter/physics.dart' as flutter_physics;
import 'package:flutter/scheduler.dart';

import '../values/motion_value.dart';
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
  }) : _vsync = vsync,
       _value = value;

  final TickerProvider _vsync;
  final MotionValue<double> _value;

  /// The physics parameters used for subsequent [animateTo] calls.
  NibSpringDescription spring;

  /// Called when the running simulation settles within tolerance.
  VoidCallback? onComplete;

  Ticker? _ticker;
  flutter_physics.SpringSimulation? _simulation;
  double _elapsedSeconds = 0.0;

  /// The instantaneous velocity of the current simulation, in units per
  /// second. Returns `0.0` if no simulation has been started.
  double get velocity => _simulation?.dx(_elapsedSeconds) ?? 0.0;

  /// Starts (or restarts) the spring simulation toward [target].
  ///
  /// If [from] is omitted, the simulation starts from the current
  /// [MotionValue] position. If [initialVelocity] is omitted (or `0`) while
  /// a simulation is already running, the new simulation continues with the
  /// outgoing simulation's current velocity and position so motion remains
  /// continuous.
  void animateTo({
    required double target,
    double? from,
    double initialVelocity = 0,
  }) {
    var startPosition = from ?? _value.value;
    var startVelocity = initialVelocity;

    final runningSimulation = _simulation;
    if (_ticker != null && _ticker!.isActive && runningSimulation != null) {
      startVelocity = initialVelocity != 0
          ? initialVelocity
          : runningSimulation.dx(_elapsedSeconds);
      startPosition = from ?? runningSimulation.x(_elapsedSeconds);
    }

    _ticker?.stop();
    _simulation = flutter_physics.SpringSimulation(
      spring.toFlutter(),
      startPosition,
      target,
      startVelocity,
    );
    _elapsedSeconds = 0.0;
    (_ticker ??= _vsync.createTicker(_onTick)).start();
  }

  void _onTick(Duration elapsed) {
    final simulation = _simulation!;
    _elapsedSeconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    _value.value = simulation.x(_elapsedSeconds);
    if (simulation.isDone(_elapsedSeconds)) {
      _ticker?.stop();
      onComplete?.call();
    }
  }

  /// Stops the simulation immediately, freezing [value] at its current
  /// position.
  void stop() {
    _ticker?.stop();
  }

  /// Stops and disposes the underlying [Ticker]. Safe to call whether or not
  /// an animation is running.
  void dispose() {
    _ticker?.stop();
    _ticker?.dispose();
  }
}

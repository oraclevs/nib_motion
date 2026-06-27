import 'package:flutter/physics.dart' as flutter_physics;
import 'package:flutter/scheduler.dart';

import '../values/motion_value.dart';

/// Drives a [MotionValue<double>] with a decelerating "coast to a stop"
/// simulation, using the same friction model iOS uses for scroll
/// deceleration.
///
/// `InertiaSolver` runs a [flutter_physics.FrictionSimulation] on a [Ticker]
/// and writes the simulated position to [value] on every tick, the same
/// pattern `SpringSolver` uses.
class InertiaSolver {
  /// Creates a solver that decelerates [value] from its current position,
  /// ticking via a [Ticker] obtained from [vsync].
  InertiaSolver({
    required TickerProvider vsync,
    required MotionValue<double> value,
    this.drag = 0.135,
    this.onComplete,
  })  : _vsync = vsync,
        _value = value;

  final TickerProvider _vsync;
  final MotionValue<double> _value;

  /// The friction coefficient used for subsequent [animateTo] calls. Values
  /// closer to `1.0` coast farther before stopping; `0.135` matches the
  /// deceleration rate iOS uses for scrolling.
  double drag;

  /// Called when the running simulation settles within tolerance.
  VoidCallback? onComplete;

  Ticker? _ticker;
  flutter_physics.FrictionSimulation? _simulation;
  double _elapsedSeconds = 0.0;

  /// Starts a deceleration simulation from the current [MotionValue]
  /// position with the given initial [velocity], in units per second.
  void animateTo({required double velocity}) {
    _ticker?.stop();
    _simulation =
        flutter_physics.FrictionSimulation(drag, _value.value, velocity);
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

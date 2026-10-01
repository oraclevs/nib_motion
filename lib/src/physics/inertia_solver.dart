import 'package:flutter/physics.dart' as flutter_physics;
import 'package:flutter/scheduler.dart';

import '../values/motion_value.dart';
import 'driver_completer.dart';
import 'driver_guard.dart';
import 'spring_description.dart';

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

  /// The spring that pulls the value back to a bound it overshot. Defaults to
  /// a critically-damped-ish spring that feels like a scroll view bounce.
  NibSpringDescription boundsSpring = const NibSpringDescription(
    mass: 0.5,
    stiffness: 100.0,
    damping: 15.0,
  );

  final DriverCompleter _completer = DriverCompleter();
  Ticker? _ticker;
  flutter_physics.Simulation? _simulation;
  double _elapsedSeconds = 0.0;

  /// Starts a deceleration simulation from the current [MotionValue]
  /// position with the given initial [velocity], in units per second.
  ///
  /// With [min] and/or [max], the value is elastically bounded: if the
  /// coast would cross a bound it overshoots it and springs back (using
  /// [boundsSpring]), coming to rest exactly on the bound. A value that
  /// starts outside the bounds springs back to the nearest one.
  ///
  /// The returned future completes when the value comes to rest, or when the
  /// animation is superseded by another [animateTo] or by [stop]/[dispose].
  Future<void> animateTo({required double velocity, double? min, double? max}) {
    assert(min == null || max == null || min <= max, 'min must be <= max');
    if (!nibAcceptFinite('velocity', velocity) ||
        (min != null && !nibAcceptFinite('min', min)) ||
        (max != null && !nibAcceptFinite('max', max))) {
      return Future.value();
    }
    _ticker?.stop();
    final future = _completer.begin();
    _simulation = _CoastSimulation(
      position: _value.value,
      velocity: velocity,
      drag: drag,
      min: min,
      max: max,
      spring: boundsSpring.toFlutter(),
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
      _value.update((simulation as _CoastSimulation).restingX);
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

/// Friction coast with optional elastic bounds, as a single [Simulation].
///
/// Phases: friction until the bound is reached (found analytically with
/// [flutter_physics.FrictionSimulation.timeAtX]) → a spring seeded with the
/// crossing velocity that overshoots and returns to the bound. If the start
/// is already outside, only the spring phase runs.
class _CoastSimulation extends flutter_physics.Simulation {
  _CoastSimulation({
    required double position,
    required double velocity,
    required double drag,
    required double? min,
    required double? max,
    required flutter_physics.SpringDescription spring,
  }) {
    final friction = flutter_physics.FrictionSimulation(
      drag,
      position,
      velocity,
    );
    _friction = friction;
    restingX = friction.finalX;

    double? bound;
    if (min != null && position < min) {
      bound = min;
      _frictionEnd = 0;
    } else if (max != null && position > max) {
      bound = max;
      _frictionEnd = 0;
    } else if (min != null && friction.finalX < min) {
      bound = min;
      _frictionEnd = friction.timeAtX(min);
    } else if (max != null && friction.finalX > max) {
      bound = max;
      _frictionEnd = friction.timeAtX(max);
    }

    if (bound != null) {
      restingX = bound;
      final crossVelocity =
          _frictionEnd == 0 ? velocity : friction.dx(_frictionEnd);
      _spring = flutter_physics.SpringSimulation(
        spring,
        _frictionEnd == 0 ? position : bound,
        bound,
        crossVelocity,
      );
      // Spring position is absolute (start → bound), so no offset is needed.
    }
  }

  late final flutter_physics.FrictionSimulation _friction;
  flutter_physics.SpringSimulation? _spring;
  double _frictionEnd = double.infinity;

  /// The position the motion comes to rest at.
  late double restingX;

  @override
  double x(double time) {
    final spring = _spring;
    if (spring == null || time < _frictionEnd) return _friction.x(time);
    return spring.x(time - _frictionEnd);
  }

  @override
  double dx(double time) {
    final spring = _spring;
    if (spring == null || time < _frictionEnd) return _friction.dx(time);
    return spring.dx(time - _frictionEnd);
  }

  @override
  bool isDone(double time) {
    final spring = _spring;
    if (spring == null) return _friction.isDone(time);
    return time >= _frictionEnd && spring.isDone(time - _frictionEnd);
  }
}

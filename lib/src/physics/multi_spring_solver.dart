import 'package:flutter/physics.dart' as flutter_physics;
import 'package:flutter/scheduler.dart';

import '../values/motion_converter.dart';
import '../values/motion_value.dart';
import 'driver_completer.dart';
import 'driver_guard.dart';
import 'spring_description.dart';

/// Drives a [MotionValue] of a composite type (`Offset`, `Size`, `Color`, …)
/// with one spring **per channel**, so each axis keeps its own position and
/// velocity.
///
/// Retargeting mid-flight starts every channel from its current position and
/// current velocity (per-axis momentum hand-off). A value that was assigned
/// from outside since the last tick counts as a jump: velocities reset to `0`.
///
/// One [Ticker] drives all channels and the composed value is written (and
/// listeners notified) once per frame.
class MultiSpringSolver<T> {
  /// Creates a solver for [value] using [converter] to split it into channels.
  MultiSpringSolver({
    required TickerProvider vsync,
    required MotionValue<T> value,
    required this.converter,
    required this.spring,
    this.onComplete,
  })  : _vsync = vsync,
        _value = value,
        _velocities = List<double>.filled(converter.channels, 0.0);

  final TickerProvider _vsync;
  final MotionValue<T> _value;

  /// Splits [T] into scalar channels.
  final MotionConverter<T> converter;

  /// The spring used by subsequent [animateTo] calls (applied to every channel).
  NibSpringDescription spring;

  /// Called when all channels have settled naturally.
  void Function()? onComplete;

  final DriverCompleter _completer = DriverCompleter();
  Ticker? _ticker;
  List<flutter_physics.SpringSimulation?> _sims = const [];
  List<double> _targets = const [];
  final List<double> _velocities;
  T? _lastWritten;
  bool _hasWritten = false;
  double _elapsed = 0.0;

  /// Current per-channel velocities, in channel units per second.
  List<double> get velocities => List<double>.unmodifiable(_velocities);

  /// Whether a spring is currently running.
  bool get isAnimating => _ticker?.isActive ?? false;

  /// Springs every channel toward [target].
  ///
  /// [initialVelocity] (one number per channel) overrides the inherited
  /// per-channel velocity. With [immediate] the value jumps to [target] with
  /// zero velocity (used for reduced motion).
  ///
  /// The returned future completes when all channels settle, or when this
  /// animation is superseded by another [animateTo] or by [stop]/[dispose].
  Future<void> animateTo(
    T target, {
    List<double>? initialVelocity,
    bool immediate = false,
  }) {
    assert(initialVelocity == null ||
        initialVelocity.length == converter.channels);
    final targetChannels = converter.normalize(target);
    if (!targetChannels.every((c) => nibAcceptFinite('target', c)) ||
        (initialVelocity != null &&
            !initialVelocity.every((v) => nibAcceptFinite('velocity', v)))) {
      return Future.value();
    }
    _ticker?.stop();
    final future = _completer.begin();

    if (immediate) {
      _write(converter.normalize(target));
      _velocities.fillRange(0, _velocities.length, 0.0);
      _completer.resolve();
      onComplete?.call();
      return future;
    }

    final from = converter.normalize(_value.value);
    // An outside write since our last tick is a jump, not momentum.
    final jumped = _hasWritten && _lastWritten != _value.value;
    final to = converter.normalize(target);
    _targets = to;
    _sims = [
      for (var i = 0; i < from.length; i++)
        flutter_physics.SpringSimulation(
          spring.toFlutter(),
          from[i],
          to[i],
          initialVelocity?[i] ?? (jumped ? 0.0 : _velocities[i]),
        ),
    ];
    _elapsed = 0.0;
    (_ticker ??= _vsync.createTicker(_onTick)).start();
    return future;
  }

  void _onTick(Duration elapsed) {
    _elapsed = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    var allDone = true;
    final xs = List<double>.filled(_sims.length, 0.0);
    for (var i = 0; i < _sims.length; i++) {
      final sim = _sims[i]!;
      if (sim.isDone(_elapsed)) {
        xs[i] = _targets[i];
        _velocities[i] = 0.0;
      } else {
        allDone = false;
        xs[i] = sim.x(_elapsed);
        _velocities[i] = sim.dx(_elapsed);
      }
    }
    _write(xs);
    if (allDone) {
      _ticker?.stop();
      _completer.resolve();
      onComplete?.call();
    }
  }

  void _write(List<double> channels) {
    final next = converter.denormalize(channels);
    _lastWritten = next;
    _hasWritten = true;
    _value.update(next);
  }

  /// Freezes the value where it is. Per-channel velocities are kept for a
  /// following [animateTo]; the pending future completes.
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

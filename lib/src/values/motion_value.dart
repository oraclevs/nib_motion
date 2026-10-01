import 'package:flutter/foundation.dart';

import 'computed_motion_value.dart';
import 'derived_motion_value.dart';

/// A reactive container for a single animatable value of type [T].
///
/// `MotionValue` is the core primitive that animation drivers (such as
/// [SpringSolver]) write to and that `RenderNibMotion` listens to in order to
/// repaint directly via `markNeedsPaint()`. Setting [value] notifies
/// listeners exactly once per distinct change — no widget rebuilds occur as
/// a result.
class MotionValue<T> extends ChangeNotifier implements ValueListenable<T> {
  /// Creates a [MotionValue] holding [initial] as its starting value.
  MotionValue(T initial) : _value = initial;

  T _value;
  double _velocity = 0.0;

  @override
  T get value => _value;

  /// The instantaneous rate of change of this value, in units per second.
  ///
  /// Animation drivers ([SpringSolver], [InertiaSolver], tweens) publish
  /// their velocity through [update], and a new driver starts from it, so an
  /// interrupted animation hands its momentum to whatever takes over instead
  /// of restarting from rest. Plain assignment to [value] is a *jump* and
  /// resets the velocity to `0`. Always `0` for non-numeric values.
  double get velocity => _velocity;

  /// Updates the current value.
  ///
  /// If [newValue] is equal to the current value, listeners are not
  /// notified. Otherwise the value is replaced and [ChangeNotifier]
  /// listeners are notified synchronously.
  set value(T newValue) => update(newValue);

  /// Sets [value] and records [velocity] (units per second) alongside it.
  ///
  /// Listeners are notified only when the value itself changes. Used by
  /// animation drivers so momentum survives interruption; see [velocity].
  void update(T newValue, {double velocity = 0.0}) {
    final candidate = newValue;
    if (candidate is double && !candidate.isFinite) {
      // A NaN/infinite position would stay in the value (and the transform
      // built from it) forever. Loud in debug, ignored in release.
      if (kDebugMode) {
        throw ArgumentError.value(
            candidate, 'newValue', 'MotionValue<double> must stay finite');
      }
      return;
    }
    _velocity = velocity.isFinite ? velocity : 0.0;
    if (_value == newValue) return;
    _value = newValue;
    notifyListeners();
  }

  /// Whether this value currently has any listeners attached.
  ///
  /// The inherited `ChangeNotifier.hasListeners` is `@protected`; this
  /// override makes it public so derived values and tests can verify
  /// listener wiring (e.g. that disposing a [DerivedMotionValue] removes its
  /// listener from its source).
  @override
  bool get hasListeners => super.hasListeners;

  /// Creates a lazy, glitch-free [ComputedMotionValue] that re-evaluates
  /// [compute] after any of [dependencies] changes.
  ///
  /// ```dart
  /// final scale = MotionValue.computed(
  ///     [progress, boost], () => 0.9 + progress.value * boost.value);
  /// ```
  static ComputedMotionValue<R> computed<R>(
    List<Listenable> dependencies,
    R Function() compute,
  ) =>
      ComputedMotionValue<R>(dependencies, compute);

  /// Creates a [DerivedMotionValue] that tracks `mapper(value)`.
  ///
  /// The derived value recomputes (and notifies its own listeners) whenever
  /// this value changes. The returned value is itself a [MotionValue], so
  /// `transform` calls can be chained.
  DerivedMotionValue<T, R> transform<R>(R Function(T value) mapper) {
    return DerivedMotionValue<T, R>(this, mapper);
  }
}

/// Creates a [MotionValue] holding [initial] as its starting value.
MotionValue<T> motionValue<T>(T initial) => MotionValue<T>(initial);

/// Adds [mapRange] to numeric [MotionValue]s.
extension MotionValueMapRange on MotionValue<double> {
  /// Creates a [DerivedMotionValue] that linearly maps this value from
  /// [inputRange] to [outputRange].
  ///
  /// [inputRange] and [outputRange] are parallel lists: `inputRange[i]`
  /// corresponds to `outputRange[i]`. At least two stops are required.
  /// Between stops, the result is linearly interpolated. When [clamp] is
  /// true (the default), values outside [inputRange] are clamped to the
  /// nearest end of [outputRange]; otherwise the first/last segment's slope
  /// is extrapolated.
  DerivedMotionValue<double, double> mapRange(
    List<double> inputRange,
    List<double> outputRange, {
    bool clamp = true,
  }) {
    assert(
      inputRange.length == outputRange.length,
      'inputRange and outputRange must have the same number of stops.',
    );
    assert(inputRange.length >= 2, 'mapRange requires at least two stops.');
    return DerivedMotionValue<double, double>(
      this,
      (input) => _mapRangeValue(input, inputRange, outputRange, clamp),
      velocityMapper: (input, velocity) =>
          _mapRangeSlope(input, inputRange, outputRange, clamp) * velocity,
    );
  }
}

double _mapRangeSlope(
  double input,
  List<double> inputRange,
  List<double> outputRange,
  bool clamp,
) {
  if (clamp && (input <= inputRange.first || input >= inputRange.last)) {
    return 0.0;
  }
  final segment = _segmentFor(input, inputRange);
  final run = inputRange[segment + 1] - inputRange[segment];
  if (run == 0) return 0.0;
  return (outputRange[segment + 1] - outputRange[segment]) / run;
}

int _segmentFor(double input, List<double> inputRange) {
  final lastSegment = inputRange.length - 2;
  for (var i = 0; i < lastSegment + 1; i++) {
    if (input <= inputRange[i + 1]) return i;
  }
  return lastSegment;
}

double _mapRangeValue(
  double input,
  List<double> inputRange,
  List<double> outputRange,
  bool clamp,
) {
  if (clamp) {
    if (input <= inputRange.first) return outputRange.first;
    if (input >= inputRange.last) return outputRange.last;
  }

  final segment = _segmentFor(input, inputRange);

  final inStart = inputRange[segment];
  final inEnd = inputRange[segment + 1];
  final outStart = outputRange[segment];
  final outEnd = outputRange[segment + 1];
  final t = (input - inStart) / (inEnd - inStart);
  return outStart + (outEnd - outStart) * t;
}

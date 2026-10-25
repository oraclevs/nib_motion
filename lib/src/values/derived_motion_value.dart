import 'motion_value.dart';

/// A [MotionValue] whose value is computed from a source [MotionValue].
///
/// Created via [MotionValue.transform] or [MotionValueMapRange.mapRange].
/// Whenever the source value changes, [mapper] is re-applied and the result
/// is written to this value (which in turn notifies its own listeners only
/// if the mapped result actually changed).
///
/// Because a `DerivedMotionValue` is itself a [MotionValue], it can be
/// chained: `source.transform(...).transform(...)`.
class DerivedMotionValue<S, T> extends MotionValue<T> {
  /// Creates a value derived from `source` by applying [mapper].
  ///
  /// If [velocityMapper] is given it converts the source's `(value, velocity)`
  /// into this value's velocity (e.g. `mapRange` multiplies by the segment
  /// slope); otherwise the derived velocity is `0`.
  DerivedMotionValue(this._source, this.mapper, {this.velocityMapper})
      : super(mapper(_source.value)) {
    _source.addListener(_recompute);
  }

  final MotionValue<S> _source;

  /// The function applied to the source value to produce this value.
  final T Function(S) mapper;

  /// Maps the source's value and velocity to this value's velocity.
  final double Function(S value, double velocity)? velocityMapper;

  void _recompute() {
    update(
      mapper(_source.value),
      velocity: velocityMapper?.call(_source.value, _source.velocity) ?? 0.0,
    );
  }

  @override
  void dispose() {
    _source.removeListener(_recompute);
    super.dispose();
  }
}

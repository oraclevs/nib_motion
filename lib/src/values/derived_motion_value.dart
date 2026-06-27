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
  DerivedMotionValue(this._source, this.mapper) : super(mapper(_source.value)) {
    _source.addListener(_recompute);
  }

  final MotionValue<S> _source;

  /// The function applied to the source value to produce this value.
  final T Function(S) mapper;

  void _recompute() {
    value = mapper(_source.value);
  }

  @override
  void dispose() {
    _source.removeListener(_recompute);
    super.dispose();
  }
}

import 'package:flutter/foundation.dart';

import 'motion_value.dart';

/// A read-only [MotionValue] computed from any number of dependencies.
///
/// Unlike [DerivedMotionValue] (one source, eager), a `ComputedMotionValue`
/// depends on several [Listenable]s — typically other [MotionValue]s, but
/// scroll positions, animation controllers and notifiers work too — and is
/// **lazy**:
///
/// * When a dependency changes the value is only marked stale and its own
///   listeners are notified; [compute] runs the next time [value] is read
///   (in practice: at paint time, after every dependency has finished
///   updating). In a diamond-shaped graph (`a → b`, `a → c`, `d = f(b, c)`)
///   a render object reading `d` at paint therefore sees `b` and `c` both
///   updated. A listener that reads `d` *synchronously while `a` is still
///   notifying* can still observe an eager [DerivedMotionValue] intermediate;
///   read in paint/layout, or after the update that triggered the change.
/// * Dependencies must exist before the computed value, so cycles cannot be
///   constructed; no cycle detection is needed.
///
/// [velocity] is `0`: a computed value has no closed-form derivative. Use
/// [MotionValueMapRange.mapRange] when velocity must flow through a mapping.
///
/// Assigning to [value] or calling [update] throws a [StateError].
class ComputedMotionValue<T> extends MotionValue<T> {
  /// Creates a value that evaluates [compute] whenever it is read after one of
  /// [dependencies] has changed.
  ComputedMotionValue(List<Listenable> dependencies, this.compute)
      : _dependencies = List<Listenable>.unmodifiable(dependencies),
        super(compute()) {
    _cache = super.value;
    for (final dependency in _dependencies) {
      dependency.addListener(_onDependencyChanged);
    }
  }

  /// Computes the current value from the dependencies.
  final T Function() compute;

  final List<Listenable> _dependencies;
  late T _cache;
  bool _stale = false;

  void _onDependencyChanged() {
    _stale = true;
    notifyListeners();
  }

  @override
  T get value {
    if (_stale) {
      _stale = false;
      _cache = compute();
    }
    return _cache;
  }

  @override
  void update(T newValue, {double velocity = 0.0}) {
    throw StateError('A ComputedMotionValue is read-only.');
  }

  @override
  void dispose() {
    for (final dependency in _dependencies) {
      dependency.removeListener(_onDependencyChanged);
    }
    super.dispose();
  }
}

import 'package:flutter/foundation.dart';

import '../values/motion_value.dart';

/// A global, debug-only registry of live [MotionValue]s.
///
/// `NibMotion` widgets (or any other code in the package/app) can opt in to
/// registering their [MotionValue]s here under a stable string id so that
/// debug tooling — such as `NibMotionDebugger` — can list every animatable
/// value currently alive, without the core animation pipeline needing any
/// compile-time knowledge of the debugger.
///
/// Despite the filename (`motion_value_inspector.dart`, per the package's
/// file layout), the public type is named [NibMotionRegistry] to match the
/// rest of the debug-tooling API (`NibMotionDebugger`, `NibPerfOverlay`).
///
/// Every method is a no-op outside of [kDebugMode] — in profile/release
/// builds, [register] and [unregister] do nothing and [values] always
/// returns an empty, unmodifiable map. This keeps the registry from
/// retaining references to (and thus keeping alive) `MotionValue`s in
/// production builds, and guarantees zero overhead outside debug mode.
class NibMotionRegistry {
  NibMotionRegistry._();

  /// The single global instance of this registry.
  static final NibMotionRegistry instance = NibMotionRegistry._();

  final Map<String, MotionValue<dynamic>> _values = {};

  /// Registers [value] under [id].
  ///
  /// If [id] is already registered, this replaces the previous entry.
  /// No-op outside [kDebugMode].
  void register(String id, MotionValue<dynamic> value) {
    if (!kDebugMode) return;
    _values[id] = value;
  }

  /// Removes the entry previously registered under [id], if any.
  ///
  /// No-op outside [kDebugMode].
  void unregister(String id) {
    if (!kDebugMode) return;
    _values.remove(id);
  }

  /// A snapshot of every currently-registered [MotionValue], keyed by id.
  ///
  /// The returned map is unmodifiable — callers must go through [register]
  /// and [unregister] to change membership. Always empty outside
  /// [kDebugMode].
  Map<String, MotionValue<dynamic>> get values {
    if (!kDebugMode) return Map.unmodifiable(const <String, Never>{});
    return Map.unmodifiable(_values);
  }
}

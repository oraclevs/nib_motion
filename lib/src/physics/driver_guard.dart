import 'package:flutter/foundation.dart';

/// Validates a numeric driver input.
///
/// Returns `true` when [value] is finite. Otherwise debug builds throw an
/// [ArgumentError] naming [name] (so the bug is found where the NaN is
/// produced), and release builds return `false` so the caller can ignore the
/// request instead of writing NaN into a `MotionValue`.
bool nibAcceptFinite(String name, double value) {
  if (value.isFinite) return true;
  if (kDebugMode) {
    throw ArgumentError.value(value, name, 'must be finite');
  }
  return false;
}

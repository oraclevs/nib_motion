import 'package:flutter/foundation.dart';

/// Global gate that holds `NibMotion` entrance animations at their initial
/// frame until the app signals that it's actually visible to the user.
///
/// By default the gate is open ([ready] starts `true`), so `NibMotion` only
/// applies its small built-in [warm-up delay][NibMotionConfig.entranceWarmup]
/// before starting entrance animations.
///
/// Apps that preserve a native splash screen (e.g. via `flutter_native_splash`
/// in "preserve" mode) can call [hold] before `runApp` and [release] once the
/// splash is actually removed, so entrance animations don't run underneath it:
///
/// ```dart
/// void main() {
///   NibMotionGate.hold();
///   runApp(const MyApp());
/// }
///
/// // After FlutterNativeSplash.remove():
/// NibMotionGate.release();
/// ```
abstract final class NibMotionGate {
  /// Whether `NibMotion` entrance animations are allowed to start.
  ///
  /// `NibMotion` widgets listen to this and hold their entrance animation at
  /// its initial frame while it's `false`.
  static final ValueNotifier<bool> ready = ValueNotifier<bool>(true);

  /// Holds all `NibMotion` entrance animations at their initial frame until
  /// [release] is called.
  static void hold() => ready.value = false;

  /// Releases any entrance animations held by [hold].
  static void release() => ready.value = true;

  /// Resets the gate to its default open state.
  ///
  /// Intended for tests.
  static void reset() => ready.value = true;
}

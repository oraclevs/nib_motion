import 'dart:ui' show FragmentProgram;

import 'package:flutter/foundation.dart' show visibleForTesting;

/// Asset paths for every fragment shader bundled with `nib_motion`.
///
/// These must match the `flutter.shaders` entries in `pubspec.yaml`.
class NibShaderAssets {
  NibShaderAssets._();

  /// Asset path for the shimmer/skeleton-loading shader.
  static const String shimmer = 'packages/nib_motion/lib/shaders/shimmer.frag';

  /// Asset path for the noise-based dissolve transition shader.
  static const String dissolve =
      'packages/nib_motion/lib/shaders/dissolve.frag';

  /// Asset path for the animated gradient sweep shader.
  static const String gradientSweep =
      'packages/nib_motion/lib/shaders/gradient_sweep.frag';

  /// Asset path for the liquid-glass backdrop-refraction shader.
  static const String liquidGlass =
      'packages/nib_motion/lib/shaders/liquid_glass.frag';
}

/// A singleton cache/loader for the [FragmentProgram]s bundled with
/// `nib_motion`.
///
/// `FragmentProgram.fromAsset` compiles a shader asynchronously the first
/// time it's requested; widgets such as `NibShimmer` and `NibDissolve` call
/// straight into this loader and create their `FragmentShader` instances
/// once the relevant program resolves. Call [preloadAll] once at app
/// startup (via `NibMotionConfig.init`) so the first shader-backed widget
/// built doesn't pay the compilation cost on its own first frame.
class NibShaderLoader {
  NibShaderLoader._();

  static final Map<String, Future<FragmentProgram>> _cache = {};

  /// Maps an asset key to the key actually passed to
  /// `FragmentProgram.fromAsset`. `null` (the default) uses keys as-is.
  ///
  /// Test-friendly: inside this package's own `flutter test` runs, the
  /// bundled shaders resolve under the root-package key
  /// (`lib/shaders/shimmer.frag`), not `packages/nib_motion/lib/shaders/…`
  /// (which only exists in a consuming app). Set
  /// `(key) => key.replaceFirst('packages/nib_motion/', '')` to exercise the
  /// real shaders; [resetForTesting] clears it.
  @visibleForTesting
  static String Function(String assetKey)? assetKeyResolver;

  /// Returns the cached or newly-started [Future] that resolves to the
  /// compiled [FragmentProgram] for the shimmer shader.
  static Future<FragmentProgram> shimmer() => _load(NibShaderAssets.shimmer);

  /// Returns the cached or newly-started [Future] that resolves to the
  /// compiled [FragmentProgram] for the dissolve shader.
  static Future<FragmentProgram> dissolve() => _load(NibShaderAssets.dissolve);

  /// Returns the cached or newly-started [Future] that resolves to the
  /// compiled [FragmentProgram] for the gradient sweep shader.
  static Future<FragmentProgram> gradientSweep() =>
      _load(NibShaderAssets.gradientSweep);

  /// Returns the cached or newly-started [Future] that resolves to the
  /// compiled [FragmentProgram] for the liquid-glass shader.
  static Future<FragmentProgram> liquidGlass() =>
      _load(NibShaderAssets.liquidGlass);

  /// Loads (and caches) any fragment program by [assetKey].
  ///
  /// For your own shader declare it under `flutter: shaders:` in your app's
  /// pubspec and pass its asset path (for a package asset,
  /// `packages/<package>/<path>`). Used by `NibShaderEffect`.
  static Future<FragmentProgram> load(String assetKey) => _load(assetKey);

  static Future<FragmentProgram> _load(String assetKey) {
    return _cache.putIfAbsent(assetKey, () {
      late final Future<FragmentProgram> pending;
      pending = FragmentProgram.fromAsset(
              assetKeyResolver?.call(assetKey) ?? assetKey)
          .then((program) => program,
              onError: (Object error, StackTrace stack) {
        // A later mount may retry; do not evict a newer generation after reset.
        if (identical(_cache[assetKey], pending)) _cache.remove(assetKey);
        Error.throwWithStackTrace(error, stack);
      });
      return pending;
    });
  }

  /// Kicks off compilation of every bundled shader and waits for all of
  /// them to finish (or fail).
  ///
  /// Failures are caught and swallowed here rather than rethrown: a host
  /// app that doesn't bundle the shader assets (or runs in an environment
  /// without shader compilation support, such as some test harnesses)
  /// should still be able to start — shader-backed widgets fall back to
  /// painting only their child when their program never resolves. Callers
  /// that need to know whether preloading actually succeeded should call
  /// [shimmer]/[dissolve]/[gradientSweep] directly and inspect the
  /// resulting [Future].
  static Future<void> preloadAll() async {
    await Future.wait<void>([
      shimmer().then((_) {}, onError: (_) {}),
      dissolve().then((_) {}, onError: (_) {}),
      gradientSweep().then((_) {}, onError: (_) {}),
      liquidGlass().then((_) {}, onError: (_) {}),
    ]);
  }

  /// Removes every cached program, forcing the next call to
  /// [shimmer]/[dissolve]/[gradientSweep] to recompile from the asset.
  ///
  /// Intended for tests.
  static void resetForTesting() {
    _cache.clear();
    assetKeyResolver = null;
  }
}

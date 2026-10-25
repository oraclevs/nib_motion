import 'package:flutter/widgets.dart';

import '../shaders/shader_loader.dart';
import 'nib_transition.dart';

/// Global configuration for `NibMotion` widgets.
///
/// Provide a `NibMotionConfig` as an ancestor to override the system's
/// reduced-motion preference and/or set a default [NibTransition] for
/// `NibMotion` widgets that don't specify their own.
///
/// ```dart
/// NibMotionConfig(
///   defaultTransition: NibTransition.springGentle,
///   child: MyApp(),
/// )
/// ```
class NibMotionConfig extends InheritedWidget {
  /// Creates a `NibMotionConfig`.
  ///
  /// If [reducedMotion] is `null`, `NibMotion` falls back to
  /// `MediaQuery.of(context).disableAnimations`.
  const NibMotionConfig({
    super.key,
    this.reducedMotion,
    this.defaultTransition = const NibTransition(),
    this.entranceWarmup = const Duration(milliseconds: 400),
    required super.child,
  });

  /// Overrides `MediaQuery.disableAnimations` when non-`null`.
  final bool? reducedMotion;

  /// The transition used by `NibMotion` widgets that don't specify their own
  /// [NibMotion.transition].
  final NibTransition defaultTransition;

  /// How long after the app starts `NibMotion` entrance animations
  /// (`animate`/`keyframes` on first build, and an immediately-visible
  /// `whileInView`) should wait before starting.
  ///
  /// This absorbs the brief delay on real devices between Flutter rendering
  /// its first frame and the native splash screen actually disappearing, so
  /// entrance animations don't run unseen underneath it. Widgets created
  /// after this warm-up window has elapsed (e.g. on a later screen) start
  /// immediately, as before.
  ///
  /// Defaults to 400ms, which comfortably covers the gap between Flutter's
  /// first frame and the platform's native splash screen actually
  /// disappearing on a real device — so entrance animations don't run (and
  /// finish) unseen underneath it. See also [NibMotionGate] for apps that
  /// preserve a native splash screen for longer than this.
  final Duration entranceWarmup;

  static bool? _reducedMotionOverride;

  static DateTime _appStartedAt = DateTime.now();

  /// Resets the app-start timestamp used by [remainingWarmup] to now.
  ///
  /// Intended for tests.
  @visibleForTesting
  static void resetAppStartTime() {
    _appStartedAt = DateTime.now();
  }

  /// Globally forces (`true`), disables (`false`), or clears (`null`) the
  /// reduced-motion override, regardless of any [NibMotionConfig] ancestor or
  /// `MediaQuery` setting.
  ///
  /// Intended for tests; production code should prefer the [reducedMotion]
  /// constructor parameter.
  static void setReducedMotion(bool? value) {
    _reducedMotionOverride = value;
  }

  /// Returns the nearest ancestor `NibMotionConfig`, or `null` if there is
  /// none.
  static NibMotionConfig? maybeOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<NibMotionConfig>();
  }

  /// Resolves whether `NibMotion` animations should jump straight to their
  /// target instead of animating.
  ///
  /// Resolution order: [setReducedMotion] override, then
  /// [NibMotionConfig.reducedMotion], then
  /// `MediaQuery.of(context).disableAnimations`.
  static bool shouldReduceMotion(BuildContext context) {
    final override = _reducedMotionOverride;
    if (override != null) return override;

    final configValue = maybeOf(context)?.reducedMotion;
    if (configValue != null) return configValue;

    final mediaQuery = context.getInheritedWidgetOfExactType<MediaQuery>();
    return mediaQuery?.data.disableAnimations ?? false;
  }

  /// Like [shouldReduceMotion], but registers a dependency on the nearest
  /// [NibMotionConfig] and `MediaQuery`, so the calling element rebuilds
  /// (and `didChangeDependencies` runs) when the preference changes.
  static bool watchReducedMotion(BuildContext context) {
    final override = _reducedMotionOverride;
    if (override != null) return override;

    final config =
        context.dependOnInheritedWidgetOfExactType<NibMotionConfig>();
    final configValue = config?.reducedMotion;
    if (configValue != null) return configValue;

    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  /// Resolves the default transition for `NibMotion` widgets that don't
  /// specify their own [NibMotion.transition].
  static NibTransition defaultTransitionOf(BuildContext context) {
    return maybeOf(context)?.defaultTransition ?? const NibTransition();
  }

  /// Returns how much longer entrance animations should wait before
  /// starting, based on [entranceWarmup] and how long ago the app started.
  ///
  /// Returns [Duration.zero] once the warm-up window has elapsed.
  static Duration remainingWarmup(BuildContext context) {
    final warmup =
        maybeOf(context)?.entranceWarmup ?? const Duration(milliseconds: 400);
    // Read `_appStartedAt` (which lazily initializes to `DateTime.now()` on
    // first access) before calling `DateTime.now()` again here, so `elapsed`
    // can never be negative.
    final startedAt = _appStartedAt;
    final elapsed = DateTime.now().difference(startedAt);
    final remaining = warmup - elapsed;
    return remaining > Duration.zero ? remaining : Duration.zero;
  }

  @override
  bool updateShouldNotify(NibMotionConfig oldWidget) {
    return reducedMotion != oldWidget.reducedMotion ||
        defaultTransition != oldWidget.defaultTransition ||
        entranceWarmup != oldWidget.entranceWarmup;
  }

  static NibTransition _globalDefaultTransition = const NibTransition();

  static bool _globalReducedMotion = false;

  /// The process-wide default [NibTransition] set by the most recent
  /// [init] call.
  ///
  /// This is distinct from the per-subtree [defaultTransition] resolved by
  /// [defaultTransitionOf] — code that runs outside a `BuildContext` (e.g.
  /// imperative animation setup) can read this directly.
  static NibTransition get globalDefaultTransition => _globalDefaultTransition;

  /// The process-wide reduced-motion preference set by the most recent
  /// [init] call's `respectReducedMotion` resolution.
  ///
  /// This reflects [init]'s one-time startup resolution; it does not track
  /// later `MediaQuery` or [setReducedMotion] changes — prefer
  /// [shouldReduceMotion] inside a `BuildContext` for that.
  static bool get reducedMotionEnabled => _globalReducedMotion;

  /// Call once at app startup, before `runApp()`, to pre-load
  /// `nib_motion`'s bundled fragment shaders and configure framework-wide
  /// defaults.
  ///
  /// When [preloadShaders] is `true` (the default), this kicks off
  /// compilation of every shader bundled with `nib_motion` (see
  /// [NibShaderLoader.preloadAll]) so the first `NibShimmer`/`NibDissolve`
  /// built doesn't pay that cost on its own first frame. Shader preload
  /// failures (e.g. the host app hasn't declared `nib_motion`'s shader
  /// assets) are swallowed — affected widgets fall back to painting their
  /// child without the shader effect.
  ///
  /// [defaultTransition] becomes the process-wide [globalDefaultTransition].
  /// When [respectReducedMotion] is `true` (the default), [init] also reads
  /// `WidgetsBinding.instance.platformDispatcher.accessibilityFeatures`'s
  /// reduce-motion preference once at startup and stores it in
  /// [reducedMotionEnabled]; when `false`, [reducedMotionEnabled] is left as
  /// `false` regardless of the platform setting.
  ///
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await NibMotionConfig.init();
  ///   runApp(MyApp());
  /// }
  /// ```
  static Future<void> init({
    bool preloadShaders = true,
    NibTransition defaultTransition = const NibTransition(),
    bool respectReducedMotion = true,
  }) async {
    _globalDefaultTransition = defaultTransition;
    _globalReducedMotion = respectReducedMotion &&
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
            .disableAnimations;

    if (preloadShaders) {
      await NibShaderLoader.preloadAll();
    }
  }
}

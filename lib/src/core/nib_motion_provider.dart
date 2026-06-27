import 'package:flutter/widgets.dart';

import 'nib_transition.dart';
import 'reduced_motion.dart';

/// Convenience root widget that configures [NibMotionConfig] and (in debug
/// builds) [NibMotionDebugger]-style diagnostics for every descendant
/// `NibMotion`.
///
/// This is a thin wrapper over [NibMotionConfig] for the common case of
/// configuring the whole app once near its root:
///
/// ```dart
/// void main() {
///   runApp(
///     NibMotionProvider(
///       defaultTransition: NibTransition.springGentle,
///       child: const MyApp(),
///     ),
///   );
/// }
/// ```
class NibMotionProvider extends StatelessWidget {
  /// Creates a `NibMotionProvider`.
  const NibMotionProvider({
    super.key,
    required this.child,
    this.defaultTransition = const NibTransition(),
    this.respectReducedMotion = true,
    this.debug = false,
  });

  /// The widget below this one in the tree.
  final Widget child;

  /// The transition used by `NibMotion` widgets that don't specify their own
  /// `NibMotion.transition`.
  final NibTransition defaultTransition;

  /// When `false`, descendant `NibMotion`s ignore the platform's
  /// `MediaQuery.disableAnimations` accessibility setting and always
  /// animate.
  final bool respectReducedMotion;

  /// Reserved for future debug-overlay wiring at the provider level. Compose
  /// `NibMotionDebugger` directly around `child` for now if you need it.
  final bool debug;

  /// Returns the nearest ancestor [NibMotionConfig], or `null` if there is
  /// none.
  static NibMotionConfig? of(BuildContext context) =>
      NibMotionConfig.maybeOf(context);

  @override
  Widget build(BuildContext context) {
    return NibMotionConfig(
      defaultTransition: defaultTransition,
      reducedMotion: respectReducedMotion ? null : false,
      child: child,
    );
  }
}

import 'package:flutter/widgets.dart';

import '../core/nib_anim.dart';
import '../core/nib_motion_widget.dart';
import '../core/nib_transition.dart';
import '../viewport/nib_in_view_config.dart';

/// Reveals [child] with an animation when it scrolls into the viewport.
///
/// `NibScrollReveal` is a thin convenience wrapper over
/// [NibMotion.whileInView] — it configures [NibMotion.initial],
/// [NibMotion.whileInView], and [NibMotion.viewport] for the common "fade
/// and slide up on reveal" pattern, without reimplementing any
/// viewport-intersection logic.
///
/// ```dart
/// NibScrollReveal(
///   child: const Text('Revealed on scroll'),
/// )
/// ```
///
/// By default [child] starts at [initial] (faded out, offset down by 32
/// logical pixels), animates to [animate] (`NibAnim.identity`, i.e. fully
/// visible at its natural position) once at least [amount] of its area is
/// visible, and — because [once] defaults to `true` — stays revealed even if
/// it's later scrolled back out of view.
class NibScrollReveal extends StatelessWidget {
  /// Creates a `NibScrollReveal`.
  const NibScrollReveal({
    super.key,
    required this.child,
    this.initial = const NibAnim(opacity: 0, y: 32),
    this.animate = NibAnim.identity,
    this.transition,
    this.once = true,
    this.amount = 0.2,
  });

  /// The widget to reveal.
  final Widget child;

  /// The animation values [child] starts at before it has entered the
  /// viewport. Defaults to faded out and offset 32 pixels down.
  final NibAnim initial;

  /// The animation values [child] transitions to once it enters the
  /// viewport. Defaults to [NibAnim.identity] (fully visible, no offset).
  final NibAnim animate;

  /// The transition used when revealing [child]. If `null`, falls back to
  /// `NibMotionConfig.defaultTransitionOf(context)` (see
  /// [NibMotion.transition]).
  final NibTransition? transition;

  /// If `true` (the default), [child] is revealed only the first time it
  /// enters the viewport and does not revert if scrolled back out. If
  /// `false`, [child] reverts to [initial] every time it leaves the
  /// viewport, replaying the reveal animation each time it re-enters.
  final bool once;

  /// The fraction of [child]'s area that must be visible for the reveal to
  /// trigger. See [NibInViewConfig.amount].
  final double amount;

  @override
  Widget build(BuildContext context) {
    return NibMotion(
      initial: initial,
      whileInView: animate,
      viewport: NibInViewConfig(amount: amount, once: once),
      transition: transition,
      child: child,
    );
  }
}

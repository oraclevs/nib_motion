import 'package:flutter/widgets.dart';

import '../core/nib_anim.dart';
import '../core/nib_motion_widget.dart';
import '../core/nib_transition.dart';
import 'nib_presence.dart';

/// Shows or hides a single [child] with an enter/exit animation, keeping it
/// mounted until the exit has finished.
///
/// The one-widget counterpart of [NibPresence]: set [visible] to `false` and
/// the child fades (or whatever [exit] says) out *before* it is removed;
/// set it back to `true` mid-exit and the removal is cancelled and the child
/// animates back in from where it was. While exiting, the child ignores
/// pointers and is excluded from semantics and focus. Reduced motion
/// (`NibMotionConfig`) removes it immediately.
///
/// ```dart
/// NibVisibility(
///   visible: showBanner,
///   initial: const NibAnim(opacity: 0, y: -12),
///   exit: const NibAnim(opacity: 0, y: -12),
///   transition: NibTransition.springSnappy,
///   exitDelay: const Duration(milliseconds: 100),
///   child: const Banner(),
/// )
/// ```
///
/// Layout: the child sits in a [Stack] with default alignment, like
/// [NibPresence]; wrap in an `Align`/`Center` to position it.
class NibVisibility extends StatefulWidget {
  /// Creates a visibility wrapper around [child].
  const NibVisibility({
    super.key,
    required this.visible,
    required this.child,
    this.initial = const NibAnim(opacity: 0),
    this.animate = const NibAnim(opacity: 1),
    this.exit = const NibAnim(opacity: 0),
    this.transition,
    this.exitTransition,
    this.enterDelay = Duration.zero,
    this.exitDelay = Duration.zero,
  });

  /// Whether the child should be shown.
  final bool visible;

  /// The widget to show and hide.
  final Widget child;

  /// Where the child starts when it appears. Defaults to transparent.
  final NibAnim initial;

  /// Where the child rests while visible. Defaults to fully opaque.
  final NibAnim animate;

  /// Where the child animates to before it is removed. Defaults to
  /// transparent.
  final NibAnim exit;

  /// The enter transition (and the exit transition when [exitTransition] is
  /// `null`). Falls back to the ambient `NibMotionConfig` default.
  final NibTransition? transition;

  /// The transition used when hiding. Falls back to [transition].
  final NibTransition? exitTransition;

  /// How long to wait before the enter animation starts.
  final Duration enterDelay;

  /// How long to wait before the exit animation starts.
  final Duration exitDelay;

  @override
  State<NibVisibility> createState() => _NibVisibilityState();
}

class _NibVisibilityState extends State<NibVisibility> {
  static const ValueKey<String> _key = ValueKey<String>('nib_visibility');

  @override
  Widget build(BuildContext context) {
    final base = widget.transition ?? const NibTransition();
    final exitBase = widget.exitTransition ?? base;
    return NibPresence(
      children: [
        if (widget.visible)
          NibMotion(
            key: _key,
            initial: widget.initial,
            animate: widget.animate,
            exit: widget.exit,
            transition: widget.enterDelay == Duration.zero
                ? base
                : base.copyWith(delay: widget.enterDelay),
            exitTransition: widget.exitDelay == Duration.zero
                ? exitBase
                : exitBase.copyWith(delay: widget.exitDelay),
            child: widget.child,
          ),
      ],
    );
  }
}

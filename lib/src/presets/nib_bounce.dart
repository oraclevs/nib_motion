import 'package:flutter/widgets.dart';

import '../core/nib_motion_widget.dart';
import '../core/nib_transition.dart';
import 'nib_anim_presets.dart';

/// Plays a "drop in from above and bounce" entrance animation on [child]
/// using [NibAnimPresets.bounceIn].
///
/// ```dart
/// NibBounce(
///   child: const Text('Welcome!'),
/// )
/// ```
class NibBounce extends StatelessWidget {
  /// Creates a `NibBounce`.
  const NibBounce(
      {super.key,
      required this.child,
      this.duration = const Duration(milliseconds: 800)});

  /// The widget to animate in.
  final Widget child;

  /// How long the bounce-in entrance takes to play out.
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return NibMotion(
      keyframes: NibAnimPresets.bounceIn,
      transition: NibTransition(duration: duration),
      child: child,
    );
  }
}

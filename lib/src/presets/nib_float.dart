import 'package:flutter/widgets.dart';

import '../core/nib_anim.dart';
import '../core/nib_motion_widget.dart';
import '../core/nib_transition.dart';

/// Gently floats [child] up and down forever, like it's drifting in zero
/// gravity.
///
/// ```dart
/// NibFloat(
///   child: const Icon(Icons.cloud),
/// )
/// ```
class NibFloat extends StatelessWidget {
  /// Creates a `NibFloat`.
  const NibFloat({
    super.key,
    required this.child,
    this.distance = 10,
    this.duration = const Duration(milliseconds: 1600),
  });

  /// The widget to float.
  final Widget child;

  /// How far, in logical pixels, [child] travels above its resting position
  /// at the peak of each cycle.
  final double distance;

  /// How long one direction of the float (down-to-up, or up-to-down) takes
  /// to play out.
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return NibMotion(
      initial: NibAnim(y: 0),
      animate: NibAnim(y: -distance),
      transition: NibTransition(duration: duration, curve: Curves.easeInOut),
      repeatAnimationInLoop: true,
      child: child,
    );
  }
}

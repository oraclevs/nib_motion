import 'package:flutter/widgets.dart';

import '../core/nib_motion_widget.dart';
import '../core/nib_transition.dart';
import 'nib_anim_presets.dart';

/// Plays a repeating "heartbeat" pulse animation on [child] using
/// [NibAnimPresets.pulse], looping forever via `NibMotion.repeatAnimationInLoop`.
///
/// ```dart
/// NibPulse(
///   child: const Icon(Icons.favorite),
/// )
/// ```
class NibPulse extends StatelessWidget {
  /// Creates a `NibPulse`.
  const NibPulse({super.key, required this.child, this.duration = const Duration(milliseconds: 900)});

  /// The widget to pulse.
  final Widget child;

  /// How long one pulse cycle (scale up, then back down) takes to play out.
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return NibMotion(
      keyframes: NibAnimPresets.pulse,
      transition: NibTransition(duration: duration),
      repeatAnimationInLoop: true,
      child: child,
    );
  }
}

import 'package:flutter/widgets.dart';

import '../core/nib_motion_widget.dart';
import '../core/nib_transition.dart';
import 'nib_anim_presets.dart';

/// Plays a rubber-band overshoot-and-settle animation on [child] once, using
/// [NibAnimPresets.rubberBand].
///
/// ```dart
/// NibRubberBand(
///   child: const Text('Stretchy!'),
/// )
/// ```
class NibRubberBand extends StatelessWidget {
  /// Creates a `NibRubberBand`.
  const NibRubberBand({super.key, required this.child, this.duration = const Duration(milliseconds: 1000)});

  /// The widget to animate.
  final Widget child;

  /// How long the overshoot-and-settle animation takes to play out.
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return NibMotion(
      keyframes: NibAnimPresets.rubberBand,
      transition: NibTransition(duration: duration),
      child: child,
    );
  }
}

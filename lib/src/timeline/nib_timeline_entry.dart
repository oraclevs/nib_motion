import 'package:flutter/foundation.dart';

import '../core/nib_anim.dart';
import '../core/nib_motion_controller.dart';
import '../core/nib_transition.dart';

/// A single scheduled animation in a [NibTimeline].
///
/// Describes which [controller] to drive, what [target] to animate it to,
/// how (via [transition]), and when (via [at] — an offset from the
/// timeline's start).
@immutable
class NibTimelineEntry {
  /// Creates a timeline entry. [controller] is driven toward [target] (via
  /// [NibMotionController.start]) once [at] has elapsed since the owning
  /// [NibTimeline] started playing.
  const NibTimelineEntry({required this.controller, required this.target, required this.at, this.transition});

  /// The controller to drive when this entry fires.
  final NibMotionController controller;

  /// The animation values [controller] should animate toward.
  final NibAnim target;

  /// How long after the timeline starts playing this entry fires.
  final Duration at;

  /// The transition to use for this entry's animation. `null` uses each
  /// attached `NibMotion`'s default transition.
  final NibTransition? transition;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NibTimelineEntry &&
        other.controller == controller &&
        other.target == target &&
        other.at == at &&
        other.transition == transition;
  }

  @override
  int get hashCode => Object.hash(controller, target, at, transition);
}

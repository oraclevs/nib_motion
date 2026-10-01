import 'package:flutter/foundation.dart';

import '../core/nib_anim.dart';
import '../core/nib_motion_controller.dart';
import '../core/nib_transition.dart';

/// How a [NibTimelineEntry] is positioned on its timeline.
enum NibTimelineAnchor {
  /// At the absolute [NibTimelineEntry.at] offset.
  absolute,

  /// When the referenced entry (or the previous one) has *finished*, plus
  /// [NibTimelineEntry.offset].
  afterEnd,

  /// When the referenced entry *starts*, plus [NibTimelineEntry.offset].
  withStart,
}

/// A single scheduled animation in a [NibTimeline].
///
/// Describes which [controller] to drive, what [target] to animate it to,
/// how (via [transition]), and when — either at an absolute offset ([at]) or
/// relative to another entry ([NibTimelineEntry.after],
/// [NibTimelineEntry.withStart]).
///
/// Relative entries are resolved to absolute times when the [NibTimeline] is
/// constructed. An entry's *end* is its start plus its transition's delay and
/// duration (for springs, the time the spring takes to settle).
@immutable
class NibTimelineEntry {
  /// Creates a timeline entry. [controller] is driven toward [target] (via
  /// [NibMotionController.start]) once [at] has elapsed since the owning
  /// [NibTimeline] started playing.
  ///
  /// [label] names the entry so others can anchor to it; [from] is the state
  /// the entry animates *from*, which lets [NibTimeline.seek] scrub it
  /// smoothly (without it, scrubbing steps the entry at its end).
  const NibTimelineEntry({
    required this.controller,
    required this.target,
    required this.at,
    this.transition,
    this.label,
    this.from,
  })  : anchor = NibTimelineAnchor.absolute,
        reference = null,
        offset = Duration.zero;

  /// An entry that starts when [reference] (a [label]) has finished, or when
  /// the previous entry in the list has finished if [reference] is `null`,
  /// plus [offset] (may be negative to overlap).
  const NibTimelineEntry.after({
    required this.controller,
    required this.target,
    this.reference,
    this.offset = Duration.zero,
    this.transition,
    this.label,
    this.from,
  })  : anchor = NibTimelineAnchor.afterEnd,
        at = Duration.zero;

  /// An entry that starts together with the entry labelled [reference], plus
  /// [offset].
  const NibTimelineEntry.withStart({
    required this.controller,
    required this.target,
    required String this.reference,
    this.offset = Duration.zero,
    this.transition,
    this.label,
    this.from,
  })  : anchor = NibTimelineAnchor.withStart,
        at = Duration.zero;

  /// The controller to drive.
  final NibMotionController controller;

  /// The state to animate toward.
  final NibAnim target;

  /// Absolute start offset from the timeline's start. For relative entries
  /// this is `Duration.zero` until the timeline resolves them.
  final Duration at;

  /// How to animate; the controller's widget default if `null`.
  final NibTransition? transition;

  /// Optional name other entries can anchor to.
  final String? label;

  /// The state this entry animates from, used only for scrubbing
  /// (`NibTimeline.seek`).
  ///
  /// Optional: when omitted it is derived per property from the latest earlier
  /// entry on the same controller that animates that property, else from the
  /// widget's own `initial` state. Pass it only to override that.
  final NibAnim? from;

  /// How [at] is determined.
  final NibTimelineAnchor anchor;

  /// The label this entry is anchored to (`null` = previous entry for
  /// [NibTimelineAnchor.afterEnd]).
  final String? reference;

  /// Offset added to the anchor point.
  final Duration offset;

  /// Returns a copy with absolute start [at].
  NibTimelineEntry resolvedAt(Duration at) => NibTimelineEntry(
        controller: controller,
        target: target,
        at: at,
        transition: transition,
        label: label,
        from: from,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NibTimelineEntry &&
        other.controller == controller &&
        other.target == target &&
        other.at == at &&
        other.transition == transition &&
        other.label == label &&
        other.from == from &&
        other.anchor == anchor &&
        other.reference == reference &&
        other.offset == offset;
  }

  @override
  int get hashCode => Object.hash(controller, target, at, transition, label,
      from, anchor, reference, offset);
}

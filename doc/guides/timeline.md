---
{
  "id": "timeline",
  "evidence": "MotionNib/motion/lib/src/timeline/nib_timeline.dart; MotionNib/motion/lib/src/timeline/nib_timeline_entry.dart; MotionNib/motion/lib/src/timeline/nib_animation_sequence.dart"
}
---

# Timeline

Schedule several controllers on one clock and scrub known states.

<!-- section: time-model -->
## Understand the shared clock

Construct the timeline after the controllers exist and the participating NibMotion widgets can attach. An absolute at is measured from each play() call, not from app startup. A relative after entry starts when its reference finishes, including transition delay and modeled spring settling; withStart aligns with the reference start. Relative references resolve in input order, so a label must already have been declared when it is used. The resolved entries are then sorted by start time.

The example schedules title at zero and subtitle at 150 ms. Each entry invokes its controller independently, so the two can overlap. Give each controller to the corresponding mounted NibMotion. Store both controllers and the timeline in the owning State and dispose them when that State leaves. Avoid constructing a fresh timeline inside build, where a rebuild would discard the old schedule while its commands are still active.

<!-- section: entries -->
## Schedule entries across elements

NibTimeline takes NibTimelineEntry values and sorts their resolved start offsets. Each entry drives a NibMotionController toward a NibAnim target. at is a Duration from play start; NibTimelineEntry.after can follow the previous entry or a named label, while withStart can align to a named start with an offset.

Relative references must point to entries already defined in the input list. The constructor rejects duplicate labels and unknown or later references. For a single controller’s sequential changes, NibAnimationSequence is the simpler fluent API.

<!-- api -->
| Name | Type | Default | Description |
| --- | --- | --- | --- |
| controller | NibMotionController | required | The element driven by this entry. |
| target | NibAnim | required | State to reach when the entry runs. |
| at | Duration | required | Absolute offset from timeline play start. |
| from | NibAnim? | null | Optional start state for precise scrubbing. |

```dart
// In State, after creating both controllers.
final timeline = NibTimeline([
  NibTimelineEntry(
    controller: titleController,
    target: const NibAnim(opacity: 1),
    at: Duration.zero,
  ),
  NibTimelineEntry(
    controller: subtitleController,
    target: const NibAnim(opacity: 1),
    at: const Duration(milliseconds: 150),
  ),
]);
```

<!-- section: scrub -->
## Scrub with explicit starts

seek clamps a fraction into zero through one, cancels pending play timers, and applies each entry’s state at that point. An explicit from gives a known start state. Without it, the implementation derives the start of each targeted property from an earlier entry on the same controller or from the attached widget’s initial state. An entry can step only where no usable start can be derived. NibTimeline.progress records the last seek position and is not advanced by play.

Pause and stop cancel pending timers but leave animations that already started running. If pending entries are canceled, the Future from that play call can remain incomplete; do not await it as a cancellation signal. Dispose the timeline and each controller owned by the host. A playing spring can take longer to report completion than it appears to settle.

<!-- section: scrub-exercise -->
## Build a seekable introduction

Add from: const NibAnim(opacity: 0) to each example entry and attach a Slider that calls timeline.seek(value). Move it to 0, 0.5, and 1. The slider’s fraction maps to the timeline’s total duration, which is the latest entry end, not just the last start. At 0.5, one element may have finished while another is still moving. Compare that with play(), which dispatches actual timed animations and does not update timeline.progress on each frame.

Then add a third entry using NibTimelineEntry.after(reference: a label) and a negative offset so it overlaps the previous end. Verify that the label appears earlier in the input list; duplicate or forward labels throw at construction. Exercise a second play during the first one: pending timers from the older run are canceled before all entries are rescheduled. If the screen can close during this work, avoid treating an incomplete play Future as a signal to update disposed State.

<!-- section: use -->
## Keep the sequence proportional

Use separate controllers when independent elements need different start times. Keep the primary action available even if the sequence is skipped by reduced motion. Test replay, interruption, and route disposal before using a timeline for navigation or form completion.

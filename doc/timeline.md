# Timelines: relative timing, scrubbing, loop modes

## Relative entries

```dart
final t = NibTimeline([
  NibTimelineEntry(controller: title, target: shown, at: Duration.zero,
      label: 'title', transition: NibSpring.smooth.transition),
  NibTimelineEntry.after(controller: subtitle, target: shown),              // after the previous entry ends
  NibTimelineEntry.after(controller: cta, target: shown, reference: 'title',
      offset: const Duration(milliseconds: -80)),                            // overlap 80 ms
  NibTimelineEntry.withStart(controller: icon, target: shown, reference: 'title'),
]);
```

* An entry's *end* is its start + transition delay + duration; for springs, the
  time the spring takes to settle.
* Relative entries resolve to absolute times when the timeline is built, in list
  order. Referring to an unknown or later label, a duplicate label, or `after`
  with no previous entry throws `ArgumentError`. Negative results clamp to 0.
* Absolute-only timelines behave exactly as before (same entry objects).
* `timeline.entries` holds resolved entries; `timeline.duration` is the total.

## Scrubbing

`timeline.seek(0..1)` sets every entry to the state it has at that fraction of
`duration`, and updates `timeline.progress` (a `MotionValue`).

* An entry with `from:` interpolates `from → target` (its curve, or the spring
  curve) and returns to `from` before it starts.
* An entry **without** `from` cannot be interpolated (its start state is unknown
  to the timeline): it steps to its target when its end is reached.
* `seek` cancels pending `play` timers; `play` does not drive `progress`.
* `NibTimelineScrubber(timeline:)` is a debug slider over `seek`.

## Contract kept

`play()` futures still never complete after `stop()`/`pause()`.

## Loop modes for `NibAnimationSequence`

`sequence.loop([times], [mode])`:

| Mode | Behaviour |
|---|---|
| `NibLoopMode.restart` | replay from the first step (default, unchanged) |
| `NibLoopMode.pingPong` | odd passes replay in reverse, animating back through earlier targets to the first one; `wait`/`call` run both ways |
| `NibLoopMode.seamless` | like restart, but skips a first animate step that already equals where the last one ended |

`NibMotion.repeatAnimationInLoop` (widget-level keyframe loop) is unchanged and
remains ping-pong only.

## Scrubbing without duplicating `from:`

`NibTimelineEntry.from` is optional. When omitted, `NibTimeline.seek` derives
each property's start per entry: the target of the latest earlier entry on the
same controller that animates that property, otherwise the widget's own
`initial` state (`NibMotionController.initialAnim`). Pass `from` only to
override. Entries that have not started hold their start state only for
properties no earlier entry on the same controller owns.

`NibTimelineScrubber` uses widgets-layer primitives only (no Material): a
`GestureDetector` track painted with `CustomPaint`; colours are constructor
parameters.

## Progress values in every scroll direction

`NibViewportProgress` publishes in the same frame as the scroll (extrapolating
from the last layout measurement, then correcting after layout), and runs
`0 → 1` in the *scroll* direction for vertical, horizontal, `reverse: true` and
RTL lists, including children of an inner list inside an outer scroll view.
`visibleFraction` counts only what is inside every enclosing viewport. A child
that a lazy list has not built yet does not exist to measure.
Sliver header `progress` values may be listened to with `ValueListenableBuilder`:
writes during layout notify right after the frame (at most one frame behind);
paint reads see the new value immediately.

# Debug tools

All widgets-only (no Material) and safe to drop into an overlay.

## `NibSpringTuner`

Tune a spring by feel. Sliders (duration/bounce or mass/stiffness/damping), a
live preview box driven by a real `SpringSolver`, the step-response curve
(`NibSpringCurve`) and a copyable snippet.

```dart
if (kDebugMode) NibSpringTuner(onChanged: (spring) => debugPrint('$spring'))
```

The preview honours `NibMotionConfig` reduced motion (it jumps). Copy uses the
platform clipboard.

## `NibHotReloadReplay`

Replays all descendant `NibMotion` entrances on hot reload, so edits to
`initial`/`animate`/`transition` show immediately.

```dart
NibHotReloadReplay(child: MyScreen())
```

It listens to `State.reassemble` and fires the ambient
`NibMotionReplaySignal`; it does nothing outside debug mode.

## Sliver progress

`NibSliverHeaderDelegate` and `NibSliverProgress` expose a sliver's collapse
progress as a `MotionValue` (no rebuild per scroll frame); see their API docs.

## Timeline drag scrubbing

`NibTimelineDragScrubber` turns a drag (axis-, direction- and RTL-aware) into
`NibTimeline.seek`. Use it with `NibTimelineScrubber` (slider) for debugging.

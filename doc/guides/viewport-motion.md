---
{
  "id": "viewport-motion",
  "evidence": "MotionNib/motion/lib/src/viewport/nib_in_view_config.dart; MotionNib/motion/lib/src/viewport/nib_viewport_progress.dart; MotionNib/motion/lib/src/core/nib_motion_replay_scope.dart"
}
---

# Viewport motion and replay

Trigger on entry, track progress through a viewport, or replay on purpose.

<!-- section: entry -->
## Trigger a temporary in-view state

NibMotion.whileInView applies a NibAnim while the widget meets its viewport test. NibInViewConfig.amount defaults to 0.5, so about half the widget must be visible. once defaults to false: after the widget leaves, it can return to animate or initial and trigger again. A positive margin expands the tested viewport; a negative margin shrinks it. The value is a fraction of the widget area, not pixels.

The source widget still needs a useful resting state. For a one-time entrance, set once true so leaving the viewport does not hide content again. A NibScrollReveal wrapper has different defaults, amount 0.2 and once true, and is the short form when no custom in-view state is needed.

```dart
NibMotion(
  initial: const NibAnim(opacity: 0, y: 24),
  whileInView: NibAnim.identity,
  viewport: const NibInViewConfig(amount: 0.5, once: true),
  child: const Text('Visible when reached'),
)
```

<!-- api -->
| Name | Type | Default | Description |
| --- | --- | --- | --- |
| amount | double | 0.5 | Visible fraction needed for whileInView. |
| once | bool | false | Keep the in-view state after first entry when true. |
| margin | EdgeInsets | EdgeInsets.zero | Expand or shrink the tested viewport bounds. |

<!-- section: continuous -->
## Use continuous progress for a parallax-style response

NibViewportProgress reports two MotionValues through an owned NibViewportProgressController. progress is zero when the leading edge is about to enter and one after the trailing edge has left; visibleFraction measures how much area is currently inside. Wrap the measured child with NibViewportProgress, derive a paint value with mapRange, and pass that value to NibMotionValues.

Create the controller and derived values once in State and dispose derived values before the controller. The widget observes all ancestor Scrollables and uses the nearest viewport for measurement. On reversed scroll axes, progress is mirrored relative to the usual forward reading. Test a nested scroll view rather than assuming the outer page alone decides visibility.

```dart
// State fields:
final viewport = NibViewportProgressController();
late final opacity = viewport.progress.mapRange(
  [0, 0.3, 0.7, 1], [0, 1, 1, 0],
);

// In build:
NibViewportProgress(
  controller: viewport,
  child: NibMotion(
    motionValues: NibMotionValues(opacity: opacity),
    child: const Text('Through the window'),
  ),
)

// In State.dispose: opacity.dispose(); viewport.dispose();
```

<!-- section: replay -->
## Replay an entrance deliberately

A viewport trigger depends on visibility. NibMotionReplaySignal is different: its replay call asks listening descendants under NibMotionReplayScope to run their entrance again. The signal records an optional delay and notifies immediately; each listening NibMotion applies that delay before playback. NibScreenStack can use this mechanism when a tab transition asks to retrigger page animations.

Create one signal in State, put the scope above the intended descendants, and call replay from a clear event such as a Replay button. Dispose the signal with the State. Avoid a replay on every build; that would keep resetting the same content and may interrupt focus or reading.

```dart
final replaySignal = NibMotionReplaySignal(); // State field

// In build:
NibMotionReplayScope(
  signal: replaySignal,
  child: NibMotion(
    initial: const NibAnim(opacity: 0),
    animate: NibAnim.identity,
    child: const Text('Ready again'),
  ),
)

// On a user action: replaySignal.replay();
// In State.dispose: replaySignal.dispose();
```

<!-- section: viewport-checks -->
## Check the scroller that actually moves the child

Scroll an inner list while its outer page stays still, then move the outer page. Observe entry, exit, and progress separately. A child may be outside either viewport, so a screen-only check would give the wrong answer. Keep the final content available when reduced motion jumps to the endpoint. Continue to Scroll motion for ScrollController mapping and reveal behavior.

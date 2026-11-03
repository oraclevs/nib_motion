---
{
  "id": "transitions",
  "evidence": "MotionNib/motion/lib/src/core/nib_transition.dart; MotionNib/motion/lib/src/core/nib_motion_widget.dart"
}
---

# Transitions

Choose a timed tween or a spring, then set the return behavior.

<!-- section: compare-two-paths -->
## Compare the same target side by side

The live preview changes two tiles between the same left and right x offsets. The first uses NibTransition.springSnappy. The second uses a 450 ms easeInOutCubic tween. Tap Move right, then tap Move left before either tile finishes. Both receive the same new destination, but one is physically retargeted while the other follows a fixed-duration easing curve.

A timed transition promises a duration for each trip; it does not promise that repeated taps will feel like continuous velocity. A spring has no fixed finish time, but it can preserve velocity at a new target. Choose based on the interaction, not on which tile is visually busier.

<!-- section: place-a-transition -->
## Set timing on the NibMotion that owns the target

In a StatefulWidget, keep a boolean target in State and pass NibAnim(x: right ? 22 : -22) to NibMotion.animate. Pass a NibTransition to that same widget. Change the boolean from a button with setState; the button does not need to start an AnimationController. Use another NibMotion with the same target and a different transition when comparing behavior, as the preview does.

duration is a Duration, such as 450 milliseconds. curve is a Flutter Curve. delay is another Duration and applies before either tween or spring starts. A spring description selects the spring path even if duration and curve are also present in the object; do not treat those fields as spring limits.

<!-- section: timed -->
## Use fixed time when timing matters

NibTransition without a spring is a tween: duration defaults to 300 ms, curve to easeInOut, and delay to zero. Choose an explicit duration for a deliberately timed entrance or a sequence with a known beat. Negative durations and delays are invalid; animation entry points validate them in debug builds and clamp them in release builds.

```dart
const NibTransition(
  duration: Duration(milliseconds: 450),
  curve: Curves.easeOutCubic,
)
```

<!-- api -->
| Name | Type | Default | Description |
| --- | --- | --- | --- |
| duration | Duration | 300 ms | Total tween duration; ignored by a spring driver. |
| curve | Curve | easeInOut | Tween easing; ignored by a spring driver. |
| delay | Duration | zero | Wait before starting either transition type. |
| spring | NibSpringDescription? | null | Selects spring physics when supplied. |

<!-- section: spring -->
## Use spring physics for retargeting

A non-null spring changes the transition type to spring and makes duration and curve irrelevant to the physical driver. NibTransition.springGentle, springSnappy, and springWobbly are presets. NibTransition.springWith converts a perceptual duration and bounce into a spring description.

delay still postpones the start. A controller Future may resolve after the motion looks settled because the simulation waits for numerical tolerance. Do not disable input until that Future ends unless the action truly depends on completion.

<!-- section: return -->
## Control the way back

NibMotion.reverseTransition applies when a temporary tap, hover, focus, drag, or in-view state ends. exitTransition applies when NibPresence removes a child. A parent transition’s delayChildren and staggerChildren affect descendants that inherit a named variant; they do not create a global delay for every arbitrary child.

<!-- section: return-and-exit -->
## Give temporary and exit states their own return

NibMotion.reverseTransition lets a press, hover, focus, drag, or in-view state return differently from how it entered. For example, a button can compress with a slower response and release quickly. NibMotion.exitTransition is used when an ancestor NibPresence removes the child. These are separate from the main animate transition.

delayChildren and staggerChildren on a parent transition schedule descendants inheriting a named variant. They are not a general timer applied to all descendants. Use the Variants and stagger lesson when you need that propagation; use Timeline when independent controllers need their own start offsets.

<!-- section: transition-errors -->
## When timing seems ignored

If changing duration does nothing, check whether spring is non-null. If a return feels wrong, check reverseTransition rather than only the main transition. If an exiting child ignores exit timing, verify it has an exit NibAnim, a stable key, and an ancestor NibPresence.

Negative durations and delays are invalid inputs. A debug build reports them; release code clamps them to zero. Supply valid positive values rather than depending on that fallback. Test with reduced motion too: the endpoint should remain clear when neither timing path runs.

---
{
  "id": "presets",
  "evidence": "MotionNib/motion/lib/src/presets/nib_anim_presets.dart; MotionNib/motion/lib/src/presets/nib_shake.dart; MotionNib/motion/lib/src/presets/nib_flip.dart"
}
---

# Presets and ready-made motion

Choose an entrance, a repeating effect, or an action-triggered effect.

<!-- section: choose-the-shape -->
## Choose a state, a sequence, or a widget

NibAnimPresets has two kinds of values. fadeUp, fadeDown, fadeLeft, fadeRight, zoomIn, and zoomOut are single NibAnim starting states. Give one to NibMotion.initial and supply a resting animate target. shake, bounceIn, pulse, rubberBand, and wiggle are lists of NibKeyframe values. Give a list to NibMotion.keyframes when its whole sequence is the effect you want.

The named widgets package some of these patterns with their timing and lifecycle. Start with one NibBounce for an entrance or NibRubberBand for a one-time emphasis. Keep a stable key so an unrelated parent rebuild does not restart an entrance. Copying the keyframe list is useful when the preset timing or intermediate poses need to change.

<!-- api -->
| Name | Type | Default | Description |
| --- | --- | --- | --- |
| fadeUp | NibAnim | opacity 0, y 24 | A starting pose for an entrance. |
| bounceIn | List<NibKeyframe> | six stages | A timed drop and bounce sequence. |
| NibBounce.duration | Duration | 800 ms | Time for the one-time entrance. |

```dart
NibMotion(
  initial: NibAnimPresets.fadeUp,
  animate: NibAnim.identity,
  child: const Text('Ready'),
)

const NibBounce(child: Text('Arrived'))
```

<!-- section: repeat -->
## Reserve loops for ambient motion

NibFloat moves its child vertically by distance (10 logical pixels by default) on a repeating 1600 ms ease-in-out path. NibPulse repeats a small scale heartbeat over 900 ms. Neither is a substitute for a persistent status label. Put a loop around decoration or a small cue, and confirm the same screen communicates its state when reduced motion removes the travel.

A longer duration slows the cycle; it does not change the distance of NibFloat. Keep float distance small enough that the painted child does not cover adjacent controls. A loop can be cheap at the widget level and still incur paint or raster work, so measure a screen that contains several repeating elements before adding them to a scrolling list.

```dart
const NibFloat(
  distance: 8,
  duration: Duration(milliseconds: 1800),
  child: Icon(Icons.cloud),
)

const NibPulse(child: Icon(Icons.favorite))
```

<!-- section: trigger-shake -->
## Trigger a shake when validation fails

NibShake is deliberately idle until NibShakeController.shake runs. Create a controller in the State that owns the form, pass it to NibShake, and call shake only after a failed validation result. If you pass your own controller, dispose it when that State leaves; an internally created controller is owned by NibShake. The default shake duration is 600 ms.

Keep the validation message visible and connected to the field. The shake is feedback, not an error explanation. An action can fail twice quickly, so test repeated calls and make sure the field still has a usable focus and hit target while it moves.

```dart
final shake = NibShakeController(); // State field

// In build:
NibShake(controller: shake, child: const Text('Check this field'))

// On failed validation:
shake.shake();

// In State.dispose:
shake.dispose();
```

<!-- section: flip-and-stretch -->
## Let application state choose the face

NibFlip takes front and back widgets and an isFlipped boolean. Change that boolean from State; the default 600 ms flip rotates on the horizontal axis, and flipAxis can choose the vertical axis. Both faces should make sense at the end of the transition, including when reduced motion is active. A button outside the flip is a reliable way for touch and keyboard users to request the change.

NibRubberBand runs its nonuniform scale sequence once over 1000 ms by default. Use it for a bounded emphasis rather than an ongoing status. The preset values are x/y scale factors, not a layout resize: neighbors keep their own slots. For an actual layout change, use the layout guide.

```dart
NibFlip(
  isFlipped: showAnswer, // bool in State
  front: const Text('Question'),
  back: const Text('Answer'),
)

const NibRubberBand(child: Text('Saved'))
```

<!-- section: verify-presets -->
## Check the endpoint before the effect

Run each effect with reduced motion, then restore travel and interrupt it with navigation or disposal. The endpoint, label, and focus order should still be correct. A repeated visual effect can draw attention away from the task, so use a trigger only when it explains a real event. Continue to Keyframes to edit a preset sequence, or Springs to tune physical retargeting.

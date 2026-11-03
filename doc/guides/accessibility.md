---
{
  "id": "accessibility",
  "evidence": "MotionNib/motion/lib/src/core/reduced_motion.dart; MotionNib/motion/lib/src/core/nib_motion_widget.dart; MotionNib/motion/lib/src/presence/nib_presence.dart"
}
---

# Accessibility

Keep the state change clear when motion is reduced or input differs.

<!-- section: design-the-endpoint -->
## Design the outcome before the travel

Decide what the UI means when the motion finishes. A completed task should have a label, icon, or state that remains visible without watching the animation. In the live example, Complete changes the tile to a checkmark and turns the button into Reset. The horizontal travel adds expression; the checkmark and button label carry the outcome.

If a gesture moves an object to indicate acceptance, provide another path to accept it and a persistent result. A hover-only clue will not reach touch or keyboard users. Motion should reinforce a state change, not be the sole record that it happened.

<!-- section: reduced -->
## Apply the endpoint immediately

NibMotionConfig resolves reduced motion from an explicit test override, then its inherited reducedMotion value, then MediaQuery.disableAnimations. When reduction is active, NibMotion sets the target immediately instead of running intermediate frames. The result must still be legible without seeing the path.

The live example shows a checkmark and Reset action after Complete. Toggle its local switch and repeat; an active system preference keeps reduction on. NibMotionProvider can set an application default transition and whether to respect reduced motion.

<!-- section: configure-policy -->
## Read the motion preference correctly

NibMotionConfig checks an explicit global override first, an inherited reducedMotion value second, and MediaQuery.disableAnimations last. The global override is intended for tests. A host can wrap a subtree in NibMotionConfig(reducedMotion: true, child: ...) when it has a policy, or allow the system setting to flow through when reducedMotion is null.

The live switch uses the system preference as a floor: if the system requests reduced motion, its local toggle cannot turn travel back on. When reduction is true, NibMotion sets the target immediately. This does not remove the semantic result or disable the action.

```dart
NibMotionConfig(
  reducedMotion: MediaQuery.disableAnimationsOf(context),
  child: NibMotion(
    animate: NibAnim(x: complete ? 46 : -46),
    child: const Icon(Icons.check),
  ),
)
```

<!-- section: input -->
## Keep an equivalent action

A drag-only card has no obvious keyboard path. Pair the gesture with a button or another focusable control that reaches the same state. Hover feedback should add clarity without carrying essential information.

During a NibPresence exit, the departing child is excluded from focus and semantics. Test where focus moves after removal and whether a screen reader announces the new state in the host screen.

<!-- section: timing -->
## Do not gate the task on animation

Startup warm-up can delay an entrance briefly and NibMotionGate can hold it until a splash screen is removed. These affect the visual path; the task should remain understandable at the final state. Physical screen-reader checks still belong to release validation.

<!-- section: test-the-task -->
## Test the whole path with and without travel

First use Complete and Reset with motion enabled. Confirm the button remains operable while the tile moves. Then turn on reduced motion and repeat. The tile should reach each endpoint immediately and the labels should still explain what happened. Move keyboard focus through the controls and check that the visible focus indicator is not lost under a transform.

During a presence exit, the departing child is excluded from pointer, focus, and semantics. That avoids a stale action, but the host still has to decide where focus goes next and how a screen reader hears the updated collection. A widget test can inspect semantics; a physical screen-reader run remains a separate release check.

<!-- section: access-mistakes -->
## Avoid timing as a requirement

Do not require a user to wait for an entrance before they can understand a page. The default entrance warm-up lasts up to 400 ms near app start, and a NibMotionGate may hold entrances under a preserved splash screen. The destination and action must make sense if travel is skipped entirely.

If an animation appears still in testing, check the reduced-motion preference before changing durations. If it appears to run under a system preference, inspect whether an ancestor NibMotionConfig set reducedMotion to false. Continue to Gestures for equivalent input paths and Presence for focus behavior while items leave.

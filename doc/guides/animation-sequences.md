---
{
  "id": "animation-sequences",
  "evidence": "MotionNib/motion/lib/src/timeline/nib_animation_sequence.dart; MotionNib/motion/lib/src/core/nib_motion_controller.dart"
}
---

# Animation sequences

Queue targets, waits, callbacks, and a deliberate repeat mode.

<!-- section: single-controller -->
## Keep the sequence beside its controller

NibAnimationSequence records steps for one NibMotionController. Create the controller and sequence in the State that owns the widget, attach the controller to NibMotion, then add animate targets. animate starts the controller toward a NibAnim and waits for that step to finish; wait adds a Duration pause; call runs a synchronous callback at that point. play executes the recorded steps in order.

Each animate step can take its own NibTransition. If omitted, the attached NibMotion supplies its default. The sequence does not create or dispose the controller. On route disposal, stop and dispose the sequence, then dispose the controller. A controller may be attached to several widgets, but this builder is easiest to reason about when one visible object owns the story.

```dart
final controller = NibMotionController(); // State field
late final sequence = NibAnimationSequence(controller)
  .animate(const NibAnim(x: -40))
  .wait(const Duration(milliseconds: 100))
  .animate(
    const NibAnim(x: 40),
    transition: NibTransition.springGentle,
  );

// In build: NibMotion(controller: controller, child: const Icon(Icons.circle))
// On Play: await sequence.play();
// In State.dispose: sequence.dispose(); controller.dispose();
```

<!-- api -->
| Name | Type | Default | Description |
| --- | --- | --- | --- |
| animate | NibAnim + NibTransition? | transition null | Queue one controller target and wait for completion. |
| wait | Duration | required | Pause before the next step. |
| call | VoidCallback | required | Run synchronous work at this point. |
| loop | count + NibLoopMode | no loop | Repeat finite times or until stopped. |

<!-- section: repeat-modes -->
## Choose what repeat means

Without loop, play runs once. loop(3) runs the recorded steps three times in restart mode. NibLoopMode.pingPong alternates forward passes with reverse passes through earlier animate targets; wait and call steps run in both directions. NibLoopMode.seamless is like restart except it skips the first animate step on later passes when its target exactly equals the final animate target. That removes a dead step at the seam, not an arbitrary pause.

Calling loop with no count repeats forever. The Future returned by that play never completes, even after stop, so do not await it in an action that must finish. Keep a visible Stop control or stop on disposal. Test a finite two-target sequence first, then add a loop so the endpoint behavior is clear.

```dart
final sequence = NibAnimationSequence(controller)
  .animate(const NibAnim(x: -40))
  .animate(const NibAnim(x: 40))
  .loop(3, NibLoopMode.pingPong);

await sequence.play(); // Finite: completes after three passes.
```

<!-- section: cancel -->
## Stop between steps

stop prevents later steps from running and stops the controller. An already started wait or animation may finish its current run before the sequence exits, so do not use stop as a promise that a callback already entered will be undone. A second play call during an active run follows that same run instead of starting two concurrent copies.

If a later screen replaces the owner while the sequence is waiting, guard application callbacks with mounted and dispose the sequence with the State. Use the Timeline guide for several independently scheduled controllers. Use Keyframes when one widget needs intermediate poses along one timed track.

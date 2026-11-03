---
{
  "id": "first-animation",
  "evidence": "MotionNib/motion/lib/src/core/nib_motion_widget.dart"
}
---

# Your first animation

Make saving an idea feel responsive with one state value and an interruptible spring.

<!-- section: place-the-state -->
## Let application state own the bookmark

Keep bool saved = false in the owning State. The button changes it with setState. The same boolean selects the icon, confirmation text and motion target.

Keep the Save idea button outside the animated wrapper, giving pointer and keyboard users a stable action target.

Try the same Save and Undo sequence with a keyboard before tuning the spring.

<!-- section: source -->
## Describe the two states

Saving lifts, enlarges and tilts the bookmark. Undo restores all three properties. The NibMotion wrapper stays mounted, so repeated actions retarget its current motion.

```dart
// Keep this field in State: bool saved = false;
NibMotion(
  animate: NibAnim(
    y: saved ? -10 : 0,
    scale: saved ? 1.15 : 1,
    rotate: saved ? -.035 : 0,
  ),
  transition: NibTransition.springGentle,
  child: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
)
// In a button callback: setState(() => saved = !saved);
```

<!-- section: read-properties -->
## Read numbers in their units

y is a logical pixel offset: -10 lifts the bookmark ten pixels. scale: 1.15 enlarges it by fifteen percent. rotate is measured in turns; -.035 is a small counterclockwise tilt.

The icon change is ordinary Flutter state. NibMotion animates the position, scale and rotation around it.

<!-- section: properties -->
## Give every changing property an endpoint

Both branches explicitly set y, scale and rotate. A nullable field omitted from a target does not request a reset. Use NibAnim.identity when you want explicit neutral transform and opacity values.

The spring controls settling. A duration does not control a transition that has a spring configured.

<!-- section: verify -->
## Undo before it settles

Press Save idea, then Undo save while the bookmark is moving. Try several quick alternations. The text should always match the final saved state and the icon should settle at the corresponding target.

Enable reduced motion. The same final bookmark and confirmation must remain visible without travel.

<!-- section: change-one-property -->
## Tune the response

Try scale: 1.05 for a quieter response, or y: -18 for more lift. Change one value at a time and repeat the quick Save and Undo test.

Keep a stable key. A new key would remount the animation instead of letting the existing spring respond to the new state.

<!-- section: first-errors -->
## Check state before timing

If the icon changes but does not move, confirm the two targets differ and reduced motion is off. If the label is wrong, inspect the host state update before changing animation parameters.

Next, use Springs for physical tuning, Transitions for fixed timing, or Layout animations when neighboring widgets should reflow.

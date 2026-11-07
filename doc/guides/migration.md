---
{
  "id": "migration",
  "evidence": "MotionNib/motion/doc/migration.md; MotionNib/motion/doc/interruption.md; MotionNib/motion/lib/src/core/nib_motion_widget.dart"
}
---

# Migrating an existing animation

Move one interaction from implicit widgets or an AnimationController to state targets, while preserving layout and ownership.

<!-- section: start-small -->
## Keep the screen, change one interaction

Keep your state management, layout and business callbacks. Select a small animation with a clear endpoint and keyboard action. Replace its paint animation, compare the behavior, then decide whether more of the screen benefits.

These guides were checked against nib_motion 0.3.5. Version 0.3.6 is published on pub.dev. Shader rendering needs checks on your target device.

<!-- section: concepts -->
## Map responsibility before syntax

These are Flutter concepts, not automatic source translations. Existing AnimationControllers remain useful when another API requires an Animation<double>.

| Existing responsibility | NibMotion entry point | Keep in mind |
| --- | --- | --- |
| Implicit target change | NibMotion + animate: NibAnim(...) | x/y are paint offsets, not layout constraints. |
| Controller-driven start/stop | NibMotionController | Create once; dispose the owner. |
| Tween timing | NibTransition(duration:, curve:) | A spring instead uses physical settling. |
| Gesture position and release | NibDragConfig + MotionValue | Keep bounds and velocity in local pixels. |
| A timed multi-step sequence | NibKeyframe / NibTimeline | Use explicit starts for reproducible seeks. |
| Removed list item | NibPresence + stable keys + exit | Application state still owns membership. |
| Measured layout change | NibMotion(layout:) + NibLayoutScope | Respect the documented geometry limits. |

<!-- section: verify -->
## Test interruption before migrating the next screen

Change the target again before settling. Navigate away while motion runs. Check focus, hit targets, reduced motion, controller cleanup and final state. Avoid replaying by changing a key unless you intend to reset local State.

Effects from other libraries may combine several properties. Compose NibAnim fields or keyframes for the same job; do not assume a matching preset name has identical timing or lifecycle behavior.

[Build the first state-driven animation](first-animation.md)

[Controller ownership](controllers.md)

[Accessibility and reduced motion](accessibility.md)

<!-- section: applications -->
## Explore the complete example application

The NibMotion gallery includes 29 examples: the original 21 demos, Daily Focus, two quick starts and five additional examples. It is included with the published 0.3.6 release. Its README has local launch instructions.

[Review the 29-example gallery and launch instructions](https://github.com/oraclevs/nib_motion/blob/v0.3.6/example/README.md)

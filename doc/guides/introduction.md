---
{
  "id": "introduction",
  "evidence": "MotionNib/motion/lib/src/core/nib_anim.dart; MotionNib/motion/lib/src/core/nib_motion_widget.dart; MotionNib/motion/lib/src/core/nib_transition.dart"
}
---

# Introduction

A unified Flutter motion system for state transitions, physics, layout, scroll, orchestration and visual effects.

<!-- section: one-motion-model -->
## Carry an interaction from input to pixels

NibMotion connects targets, reactive motion values and drivers in one model. A dragged card can hand its velocity to inertia or a spring. A scroll position can drive opacity and translation together. Layout, presence and timelines build on those same values rather than requiring a separate animation model for each behavior.

Begin with initial, animate and a transition on one widget. Controllers and lower-level solvers are available when your interaction needs them. Continuous paint updates can avoid rebuilding the child every frame; text content changes and application state still rebuild where needed.

These guides were checked against nib_motion 0.3.5. Version 0.3.6 is published on pub.dev. Shader rendering needs checks on your target device.

NibComponents is a separate UI library that depends on NibMotion. NibGenUI is a separate, unpublished structured-UI preview. Neither is required to animate an existing Flutter widget.

[Install NibMotion](installation.md)

<!-- section: declarative-motion -->
## Declarative motion

Describe an entrance, a selected state, or a complete keyframe sequence with NibAnim and NibTransition. Named variants let a parent coordinate its children.

[Create your first animation](first-animation.md)

[Transitions, variants and stagger](variants-stagger.md)

[Compose keyframes](keyframes.md)

<!-- section: physics-and-gestures -->
## Physics and interactive gestures

Build a draggable card that coasts, meets a boundary, or snaps into place. Springs retarget from the current value and velocity, so another input can arrive before the last movement settles.

[Retarget a spring](springs.md)

[Gestures, bounds and snap](gestures.md)

[Inertia and custom simulations](physics.md)

<!-- section: layout-and-presence -->
## Layout and presence

Reorder a list, expand a card, or let a removed item finish its exit while siblings reflow. Stable identity connects application state to measured layout and retained exits.

[Layout and shared identity](layout-animations.md)

[Coordinate reflow and exits](layout-presence.md)

<!-- section: scroll-and-orchestration -->
## Scroll and orchestration

Map scroll progress to paint, reveal content as it enters a viewport, or coordinate several controllers on one timeline. Use route transitions when the movement belongs to navigation.

[Scroll-linked values](scroll-motion.md)

[Seek a timeline](timeline.md)

[Animate navigation](routes.md)

<!-- section: visual-effects -->
## Visual effects and expressive interfaces

Animate text units, follow a path, reveal a surface, or add glass and decorative water. These effects compose with ordinary Flutter widgets; GPU paths have explicit renderer limits.

[Text and typewriter](text-motion.md)

[Paths and stroke drawing](path-motion.md)

[Shaders and glass](shaders.md)

[Water surfaces](water.md)

<!-- section: tools-and-accessibility -->
## Developer tooling, performance and accessibility

Tune a spring, inspect running values, and replay entrances during development. Profile the actual screen and provide the same useful outcome when reduced motion skips the travel.

[Debug and tune springs](debugging.md)

[Measure performance](performance.md)

[Design for reduced motion](accessibility.md)

<!-- section: before-you-start -->
## Begin with a Flutter widget you already understand

You need a Flutter app and a widget whose state can change. NibMotion does not replace Row, Column, Stack, or a state manager. Flutter still decides where the child belongs in layout. NibMotion paints an offset, scale, rotation, opacity, or decoration as that state changes. A card translated with x still occupies its original layout slot, which matters when another widget sits beside it.

Import package:nib_motion/nib_motion.dart and place NibMotion around one child. Give the child a stable identity while you change targets. For a first experiment, use a colored box rather than a whole route; it is easier to see which visual property is moving.

<!-- section: model -->
## State describes the destination

NibMotion wraps an ordinary child. Its initial value is the entrance state; animate is the target when application state changes. Both accept a NibAnim or a named variant. Leave initial out to start at the neutral NibAnim.identity state.

NibAnim properties are nullable. An omitted property stays untouched by that state. x and y are logical pixel offsets from the child’s natural position; opacity runs from zero to one; rotate, rotateX, and rotateY use turns, where one turn is a full rotation. Keep the child’s layout and hit target useful at both endpoints.

<!-- api -->
| Name | Type | Default | Description |
| --- | --- | --- | --- |
| initial | NibAnim or String? | NibAnim.identity | Entrance state or named variant. |
| animate | NibAnim or String? | null | Current target or named variant. |
| child | Widget | required | The Flutter widget painted through the motion wrapper. |

```dart
NibMotion(
  initial: const NibAnim(opacity: 1, x: -36, scale: 0.9),
  animate: NibAnim(opacity: 1, x: _moved ? 38 : -38, scale: 1),
  transition: NibTransition.springGentle,
  child: const Icon(Icons.touch_app),
)
```

<!-- section: read-the-example -->
## Read the three lines that control movement

In this small target-state example, initial places the icon 36 logical pixels left of its natural position at 90 percent size. animate reads _moved, a boolean kept in State, and chooses either x: 38 or x: -38 at full size. Opacity stays at one. NibMotion drives the specified paint properties; it does not animate unrelated properties left null in NibAnim.

The first appearance is an entrance, not an instruction to keep restarting. When the button changes _moved with setState, the same NibMotion heads toward the new target from its current painted state. springGentle is the timing rule here. Without an explicit transition, the default is a 300 ms easeInOut tween unless an ancestor configuration changes it. Continue to Start with motion for a working entrance and Your first animation for a stateful interaction.

<!-- section: response -->
## Transition describes the journey

NibTransition chooses a fixed-duration tween or a physical spring. The default is a 300 ms easeInOut tween unless an ancestor NibMotionConfig supplies another default. Setting spring selects spring physics; duration and curve then stop controlling that movement.

In Your first animation, try changing the target twice before it settles. A rebuild supplies the next destination; NibMotion owns the per-property drivers and moves from its current painted values.

<!-- section: values -->
## Use MotionValue for direct data flow

MotionValue is a ValueListenable whose changes can reach NibMotion’s render object without rebuilding the child on every animation frame. Derived values can map one source into several paint properties. The creator must dispose externally owned values and their derived listeners.

For a first screen, you rarely need to create one. Start with application state and animate; NibMotion creates its own values. Reach for an external MotionValue when another changing source, such as a slider or scroll position, should drive paint continuously. This distinction keeps the first example small and gives you a clear owner for disposal later.

<!-- section: try-it -->
## Choose the next step

After Installation, Start with motion introduces a finite entrance. Your first animation then connects Save and Undo actions to an interruptible spring. Those lessons include live controls and runnable source; this introduction explains how the pieces fit together.

Install only nib_motion to animate existing Flutter widgets. Add nib_components when you also want the accompanying UI controls; it is a separate package, not a prerequisite for this guide.

<!-- section: when-it-surprises-you -->
## Three checks when the result looks wrong

If nothing moves, check that animate differs from the current value and that reduced motion is not active. If an entrance keeps replaying, check whether a changing key is remounting the widget. If nearby content does not move out of the way, remember that x and y are paint offsets; use layout animation when the child’s actual layout position changes.

The starter lessons separate entrance timing from state-driven interaction. From there, Springs explains interruption, Keyframes explains a timed sequence, and Motion values explains continuous input.

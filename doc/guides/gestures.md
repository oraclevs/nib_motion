---
{
  "id": "gestures",
  "evidence": "MotionNib/motion/lib/src/core/nib_motion_widget.dart; MotionNib/motion/lib/src/gestures/drag_handler.dart; MotionNib/motion/lib/src/gestures/nib_draggable.dart"
}
---

# Gestures

Respond to press, hover, focus, and direct manipulation.

<!-- section: choose-a-gesture -->
## Start with a temporary state

Use whileTap for a pressed response, whileHover for pointer presence, and whileFocus for keyboard focus. Each is a NibAnim target overlaid while that interaction is active. A focus treatment needs to remain visible on a control that keyboard users can actually reach; adding whileFocus to an unfocusable decoration will not create a keyboard action.

In the live example, the tile shrinks to scale 0.9 while pressed and grows to 1.08 on hover or drag. The ordinary animate.x target comes from the Move right button. That target is independent of the temporary scale response, so the tile can move toward a new destination while its interaction feedback changes.

<!-- section: states -->
## Use the right temporary state

NibMotion accepts whileTap, whileHover, whileFocus, and whileDrag as NibAnim overrides. When states overlap, drag has priority over tap, then hover, then focus. When the interaction ends, reverseTransition can use a different response for the trip home.

Hover is a pointer affordance; it is not the only way to expose an action. The live example pairs horizontal dragging with a Move right button so keyboard and touch users can reach the same endpoint.

```dart
NibMotion(
  whileTap: const NibAnim(scale: 0.9),
  whileHover: const NibAnim(scale: 1.08),
  whileDrag: const NibAnim(scale: 1.08),
  drag: const NibDragConfig(axis: Axis.horizontal),
  child: const Icon(Icons.drag_indicator),
)
```

<!-- api -->
| Name | Type | Default | Description |
| --- | --- | --- | --- |
| axis | Axis? | null | Null allows free drag; otherwise lock one axis. |
| constraints | Rect? | null | Offset bounds relative to the resting position. |
| releaseMode | NibDragReleaseMode | springBack | Spring back, coast with inertia, or stay at release. |

<!-- section: bound-the-drag -->
## Add direct manipulation deliberately

Passing NibDragConfig to NibMotion.drag enables dragging. axis: Axis.horizontal ignores vertical movement. The live configuration uses Rect.fromLTRB(-70, 0, 70, 0): those left and right numbers are offsets from the resting position in the receiving widget’s local logical pixels, not screen coordinates. springBack sends the dragged offset home when the pointer releases.

With elastic true, movement beyond constraints gets resistance rather than a hard clamp; elasticFactor defaults to 0.2. snapPoints, when supplied, take precedence over releaseMode and pick a destination offset. onDragEnd receives a Velocity in receiver-local logical pixels per second in 0.3.5. Keep it in the same coordinate system if you use it to seed another motion.

```dart
drag: const NibDragConfig(
  axis: Axis.horizontal,
  constraints: Rect.fromLTRB(-70, 0, 70, 0),
  releaseMode: NibDragReleaseMode.springBack,
)
```

<!-- section: drag -->
## Bound a drag in local units

NibDragConfig sets axis, optional Rect constraints, elasticity, and a release mode. springBack is the default release mode; inertia coasts and stay keeps the released offset. snapPoints are receiver-local offsets. In 0.3.5, release velocity is reported in receiver-local logical pixels per second so position and velocity use the same coordinate space.

NibDraggable is a separate wrapper for a drag without NibMotion’s state API. NibPinch handles scaling and NibSwipeDismiss handles threshold-based removal. Choose one gesture owner for the same pointer stream.

<!-- section: limits -->
## Verify the full interaction

Test hit targets while moving and after release, especially under nonuniform scaling or nested transforms. Perspective and near-singular transforms are not in the current verified drag contract. Confirm focus and semantics still expose an equivalent action.

<!-- section: try-gesture -->
## Compare drag and button input

Drag the tile to either edge and let go. It should follow your horizontal movement within its bounds and then spring back. Hover or press it and watch scale change. Now use Move right: the same screen reaches another target without requiring a drag. Navigate to the button with a keyboard and confirm it works there too.

In an app, put a meaningful action behind the control, not behind the animation alone. If releasing the drag commits a choice, provide a visible control that commits the same choice and a label that explains the outcome. A gesture effect without an accessible action is only decoration.

<!-- section: gesture-errors -->
## Debug the space and the gesture owner

If a drag seems offset from the finger, inspect transformed ancestors and the configured local bounds. If a scroll view and tile both want the same pan gesture, choose which element should own it; do not layer two competing drag handlers over the same target. NibDraggable is a separate wrapper for direct dragging, while NibPinch and NibSwipeDismiss solve different gestures.

Check the painted position, hit target, focus, and semantics during movement. A test that merely completes without throwing does not establish that the user can still reach the tile. For complex geometry, read the platform limits before relying on a transformed drag in a critical flow.

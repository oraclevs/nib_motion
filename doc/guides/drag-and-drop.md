---
{
  "id": "drag-and-drop",
  "evidence": "MotionNib/motion/lib/src/gestures/nib_draggable.dart; MotionNib/motion/lib/src/gestures/nib_pinch.dart; MotionNib/motion/lib/src/gestures/nib_swipe_dismiss.dart"
}
---

# Drag, pinch, and swipe

Use a standalone gesture widget when direct manipulation is the job.

<!-- section: choose-owner -->
## Choose one gesture owner

NibMotion.drag belongs on a NibMotion that also needs animate, whileTap, or other motion states. NibDraggable is a focused wrapper for moving a child directly. It owns two motion values for its painted x and y offsets, and dragging does not rebuild the child on every pointer update. Avoid nesting both handlers on the same pointer target; the gesture arena still has to choose a winner.

NibDraggable.bounds is a Rect of offset limits from the resting position. axis locks one dimension. snapBack defaults to false, so a release stays at its offset. Set snapBack true to spring to zero or to snapTarget; spring defaults to NibSpringDescription.gentle. onDragEnd receives the final offset and velocity in receiver-local logical pixels per second.

```dart
NibDraggable(
  axis: Axis.horizontal,
  bounds: const Rect.fromLTRB(-80, 0, 80, 0),
  snapBack: true,
  child: const Icon(Icons.drag_indicator),
)
```

<!-- section: pinch -->
## Bound a pinch before using it

NibPinch scales around the center of its child. minScale defaults to 0.5, maxScale to 4, and initialScale to 1. It clamps updates into that range. With snapBackOnRelease false, the chosen scale remains after the gesture; with true, a spring returns to initialScale. onScaleChanged reports the current scale when the gesture updates.

A zoomed child can paint beyond its original slot. Leave enough space or clip deliberately, and test hit targets at the transformed edge. A pinch is hard to discover and unavailable to some users, so provide another way to reach any important zoom state.

```dart
NibPinch(
  minScale: 1,
  maxScale: 2,
  snapBackOnRelease: true,
  child: const FlutterLogo(size: 80),
)
```

<!-- section: swipe -->
## Remove the model item after dismissal

NibSwipeDismiss compares the released offset with dismissThreshold times the widget extent. The default threshold is 0.5. A short swipe springs home; a qualifying swipe animates offscreen and then calls onDismissed. Remove the item from your source list in that callback. DismissDirection.horizontal accepts either side; startToEnd and endToStart restrict horizontal direction, while vertical allows both vertical directions.

The optional background sits behind the child while swiping. It can explain the action, but the visible item also needs an accessible delete or archive control if dismissal has meaning. Test repeated input while the offscreen animation is pending so the same item cannot trigger a second destructive action.

```dart
NibSwipeDismiss(
  dismissDirection: DismissDirection.endToStart,
  dismissThreshold: 0.4,
  onDismissed: () => setState(() => items.remove(item)),
  child: Text(item.label),
)
```

<!-- section: geometry-and-lifecycle -->
## Check geometry and interruption

Try a drag under a scrolling parent, release before the spring settles, and start another gesture. Check the painted position, pointer target, keyboard focus, and semantics during motion. The 0.3.5 source verifies selected affine transforms; perspective and near-singular transforms are outside its documented geometry contract. A test that only avoids an exception does not establish that the hit target follows the painted child.

These wrappers own their internal values and solvers. Your State still owns the item list and any external controller it creates. For list reordering rather than a free dragged offset, use NibReorderable or a Flutter reorderable list with layout motion. Continue to Gestures for temporary hover, press, focus, and NibMotion.drag states.

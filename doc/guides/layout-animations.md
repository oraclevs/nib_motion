---
{
  "id": "layout-animations",
  "evidence": "MotionNib/motion/doc/layout.md; MotionNib/motion/lib/src/layout/nib_layout.dart; MotionNib/motion/lib/src/layout/nib_layout_scope.dart"
}
---

# Layout animations

Animate a keyed child from its old measured place to its new one.

<!-- section: before-you-start -->
## Start with state and identity

Use layout motion when Flutter itself changes a child’s size or position: a row is reordered, a filter removes a card, or a details panel expands. Keep the data change in ordinary widget state. Layout motion observes the before and after rectangles; it does not decide where a widget belongs. A translation inside animate changes paint position, not the parent’s layout, so that is a different job.

Each moving item needs a stable key based on its data identity, such as ValueKey(item.id). An index key follows the slot when the order changes, which can make the animation follow the wrong item. Keep the NibLayoutScope above both the old and new placements when using a shared layoutId. For simple reflow a scope is useful because it defines the measurement space, although a box layout can work without one.

<!-- section: flip -->
## Measure, invert, play

NibMotion(layout:) uses FLIP: it measures before and after a layout change, paints from the old visual bounds, and animates the difference away. NibLayout.position changes position; NibLayout.size changes size; NibLayout.both handles both. Use stable keys so a reordered child remains the same element.

In the live example, Move first to end updates the Row’s order. NibLayoutScope supplies the measurement space; each keyed tile uses layout: NibLayout.position. New children need an entrance animation if they should move in, because there is no previous layout to invert.

<!-- api -->
| Name | Type | Default | Description |
| --- | --- | --- | --- |
| layout | NibLayout | inherit | Position, size, both, none, or a scope-provided default. |
| layoutSizeMode | NibLayoutSizeMode | scale | Scale size changes; clip reveals final-layout content. |
| layoutId | Object? | null | Shared identity for detached-to-mounted handoff in one scope. |

```dart
// In build(); items comes from State.
NibLayoutScope(
  child: Row(
    children: [
      for (final item in items)
        NibMotion(
          key: ValueKey(item.id),
          layout: NibLayout.position,
          layoutTransition: NibTransition.springGentle,
          child: ItemTile(item: item),
        ),
    ],
  ),
)
```

<!-- section: walkthrough -->
## Build and inspect a reorder

In the example above, changing items causes Row to calculate new offsets. The keyed NibMotion for each surviving item remains mounted, measures the new offset, and initially paints at its old visual position. layoutTransition then returns the painted offset to zero. The spring controls how this return feels; it does not change Row’s final order. NibLayout.position leaves the child’s measured size alone. Choose both only if the item’s own dimensions also change.

Open the keyed-reorder demo and move one item to the end. Then change the key to the loop index in a local copy: notice that Flutter now treats the old slot as the continuing element. Restore the data key. Next try layoutSizeMode: NibLayoutSizeMode.clip on a card that expands. Its new content is laid out at final size and revealed by a clip rather than stretched. On shrink, old pixels cannot be retained because the new child has already laid out smaller.

<!-- api -->
| Name | Type | Default | Description |
| --- | --- | --- | --- |
| layoutTransition | NibTransition? | springGentle | Spring or tween for returning measured layout channels to identity; delay holds the old visual bounds. |
| onLayoutAnimationStart | VoidCallback? | null | Called when this child begins a measured layout animation. |
| onLayoutAnimationComplete | VoidCallback? | null | Called on completion, not for a run superseded by a newer layout change. |

<!-- section: size -->
## Choose how size changes look

The default size mode scales the child during a size transition. NibLayoutSizeMode.clip reveals content at its final layout size through an animated clip. This can keep text from stretching, but clipping is visible by design.

layoutId links a recently detached source to a newly mounted destination inside the same scope. It is a handoff through retained snapshot geometry, not a transition between two widgets that remain live at once.

<!-- section: interruptions -->
## Handle retargeting and removal

If state changes again while a FLIP is playing, the widget retargets from its current painted position and velocity. Do not wait for a previous onLayoutAnimationComplete before applying a legitimate new order: the superseded run does not report completion. If your host needs one callback for an entire list update, use the aggregate NibPresence or NibLayoutGroup callbacks and identify the batch in your own state.

A new item has no old rectangle. Give it an initial and animate state if an entrance matters. A removed item needs NibPresence and an exit state if it should remain visible while leaving. A detached layoutId is retained only briefly, so build the destination during the same state change rather than across an asynchronous fetch. For a scrolling lazy list, only mounted items have old geometry; an item that leaves cache extent cannot animate back from its former offscreen placement.

<!-- section: geometry -->
## Know the measured space

The 0.3.5 source has numeric regressions for selected affine transforms. Perspective and near-singular transforms, rotated reorder, and pop exits that need cross-space ancestor clipping remain outside its verified geometry contract. Test scrolling parents, hit targets, focus, and semantics in the actual screen.

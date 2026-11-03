---
{
  "id": "motion-lists",
  "evidence": "MotionNib/motion/lib/src/list/nib_motion_list.dart; MotionNib/motion/lib/src/presence/nib_presence.dart"
}
---

# Motion lists

Stagger a short list while keeping item identity and layout explicit.

<!-- section: what-the-wrapper-does -->
## One motion wrapper per child

NibMotionList wraps every child in a NibMotion and offsets each transition delay by its index. staggerDelay defaults to 50 ms. NibStaggerDirection.forward starts at index zero; reverse starts at the last child. Its initial, animate, exit, variants, transition, and controller settings are forwarded to the wrapped children. Keep the source list in State and build from stable item IDs.

Without presenceEnabled, the list uses a Column with minimum main-axis size. A parent Row or grid is not preserved by this wrapper. If you need a different layout, put keyed NibMotion children in that layout directly and use parent variants with delayChildren and staggerChildren, or compose NibPresence with a layoutBuilder.

```dart
NibMotionList(
  initial: const NibAnim(opacity: 0, y: 12),
  animate: NibAnim.identity,
  staggerDelay: const Duration(milliseconds: 75),
  children: [
    for (final item in items)
      Text(item.label, key: ValueKey(item.id)),
  ],
)
```

<!-- api -->
| Name | Type | Default | Description |
| --- | --- | --- | --- |
| staggerDelay | Duration | 50 ms | Added per child index to the base transition delay. |
| staggerDirection | NibStaggerDirection | forward | Chooses which end starts first. |
| presenceEnabled | bool | false | Uses NibPresence for keyed exits when true. |

<!-- section: delay-math -->
## Know when each row starts

With the 75 ms delay above, the first row starts at the base transition delay, the second 75 ms later, and the third 150 ms later. Reversing direction changes which end gets those offsets; it does not reorder the data. A transition supplied to the list keeps its own duration, curve, spring, and delay. The stagger adds to that delay rather than replacing it.

Change one thing at a time: run three keyed rows forward, reverse the stagger direction, then add a base delay. Watch the start order and check that each row settles at the same animate target. For a large list, a 50 ms offset multiplied by many items can make later content wait too long; limit stagger to a small visible group.

<!-- section: presence-choice -->
## Decide whether removal needs an exit

Set presenceEnabled only when removed children need their exit animation. Every direct child then needs a unique non-null key, and exit must describe the departing pose. The wrapper passes its wrapped children to NibPresence. In this mode the default presence layout is a Stack, unlike the Column used when presenceEnabled is false. If the departing row must keep a vertical slot or siblings must reflow, build that composition explicitly with NibPresence.layoutBuilder or the layout factory.

Remove an item from the source list first. Presence keeps the old keyed child mounted for the visual exit and prevents pointer, focus, and semantics interaction during departure. A callback after exit is a lifecycle event, not the place to decide that the source item no longer exists.

```dart
NibMotionList(
  presenceEnabled: true,
  initial: const NibAnim(opacity: 0),
  animate: NibAnim.identity,
  exit: const NibAnim(opacity: 0, x: -24),
  children: [
    for (final item in items)
      Text(item.label, key: ValueKey(item.id)),
  ],
)
```

<!-- section: when-to-use-variants -->
## Use named variants for a parent-controlled group

NibMotionList is concise when each row shares the same target. Parent variants are better when the group has an open or closed state and each child needs its own named pose. Both approaches can stagger, but they calculate delay in different places: the list offsets each wrapped child directly, while the parent transition schedules children that inherit a variant.

Do not make a list key from its current index when rows can move. That key follows the slot and can attach an exit or entrance to the wrong item. Continue to Variants and stagger for named parent states, or Layout and presence together when reflow is part of the interaction.

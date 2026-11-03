---
{
  "id": "variants-stagger",
  "evidence": "MotionNib/motion/lib/src/variants/nib_variants.dart; MotionNib/motion/lib/src/core/nib_motion_widget.dart; MotionNib/motion/lib/src/list/nib_motion_list.dart"
}
---

# Variants and stagger

Name related states and schedule children that inherit them.

<!-- section: parent-and-child -->
## Put names on both levels

Define a small named map for the parent, such as closed and open. Give the parent NibMotion an animate string chosen from that map. Inside it, each child NibMotion has its own variants map with the same names but may have different NibAnim values. Leave the child animate parameter null so it reads the propagated parent name.

The live example has one parent state and three children. The parent changes opacity; each child changes opacity and x. Press Open list and watch the three rows arrive in order. Press Close list and observe the return. A child with an explicit animate target would ignore the inherited name and could remain visible when the parent closes.

```dart
const childStates = <String, NibAnim>{
  'closed': NibAnim(opacity: 0, x: -18),
  'open': NibAnim(opacity: 1, x: 0),
};

NibMotion(
  variants: parentStates,
  animate: open ? 'open' : 'closed',
  transition: const NibTransition(staggerChildren: Duration(milliseconds: 75)),
  child: Column(children: [
    for (final item in items)
      NibMotion(key: ValueKey(item.id), variants: childStates, child: ItemTile(item)),
  ]),
)
```

<!-- section: names -->
## Name each state once

NibVariants is a map from a string name to NibAnim. NibMotion.initial and animate can use a name instead of a literal NibAnim. A parent propagates its resolved variant name to descendant NibMotion widgets that have matching variants and no explicit animate value.

Use an explicit animate value on a child when it should ignore the inherited name. Keep all names present in the relevant map; a missing name cannot describe a target.

<!-- api -->
| Name | Type | Default | Description |
| --- | --- | --- | --- |
| variants | Map<String, NibAnim>? | null | Named states available to this NibMotion. |
| animate | NibAnim or String? | null | Literal target, named target, or inherited variant. |

```dart
const states = <String, NibAnim>{
  'closed': NibAnim(opacity: 0, y: 12),
  'open': NibAnim(opacity: 1, y: 0),
};
NibMotion(
  variants: states,
  animate: expanded ? 'open' : 'closed',
  child: content,
)
```

<!-- section: stagger -->
## Delay inherited children

A parent NibTransition can set delayChildren before the first descendant starts and staggerChildren per descendant index in build order. Those timings apply to children resolving animate from the propagated variant. NibMotionList offers a separate list API: staggerDelay defaults to 50 ms and can run forward or reverse.

Use stable keys when items reorder. Without them, stagger can play on a newly mounted item instead of the existing visual item. NibMotionList presenceEnabled requires unique child keys because it uses NibPresence.

<!-- api -->
| Name | Type | Default | Description |
| --- | --- | --- | --- |
| delayChildren | Duration | zero | Parent variant delay before the first inheriting child. |
| staggerChildren | Duration | zero | Extra delay per inheriting descendant index. |
| NibMotionList.staggerDelay | Duration | 50 ms | List wrapper delay between consecutive children. |

<!-- section: calculate-the-delay -->
## Understand what stagger changes

In the live example, delayChildren adds 30 ms before the first inheriting child. staggerChildren adds 75 ms per child index in build order. The rows therefore start at distinct times while each still uses its own transition to travel between named states. Stagger shifts start times; it does not change each child’s target or multiply the parent’s duration.

Try removing staggerChildren in a copied example. The three rows should begin together. Restore it, then reverse the order of the child widgets while keeping their keys; the start order follows their new build order. If an item is re-created with a new key, it may also replay its entrance, which is a separate identity issue.

<!-- section: motion -->
## Keep the list readable

Large stagger windows can delay information. Keep labels and hit targets usable while children enter, and verify the full list with reduced motion. The package jumps to final targets when reduction is active.

<!-- section: pace-and-access -->
## Do not make content wait for decoration

Staggering a long list can postpone the last item by hundreds of milliseconds. Keep the task usable while entries arrive, and test the final state with reduced motion. A name change should still communicate open or closed through labels and accessibility state, not only through fading rows.

Once this parent-child model is clear, Timeline is the next tool for independent elements that start at named offsets. It schedules controllers rather than relying on inherited variant names.

<!-- section: variant-errors -->
## Check names and inheritance first

A child cannot resolve a propagated name missing from its variants map. Keep closed and open spelled the same in the parent and children. If a child never follows the parent, inspect whether its animate parameter is explicitly set. If it jumps or restarts during reorder, inspect its key.

NibMotionList provides a shorter path for a plain list entrance with staggerDelay, which defaults to 50 ms. Set presenceEnabled only when each child has a unique key and exit behavior is needed. For a menu whose parent and children have related named states, the variant scope explains the relationship more clearly.

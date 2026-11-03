---
{
  "id": "presence",
  "evidence": "MotionNib/motion/lib/src/presence/nib_presence.dart; MotionNib/motion/lib/src/core/nib_motion_widget.dart"
}
---

# Presence

Keep a removed keyed child until its exit completes.

<!-- section: own-the-list -->
## Let application state own membership

NibPresence does not decide which items exist. Keep the collection in the parent StatefulWidget, call setState when an item is added or removed, and build NibPresence.children from the current collection. In the live example, the list begins with integers 1, 2, and 3. Add appends a new integer; Remove deletes the last one from the source list. The presence wrapper compares old and new keys to find what left.

The code excerpt assumes items is that State collection and ItemTile is your normal Flutter widget. ValueKey(item.id) must represent the same logical item on every rebuild. Do not use the current list index as the key when items can be inserted or reordered; the index describes a slot, not an item identity.

<!-- section: identity -->
## Give each child a stable key

NibPresence compares child keys from one build to the next. Every direct child needs a unique non-null key. A keyed NibMotion child needs an exit NibAnim to animate before removal; without exit, it leaves immediately.

<!-- api -->
| Name | Type | Default | Description |
| --- | --- | --- | --- |
| children | List<Widget> | required | Direct children with unique non-null keys. |
| exitLayout | NibExitLayout | sync | Keep the slot until exit; pop reflows siblings immediately. |
| onChildExit | ValueChanged<Key>? | null | Called after a departing child leaves the tree. |

```dart
NibPresence(
  children: [
    for (final item in items)
      NibMotion(
        key: ValueKey(item.id),
        exit: const NibAnim(opacity: 0, x: -40),
        child: ItemTile(item: item),
      ),
  ],
)
```

<!-- section: exit-state -->
## Define a visible exit

An exit NibAnim is the destination after removal. The live tile uses opacity zero and y: -20, so it moves upward and fades while leaving. Its initial state, opacity zero and y: 20, is an entrance for a newly added item. Its animate state is NibAnim.identity, the resting appearance between those two paths.

Because the exiting widget stays mounted for the transition, painting can continue after the source list no longer contains it. NibPresence blocks pointer events, focus, and semantics on that departing element. This prevents a stale button from receiving another action during its fade. Use onChildExit if the host needs a callback after actual removal; it is distinct from the moment your collection changes.

<!-- section: during-exit -->
## What happens while it leaves

The exiting element remains mounted until its exit Future finishes. NibPresence wraps it in IgnorePointer, ExcludeFocus, and ExcludeSemantics during that period. Its onChildExit callback runs after removal. Add and remove a tile in the live example to inspect this lifecycle.

Re-adding the same key during exit cancels the pending removal and restores the animator toward its resting state. Use keys for persistent item identity, not a changing list index.

<!-- section: reflow -->
## Choose the layout behavior

NibExitLayout.sync keeps an exiting child’s layout slot until it leaves. NibExitLayout.pop lets siblings reflow immediately and paints the leaver at captured bounds. The pop path has geometry limits with transformed and clipped ancestors; test it in the actual layout before a critical interaction.

<!-- section: try-presence -->
## Test the lifecycle, not just the fade

Press Add, wait until tile 4 settles, then press Remove. Watch where the fourth tile goes and whether the row keeps its gap until it leaves. The default sync exit keeps that slot. Press Add and Remove quickly next: the component should still identify items by their keys rather than by whichever slot is last at that instant.

For a list that should close its gap immediately, use NibExitLayout.pop or the NibPresence.layout factory, which combines pop with layout motion for the remaining children. That path uses captured geometry and has limits under complex transforms or clipping. Check hit testing and focus after an exit, especially when an overlay is involved.

<!-- section: presence-mistakes -->
## Why an item may disappear or jump

No exit target means immediate removal. A missing or duplicate direct-child key causes a Flutter error. A changing key makes the same logical item look new on every build. If siblings jump instead of moving, remember that presence by itself controls lifetime; layout motion is a separate feature.

If a removed child remains visible longer than expected, a spring may still be waiting to meet its completion tolerance. Do not force a short timer that removes it before its own exit finishes. Continue to Layout and presence together when the gap and sibling movement must be choreographed.

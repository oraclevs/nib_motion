---
{
  "id": "layout-presence",
  "evidence": "MotionNib/motion/lib/src/presence/nib_presence.dart; MotionNib/motion/lib/src/layout/nib_layout_defaults.dart; MotionNib/motion/doc/layout.md"
}
---

# Layout and presence together

Let siblings reflow while a removed item completes its exit.

<!-- section: composition -->
## Combine identity and measurement

Presence tracks whether a keyed child still belongs in the collection. Layout motion tracks the changed position of children that remain. NibPresence.layout composes both: it wraps children in a layout scope, defaults child layout to position, and defaults exitLayout to pop.

The simpler NibPresence constructor defaults to a Stack when no layoutBuilder is supplied. Give it a Row, Column, or Wrap builder when the parent layout matters. Every direct child still needs a unique non-null key.

<!-- section: working-example -->
## Remove a chip without closing the gap abruptly

Keep the chip IDs in State and build the children from that list. NibPresence.layout supplies a Wrap or Column, the layout scope, position motion for children that inherit it, and pop exits by default. The example gives each NibMotion a stable key and a visible exit target. Removing an ID changes the source list immediately; presence keeps that old keyed child alive only until its exit finishes. Its siblings take their final places at once and animate their movement.

Start with sync if a departing row must still hold its slot while it fades. Choose pop when an immediate reflow is important, such as dismissing a tag from a dense group. For a custom grid or unusual parent, use NibPresence with layoutBuilder and explicitly choose exitLayout. Its default container is Stack, which will not reproduce a Row or Wrap layout.

```dart
// In build(); tags comes from State.
NibPresence.layout(
  axis: NibPresenceAxis.wrap,
  spacing: 8,
  runSpacing: 8,
  children: [
    for (final tag in tags)
      NibMotion(
        key: ValueKey(tag.id),
        exit: const NibAnim(opacity: 0, scale: 0.85),
        child: Chip(label: Text(tag.label)),
      ),
  ],
)
```

<!-- api -->
| Name | Type | Default | Description |
| --- | --- | --- | --- |
| axis | NibPresenceAxis | column | Choose Column, Row, or Wrap for the layout factory. |
| exitLayout | NibExitLayout | pop in layout factory; sync in base constructor | Controls when the departing child releases its layout slot. |
| stagger | Duration | Duration.zero | Delay between children in the same enter or exit batch. |

<!-- section: reflow -->
## Choose when the gap closes

With sync exits, the departing child keeps its slot until the exit ends. With pop exits, siblings close the gap immediately while the departing child is painted at captured bounds. An exiting child is excluded from pointer, focus, and semantics, so it cannot keep acting as a stale control.

Use a visible exit state on each NibMotion that should linger. A child without exit is removed immediately. Add and remove repeatedly to check callback ordering and interruption in the host list.

<!-- section: events -->
## Read callbacks as lifecycle events

onChildEnter reports additions after the first build; initial children are already present. onChildExit reports that a removed child has actually left the tree, after its exit when one exists. onChildMove reports a layout animation beginning on a keyed NibMotion. The aggregate onAnimationStart and onAnimationComplete cover exits and moves, with one completion after all work in the batch finishes or is superseded. Entrance animations belong to the children and are outside that aggregate.

Try the presence-reflow demo, remove two items, then add one of those keys back during its exit. Watch the gap and callback order. Re-addition returns that keyed child to the layout flow and cancels the exit. An exiting child is excluded from pointer hits, focus, and semantics while it is only a visual remnant; keep the remaining controls available to keyboard and screen-reader users. Dispose or navigate away during a delayed exit in a test so no stale callback mutates a closed screen.

A common mistake is to use an exit callback to remove the same item from the source collection. Presence only sees an exit after the collection has already stopped supplying that key. Remove it from source state first; use onChildExit for follow-up work that truly depends on the visual departure. If a whole batch must finish before another visual phase begins, use the aggregate completion callback and check that the owning State still exists.

<!-- section: limits -->
## Check transforms and clips

Captured exit geometry crosses coordinate spaces. The 0.3.5 source tests selected scaled and rotated cases, but perspective, near-singular transforms, rotated reorder, and ancestor clips spanning different spaces have scoped limits. Use the documented geometry contract before relying on pop exits in a transformed overlay.

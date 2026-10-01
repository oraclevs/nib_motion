# Layout animation

`NibMotion(layout: …)` animates its own layout changes — FLIP (First, Last,
Invert, Play) — in **any parent**: `Column`, `Row`, `Wrap`, `Stack`, grids,
custom render objects. `NibLayoutGroup` (a keyed `Column`) is the same
mechanism: each child is a `NibMotion(layout: NibLayout.position,
layoutChannelMode: NibLayoutChannelMode.translate)` inside a `NibLayoutScope`.

```dart
NibLayoutScope(                       // optional: defines the coordinate space
  child: Wrap(children: [
    for (final item in items)
      NibMotion(
        key: ValueKey(item.id),
        layout: NibLayout.both,        // position, size, both, none
        layoutTransition: NibTransition.springGentle,
        child: Card(item),
      ),
  ]),
)
```

| API | Meaning |
|---|---|
| `NibMotion.layout` | `none` (default), `position`, `size`, `both` |
| `NibMotion.layoutTransition` | how the change plays back (default `springGentle`; `spring`/`duration`/`curve`/`delay` used — during the delay the widget keeps looking like it did before the change) |
| `NibMotion.layoutSizeMode` | `scale` (default, stretches the child) or `clip` (child laid out at final size, revealed through a growing clip anchored top-left) |
| `NibMotion.onLayoutAnimationStart/Complete` | fired per layout animation; *complete* is not fired when a newer one superseded it |
| `NibMotion.layoutId` | shared identity, needs an enclosing `NibLayoutScope` |
| `NibLayoutScope` | measurement space + shared-id registry |
| `NibPresence(layoutBuilder:, exitLayout:, stagger:, staggerFrom:)` | lay out presence children and choreograph exits |
| `NibReorderable(spacing:)` | long-press drag to reorder; gap between items; auto-scrolls the enclosing scroll view near its edges |
| `NibPresence` / `NibLayoutGroup` callbacks | `onChildEnter`, `onChildExit`, `onChildMove`, aggregated `onAnimationStart/Complete` (see below) |
| `NibPageProgress.tab(TabController)` | fractional tab index as a `MotionValue` |

## How it works

1. **Measure in layout space.** During `paint` the render object sums
   `parentData` offsets up to the nearest `NibLayoutScope` (or as far as box
   parents go, which stops at scrollables/slivers). Paint transforms — including
   other FLIPs in flight — and scrolling are *not* part of that number, so only
   genuine layout movement registers. Moving the scope itself is ignored.
2. **Invert without a flash.** If the rectangle changed, the render object
   computes the transform that makes the new layout look like the old painted
   one and applies it *in the same paint*. The widget state then writes it into
   four dedicated `MotionValue` channels (`x`, `y`, `scaleX`, `scaleY`),
   post-frame.
3. **Play.** The channels are animated back to identity by the normal drivers,
   so an interruption starts from the painted position *and velocity*
   (`MotionValue.velocity`) — there is no separate layout engine. The
   translation is applied in the widget's own coordinate space, so it is
   correct under scaled or rotated ancestors. Nothing rebuilds per frame.
4. **Size** is a scale about the centre by default (`both` also moves the
   centre; `size` holds the position). With `layoutSizeMode: clip` the box keeps
   its top-left fixed, is never scaled, and a clip (hit testing and semantics
   included) grows from the old size to the new one. A *shrinking* clip-mode
   widget shows its new content at once: the old pixels no longer exist.
5. **Reduced motion** (`NibMotionConfig`) jumps: channels go straight to
   identity, no ticker.

## Shared layout (`layoutId`)

Inside a `NibLayoutScope`, a widget that mounts with an id that another widget
in the same scope had *just* unmounted (within 250 ms of frame time) animates
from that widget's last rectangle: hero-style transitions that cross parents
and container types. Two live widgets with the same id do not affect each
other. Without a scope the id is inert.

## Presence

* Exiting children are wrapped in `IgnorePointer`, `ExcludeSemantics` and
  `ExcludeFocus`.
* `exitLayout: NibExitLayout.pop` removes an exiting child from the layout flow
  immediately and overlays it at its last rectangle (moved between parents
  with a `GlobalKey`, so its exit animation keeps running); siblings with
  `layout:` reflow at once.
* `stagger` delays the children of a batch by index (entrances of newly added
  children and exits of removed ones); `staggerFrom` picks `first`, `last` or
  `center`. Re-adding a child during its delay cancels its exit.

## Lifecycle callbacks

`NibPresence(onChildEnter:, onChildExit:, onChildMove:, onAnimationStart:,
onAnimationComplete:)` and the same on `NibLayoutGroup`.

* `onChildEnter(key)` — a child added after the first build (initial children
  are not "entering"). Called after the frame when raised during a build.
* `onChildExit(key)` — a removed child has left the tree (after its exit
  animation; immediately when it has none). `NibLayoutGroup` children have no
  exit animation, so it fires right after removal.
* `onChildMove(key)` — a layout animation started for that child (siblings
  reflowing). For `NibPresence` the child must be a keyed `NibMotion` with
  `layout:` set.
* `onAnimationStart/Complete` — aggregate: start when the first exit/move of a
  batch begins, complete once *all* of them ended or were superseded. Every
  start is matched by one complete. Enter animations belong to the children and
  are not part of the aggregate.

## NibReorderable

Every item is a `NibMotion(layout: position)`. Long-press an item, drag; when
its centre passes a sibling's centre the temporary order changes and the
sibling FLIPs into the freed slot. On release `onReorder(oldIndex, newIndex)`
is called once (only if the index changed); if the parent does not apply it the
items animate back. `spacing` separates items. If the list sits in a scroll view
on the same axis, holding the dragged item within 56 px of its edge scrolls it
(up to 900 px/s at the very edge) and keeps the item under the finger.

## Limits (deliberately documented)

* **Lazy lists / slivers.** `NibMotion(layout:)` works inside `ListView`,
  `GridView`, `SliverList`/`SliverGrid`/`SliverFixedExtentList` and
  `SliverToBoxAdapter`. Items are measured in *scroll-content space* (the
  sliver's preceding scroll extent plus the item's own offset), so scrolling is
  not layout movement, while inserting, removing or resizing items above a
  visible one FLIPs it. Limits: items that scroll out of the cache extent are
  disposed, and one scrolled back in is a new widget (no FLIP on arrival);
  a reorder of a whole `ListView.builder` only animates the items
  that are built. Reversed lists (`reverse: true`, either axis), reverse-growth
  slivers before a `center`, and RTL grids are handled: sliver offsets are
  mapped to screen-oriented content space (`layoutOffset` runs from the
  bottom/right edge in a reversed list, so it is mirrored; a grid's
  `crossAxisOffset` is already physical), so a FLIP always travels the visible
  way and a centre-keyed sliver that did not move never animates.
* **`RepaintBoundary` (one frame late).** A `ListView` wraps every item in a
  `RepaintBoundary`, and an outer relayout can move a boundary's subtree
  without painting it, so the widget's own `paint` (where movement is
  normally detected, flash-free) never runs — and nothing may mark it dirty
  during the paint phase. `NibLayoutFrameHook` therefore re-measures, after
  each frame, every `layout:` box that did not measure itself: the move is
  animated, but the FLIP starts one frame late, so the new position shows for
  a single frame first. Pass `addRepaintBoundaries: false` (lists) to get the
  flash-free path.
* **`NibLayoutGroup` is built on the per-widget mechanism**, through
  `NibLayoutChannelMode.translate`: in that mode the position part of the FLIP
  is stored directly in the widget's own `translateX`/`translateY` (rather than
  in separate layout channels), which is exactly what `NibLayoutGroup`'s
  children expose (and what its tests assert). The widget must not animate its
  own `x`/`y` in that mode. Use the default `channels` mode for anything that
  also animates position (`animate:`, gestures, variants).
* **Without a scope**, a container that moves *relative to the top of its box
  ancestors* (not scrolling) animates its children too; add a `NibLayoutScope`
  to exclude that.
* `NibReorderable` runs along one axis and auto-scrolls only a scroll view on
  that same axis.
* Clip-mode size animation does not keep old pixels when shrinking.


## Recipe: shared `layoutId` (card expands into a detail view)

```dart
NibLayoutScope(
  child: expanded
      ? NibMotion(
          key: const ValueKey('detail'),      // a *new* widget instance…
          layout: NibLayout.both,
          layoutId: 'card-$id',                // …with the same id
          child: DetailCard(),
        )
      : NibMotion(
          key: const ValueKey('thumb'),
          layout: NibLayout.both,
          layoutId: 'card-$id',
          child: Thumbnail(),
        ),
)
```

The old instance must unmount and the new one mount within the scope's short
snapshot window (250 ms), i.e. in the same rebuild. Use different keys so
Flutter creates a new element instead of reusing the old one.

## `NibPresence.layout`: FLIP reflow in one call

```dart
NibPresence.layout(
  axis: NibPresenceAxis.wrap,      // column (default) | row | wrap
  spacing: 8, runSpacing: 8,       // wrap only
  children: [for (final t in tags) NibMotion(key: ValueKey(t.id), exit: …, child: Chip(t))],
)
```

It supplies the `NibLayoutScope`, the container, `exitLayout: pop`, and a
`NibLayoutDefaults(layout: NibLayout.position)` so children do not need
`layout:` themselves. `NibMotion.layout` defaults to `NibLayout.inherit`
(use the enclosing `NibLayoutDefaults`, else none); a child that sets `layout`
explicitly keeps it, and an explicit `NibLayout.none` **opts out** of the
default. `childLayout: NibLayout.none` turns it off for all children.
`NibLayoutDefaults` is read at creation and on rebuild; it does not subscribe.

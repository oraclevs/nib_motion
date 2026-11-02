# Migrating to NibMotion

Migrate one interaction first. Keep your existing state model, replace that
interaction's animation wiring, then test interruption, reduced motion, and
layout on the platforms you ship. NibMotion does not require an app-wide rewrite.

## From Flutter controllers and implicit widgets

| Existing approach | NibMotion approach | What changes |
| --- | --- | --- |
| `AnimationController` plus transform/opacity tweens | `NibMotion(initial:, animate:, transition:)` | Describe the target state; the widget owns its drivers. |
| An implicit widget such as `AnimatedContainer` | `NibMotion` for paint properties; `NibValueBuilder` for layout values | Paint transforms leave layout unchanged. Padding and real size changes still require layout. |
| A custom spring simulation | `SpringSolver`, `MultiSpringSolver`, or `NibSimulationDriver` | Drive `MotionValue`s and retain explicit ownership of solvers. |
| Removing a widget after an animation | `NibPresence` plus keyed `NibMotion(exit:)`, or `NibVisibility` | Presence retains the exiting child and excludes it from input, focus, and semantics. |
| A route hero transition | `NibPageRoute(sharedFrom:)` or `showNibDialog(sharedFrom:)` | Route hand-off uses a mounted source key; `layoutId` instead uses a recently unmounted owner in one scope. |
| A scroll listener that calls `setState` | `ScrollMotionBridge` plus derived values in `NibMotionValues` | The core render object can repaint from the values. Dispose the bridge and derived values. |

`initial` applies at mount. Updating `animate` retargets the current widget.
A spring taking over can inherit velocity; a tween cannot honor an initial
velocity. `controller.stop()` freezes at rest. The
[interruption contract](interruption.md) covers the differences between drivers.

## From Flutter Animate

[Flutter Animate](https://pub.dev/packages/flutter_animate) has concise chained
effects, effect timelines, adapters, and shader support. Its `target` and
`ScrollAdapter` also support state-driven and scroll-driven use cases. You do
not need to replace an effect chain that already fits your interface.

In NibMotion, combine paint targets in one `NibAnim`, choose a `NibTransition`,
and update `animate` when application state changes. Use `variants` for named
states, `NibMotionList.staggerDelay` for list entrances, and `NibTimeline` or
`NibAnimationSequence` for orchestration. Keyframes use a duration-based clock;
a `NibKeyframe.spring` supplies spring-shaped easing for one segment.

The practical reason to evaluate NibMotion is using the same motion values and
state targets across gestures, layout, presence, scrolling, and imperative
control. This is an architectural choice, not a benchmark claim.

## From Motor

[Motor](https://pub.dev/packages/motor) provides physics-driven controllers,
builders, converters, sequences, and dragging. Its controllers preserve velocity
when retargeting. Springs and velocity continuity are shared strengths.

Map a `MotionController`-driven value to `MotionValue` plus a solver when you
need low-level control. Use `NibValueBuilder` for a builder that changes layout,
or `NibMotion` for transform/opacity paint updates. Composite values use
`MotionConverter` and `MultiSpringSolver`; controller APIs are not drop-in
replacements, so check units and ownership when migrating.

## From Fluid Motions

[Fluid Motions](https://pub.dev/packages/fluid_motions) focuses on interaction
wrappers, dragging, transforms, and spring-driven containers. Its interaction
and drag helpers can suit a compact effect around an existing widget.

Map interaction targets to `whileTap`, `whileHover`, and `whileDrag` on
`NibMotion`. Use `NibDragConfig` for bounds, release modes, and snap points, or
`NibDraggable` for an offset-oriented wrapper. NibMotion's broader layout,
presence, scroll, and orchestration APIs are separate adoption steps.

## From a layout or timeline package

Use [per-widget layout](layout.md) for position, scale or clip size FLIP,
shared `layoutId`, and mounted lazy-list items. `NibLayoutGroup` is a keyed
`Column`; it is not a generic grid wrapper. `NibReorderable` handles drag
reordering along one axis. Offscreen items and perspective geometry have
explicit limits.

Use [relative timelines and scrubbing](timeline.md) for labels, overlap,
`seek`, `NibTimelineScrubber`, and `NibTimelineDragScrubber`. Scrub progress is
separate from `play()`; cancelled pending entries can leave that run's future
unresolved. Check this contract before replacing existing cancellation logic.

## Before merging a migration

Run the same interaction before and after the change. Retarget while it is
moving, release a drag quickly, remove and re-add a presence child, and enable
reduced motion. Check hit targets after transforms and test the renderer's
shader fallback. See [compatibility](compatibility.md),
[troubleshooting](troubleshooting.md), and the [runnable examples](../example/README.md).

Comparison reviewed against Flutter Animate 4.5.2, Motor 1.1.0, and Fluid Motions
0.0.5 on 2026-11-02. See the [positioning research](maintainers/positioning.md)
for source references. Consult each package's current documentation when you
migrate; this guide does not claim feature parity or performance superiority.

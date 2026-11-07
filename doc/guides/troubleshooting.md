---
{
  "id": "troubleshooting",
  "evidence": "MotionNib/motion/lib/src/core/nib_motion_widget.dart; MotionNib/motion/lib/src/layout/nib_layout_scope.dart; MotionNib/motion/CHANGELOG.md"
}
---

# Troubleshooting

Trace a still or misplaced animation to state, identity, and space.

<!-- section: known-runtime-limits -->
## Known runtime issues under review

The gallery audit reproduced a second-ticker assertion when reduced motion is toggled repeatedly around NibGradientText. It also observed NibPathMotion pause/play restarting the clock, and opaque shimmer children covering the sweep. These are reported separately from website navigation and copy-code checks. No library patch is hidden in this documentation change.

NibGlass can use a frosted fallback in the browser. That is supported behavior, not evidence of shader refraction. NibTextReveal accepts a controller but the current implementation does not attach it; remounting replays the reveal and also resets local State.

[Review the gallery audit and reproductions](https://github.com/oraclevs/nib_motion/blob/v0.3.6/doc/maintainers/showcase-audit.md)

<!-- section: triage -->
## Reduce the problem to one moving child

First put a single NibMotion around a fixed-size child with an obvious initial and animate difference, such as opacity zero to one. If that moves, restore the original interaction one layer at a time: parent state, presence, scope, scrolling parent, clip, and transforms. At each step write down whether the child built with a new key, changed its target, or changed only paint. This separates a missing state update from a geometry problem.

A spring’s duration and curve do not determine its settling. If motion seems late, inspect the transition’s spring, delay, and any entrance gate. If a controller command does nothing, verify that the NibMotion using it is mounted and attached when start() runs. A controller can be shared across widgets, so a surprising extra animation may mean another child is attached to the same handle.

<!-- section: still -->
## When nothing moves

First check that animate differs from the current value, reduced motion is not active, and the entrance gate has released. A first-frame entrance can wait during the default warm-up; a later state change should still retarget. Inspect the resolved NibTransition: a spring ignores duration and curve.

<!-- section: identity -->
## When a child jumps or exits at the wrong time

List and presence behavior depend on stable unique keys. A new key remounts a child and can replay its entrance. A missing exit state removes a NibPresence child immediately. For shared layoutId handoff, keep both endpoints in the same NibLayoutScope and do not expect two live widgets with one ID to morph between each other.

<!-- section: layout-debug -->
## Trace layout and exit errors

When a reordered item travels from the wrong place, print its data ID and key before looking at timing. Stable data keys are essential. Keep the old and new layoutId endpoints under one NibLayoutScope; the old endpoint must detach shortly before the new one mounts. Two live widgets with the same layoutId do not create a morph. If a size transition stretches text, try clip mode and accept that it reveals final-layout content rather than preserving the old pixels.

When an exit never appears, check that the removed direct child has a unique non-null key and an exit target, or that the container supplies an exit override. With the base NibPresence constructor, also supply layoutBuilder when a list should lay out as a Row or Column; its default is Stack. Check exitLayout: sync holds the slot, whereas pop releases it immediately. On re-addition during an exit, the same key returns to the active flow.

<!-- section: graph -->
## When a copied example does not compile

Check the package version and Flutter SDK in pubspec.lock, then compare the public constructor with the API browser for that version. These Motion guides target the hosted 0.3.5 API. Prefer the public barrel and run the example in a small app against the same dependency graph.

<!-- section: finish-debug -->
## Verify the fix at the boundary

After changing code, repeat the failing sequence with a rapid second change and with disposal during motion. Record numeric painted position and hit target when geometry was the symptom; record callback order when lifecycle was the symptom. If the failure occurs only on a device or browser, include its renderer, Flutter version, and a short capture. A passing debug widget test does not establish a GPU or physical-touch result.

For a callback that fires too early or never fires, identify which animation owns it. A child entrance, a layout FLIP, a presence exit, and an aggregate presence batch have different completion rules. Record the old and new keys, mounted status, target values, and event order in one minimal reproduction. That log usually narrows the failure faster than changing transition duration at random.

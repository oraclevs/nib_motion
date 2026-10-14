# API feedback from building the demo screens

Awkward spots hit while dogfooding (nothing here was worked around by touching
`lib/`). Ordered roughly by how much friction they caused.

1. **No declarative way to read a `NibMotion`'s velocity.** To show live
   velocity (Interruption screen) the demo had to drop to `SpringSolver` +
   `MotionValue` + a `TickerProviderStateMixin` and feed it through
   `NibMotionValues`. Suggest exposing a read-only handle (e.g. a
   `NibMotionController.velocityOf(property)` or `MotionValue`s via the
   controller).
2. **`MotionValue<Offset>` cannot drive `NibMotion`.** `NibMotionValues` only
   takes scalar channels, so the multi-axis demo needed
   `ValueListenableBuilder` + `Positioned` (a rebuild per frame). An
   `offset`-typed adapter (writes `translateX/Y`) would keep it paint-only.
3. **`NibMotion.initial` is read once.** Changing it on a rebuild is silently
   ignored (found while testing blur). A debug-mode assert or doc line on the
   field would save time.
4. **Timeline scrubbing needs `from:` on every entry and a matching
   `NibMotion.initial`,** so the hidden state is written twice (Timeline
   screen). Deriving `from` from the target widget's `initial` would remove
   the duplication.
5. **`layoutId` shared transitions depend on a new widget instance**, so the
   collapsed and expanded cards need different keys, and the swap must happen
   within the scope's 250 ms window. Easy to get wrong; a short recipe in
   `doc/layout.md` (or a `NibSharedLayout` helper) would help.
6. **Drag geometry is relative to the resting position.** `constraints`
   (`Rect.fromLTRB(-120, 0, 120, 0)`) and `snapPoints` (`Offset(120, 0)`) are
   offsets from where the drag started, which surprises people who expect
   absolute coordinates. Worth stating on `NibDragConfig`'s field docs.
7. **Two spellings for the same spring→transition step:**
   `NibSpring.smooth.transition` (extension) vs
   `NibTransition.springWith(duration:, bounce:)`, and tokens are
   `NibSpringDescription` values, so `NibMotion(transition: NibSpring.smooth)`
   does not compile. Accepting either type where a transition is expected
   would be smoother.
8. **`NibTimelineScrubber` imports Material,** so the otherwise widgets-only
   core now has a Material dependency on that one file.
9. **`NibPresence` layout needs three pieces** (`NibLayoutScope`,
   `layoutBuilder`, per-child `layout:`) to get FLIP reflow. A named
   constructor for the common Wrap/Column case would cut the ceremony.


## Resolution (API friction pass)

1. **Resolved**: `NibMotionController.velocityOf(NibProperty)`, `.velocities`,
   `.motionValueOf(NibProperty)` (live, listenable `MotionValue`).
2. **Resolved**: `NibMotionValues(offset:)` and `NibOffsetMotionValue`; paint-only.
   Explicit `translateX/Y` win per axis.
3. **Resolved**: debug-mode `debugPrint` once per widget when `initial` changes
   (an assert would break apps that legitimately rebuild with new values); the
   field docs also say so.
4. **Resolved**: `NibTimelineEntry.from` is derived when omitted (previous entry
   target, else the widget's `initial`).
5. **Partly resolved**: recipe added to `doc/layout.md`; the new-instance
   requirement itself is unchanged.
6. **Resolved (docs)**: `NibDragConfig` field docs state offsets are relative.
7. **Resolved**: `NibTransition.of(spring)` and `NibMotion(spring:)`.
8. **Resolved**: `NibTimelineScrubber` no longer imports Material.
9. **Resolved**: `NibPresence.layout(...)` + `NibLayoutDefaults`.

## Second round (new screens: routes, sliver, velocity, presence layout, size modes, value builder, progress, transitions, simulation)

1. **`NibSpring.*` tokens are `static final`, not `const`.** They cannot appear in
   `const` keyframe lists or const widget trees (`NibKeyframe(spring: NibSpring.bouncy)`
   forced dropping `const` on the whole list). `const` tokens would need literal
   mass/stiffness/damping rather than `fromDuration`.
2. **`NibValueBuilder.withChild` names its callback `childBuilder`,** not `builder`,
   so the two constructors look alike but aren't drop-in swappable.
3. **`controller.motionValueOf(...)` is `null` until the first frame.** A live
   velocity readout needs a post-frame `setState` to pick it up; a
   `ValueListenable<MotionValue?>` or `NibMotion.onAttached` would avoid that.
4. **Velocity of a dragging `NibMotion` is 0 while the finger is down** (drag
   writes are jumps). Only the release handoff and later drivers publish
   velocity, which is correct but surprising in a readout.
5. **`NibPresence.layout` inside a scroll view needs `Align`/`SingleChildScrollView`
   plumbing by the caller,** and changing `axis` needs a new `key` to rebuild the
   container; an `axis` change is otherwise ignored by retained children.
6. **`GravitySimulation` ends when `x >= end`,** so a bounce (upward leg) has to
   start 1px above the floor or it is already done. `NibSimulationDriver` could
   accept an optional `onEnd(velocity)` so callers do not recompute the impact
   speed analytically.

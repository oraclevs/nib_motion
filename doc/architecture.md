# Architecture

NibMotion is one runtime with several front doors.

```
 State / props        Gestures        Scroll        Layout        Presence
 (animate, variants)  (drag, tap…)    (bridge)      (FLIP)        (exit)
        \                 |              |             |             /
         └────────────────┴──────┬───────┴─────────────┴────────────┘
                                 ▼
                    MotionValue<T>  (value + velocity)
                     │  mapRange / transform / computed
                     ▼
        Drivers: SpringSolver · InertiaSolver · tween · drag
                     │   (publish velocity, resolve futures on supersede)
                     ▼
                  Ticker frames
                     ▼
     RenderNibMotion.paint  ←  markNeedsPaint (never a rebuild)
```

## The rules the code follows

1. **Values are the hub.** Every animatable property is a `MotionValue`.
   Anything that moves something writes a `MotionValue`; anything that draws
   listens to one. Gestures, scroll and layout do not have private animation
   engines.
2. **Animating never rebuilds.** A `MotionValue` change calls `markNeedsPaint`
   on the render object. `test/runtime/no_rebuild_test.dart` guards this.
3. **Velocity is state.** `MotionValue.velocity` is written by whichever driver
   moved the value last, and read by whichever driver starts next. See
   [interruption.md](interruption.md).
4. **Coordinate spaces match paint.** `RenderNibMotion`, `NibDraggable` and
   `NibPinch` paint through a transform *and* report it via
   `applyPaintTransform`/hit testing (`PaintTransformHitTest`), so
   `localToGlobal`, FLIP measurement and taps agree with what is on screen.
5. **One accessibility policy.** `NibMotionConfig.shouldReduceMotion` /
   `watchReducedMotion` decide; widgets never read `MediaQuery` themselves.
   See [accessibility.md](accessibility.md).
6. **Composition over new engines.** Layout, presence, variants and gestures
   are built from `NibAnim` targets + `NibTransition` drivers on `NibMotion`.

## Progressive complexity

| You need | Use |
|---|---|
| Fade/slide on mount or state change | `NibMotion(initial:, animate:)` |
| Interaction states | `whileTap`, `whileHover`, `whileFocus`, `whileDrag` |
| Coordinated children | `variants` + `NibTransition.staggerChildren` |
| Mount/unmount | `NibPresence` + `exit` |
| Reorders | `NibLayoutGroup` |
| Imperative control | `NibMotionController` |
| Reactive graphs | `MotionValue`, `mapRange`, `MotionValue.computed`, `NibMotionValues` |
| Physics directly | `SpringSolver`, `InertiaSolver` |
| GPU | `NibShimmer`, `NibDissolve`, `NibGlass` (uniforms fed by `MotionValue`) |

## Extension packages

None are justified yet. Everything above shares one runtime and ships in
`nib_motion` (zero dependencies). `nib_components` builds on it as a normal
package. A separate devtools package only makes sense once the debugger needs a
dependency (e.g. `devtools_extensions`); until then `NibMotionDebugger` stays in
core.

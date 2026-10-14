# Accessibility and reduced motion

One policy, one place: `NibMotionConfig` (`lib/src/core/reduced_motion.dart`).

Resolution order: `NibMotionConfig.setReducedMotion(bool?)` (tests) →
nearest `NibMotionConfig.reducedMotion` → `MediaQuery.disableAnimations`.

```dart
NibMotionConfig(reducedMotion: null /* follow the OS */, child: MyApp())
```

Widgets call `shouldReduceMotion(context)` at the moment they start motion, or
`watchReducedMotion(context)` (subscribing) when they need to react to changes
while mounted.

## What "reduced" means

Essential feedback stays; decorative or settling motion jumps to its end state
without starting a ticker.

| Widget | Reduced behaviour |
|---|---|
| `NibMotion` | targets applied immediately; loops jump to the end of the cycle |
| `NibDraggable`, `NibPinch`, `NibMotion.drag` | finger-following unchanged; release/snap-back jumps |
| `NibSwipeDismiss` | returns/dismisses instantly (`onDismissed` still fires) |
| `NibShimmer`, `NibGradientText` | static frame, no ticker |
| `NibTextReveal`, `NibTypewriter` | full text at once (`onComplete` fires once) |
| `NibDrawPath`, `NibPathMotion`, `NibFlip`, `NibDissolve` | jump to the final state |
| `NibNavBar` | indicator and item state jump |

`test/runtime/reduced_motion_test.dart` asserts both the end state and that no
ticker is left running (`transientCallbackCount == 0`).

`NibTimeline` has no `BuildContext`; its entries run through `NibMotion`
controllers, which honour the policy. Only the entry *timers* still elapse.

## Switching it on while animating

`NibMotion` re-checks the policy when `MediaQuery.disableAnimations` or an
enclosing `NibMotionConfig.reducedMotion` changes (`didChangeDependencies` via
`watchReducedMotion`). When it flips to *reduced* mid-flight, every running
spring/tween lands on its target, pending delays apply immediately, keyframes
jump to their last frame, a repeat loop stops at the end of its cycle, and the
in-flight futures resolve. Turning reduced motion back off restarts nothing.
(`test/runtime/hardening_reduced_motion_test.dart`.)

## `NibVisibility`

Single-child show/hide with enter/exit animation; reduced motion removes the
child immediately, and an exiting child ignores pointers and is excluded from
semantics and focus. Exit target and timing are read from the hide build, so
changing them while hiding takes effect immediately.

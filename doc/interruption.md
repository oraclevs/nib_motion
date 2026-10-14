# Interruption semantics

What happens when an animation is interrupted is part of the public contract.

## Position and velocity are continuous

A new animation on a property starts from that property's **current value and
current velocity**, regardless of which driver was running before:

| Interrupted | By | Result |
|---|---|---|
| spring | spring | continues with the spring's velocity |
| tween | spring | spring starts with the tween's instantaneous velocity |
| inertia / drag release | spring | spring starts with the coast velocity |
| spring | tween | tween starts from the current value (a tween cannot honour an initial velocity) |
| anything | `setImmediately` / plain `value =` | a *jump*: velocity resets to 0 |
| anything | `controller.stop()` | frozen at the current value, velocity 0 |
| FLIP in flight | new layout change | continues from the **painted** position, velocity kept |

The mechanism is `MotionValue.velocity`: drivers publish it with
`MotionValue.update(v, velocity: …)`; `SpringSolver.animateTo` reads it when no
explicit `initialVelocity` is passed. Springs settle *exactly* on the target
with velocity 0.

```dart
final x = MotionValue<double>(0);
final spring = SpringSolver(vsync: this, value: x, spring: NibSpringDescription.gentle);

spring.animateTo(target: 300);
// ~100 ms later, mid-flight:
spring.animateTo(target: 0); // starts at x.value with x.velocity — no restart from rest
```

## Futures and callbacks

Every `animateTo` / `controller.start` future **completes when the animation
settles or is superseded/stopped**. It never errors and never hangs, so code
awaiting an exit or a sequence step cannot deadlock on an interruption.

* `SpringSolver.onComplete` / `InertiaSolver.onComplete` fire only on natural
  settling.
* Widgets disposed mid-animation resolve their futures too;
  `NibMotionController` does not notify after it was disposed.

## Newest target wins

A delayed animation (`NibTransition(delay: …)`) that has not started yet is
cancelled when a later `animateTo` touches any of the same properties, so a
stale delayed target cannot fire after a newer one.

## Presence

Re-adding a child while its exit is playing cancels the removal and animates it
back to its resting state (`animate`, else `initial`, else identity) from
wherever the exit had got to.

## Tests

`test/runtime/interruption_test.dart`, `presence_lifecycle_test.dart`,
`flip_interruption_test.dart` and the numeric trajectory goldens in
`test/runtime/goldens/` pin these behaviours.

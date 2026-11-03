---
{
  "id": "physics",
  "evidence": "MotionNib/motion/lib/src/physics/spring_description.dart; MotionNib/motion/lib/src/physics/spring_solver.dart; MotionNib/motion/lib/src/physics/inertia_solver.dart"
}
---

# Physics drivers

Understand the spring and inertia engines below the widgets.

<!-- section: choose-spring -->
## Tune a spring without guessing duration

A spring travels according to position, velocity, and its mass, stiffness, and damping. Greater stiffness pulls harder; greater mass resists acceleration; damping removes energy and reduces overshoot. NibSpringDescription requires positive finite mass and stiffness and non-negative finite damping. Start with gentle, snappy, wobbly, or stiff before choosing raw numbers. fromDuration accepts a perceptual duration and bounce between -1 and 1; it converts them into a spring rather than imposing a hard animation deadline.

For an ordinary widget, pass the description through NibTransition(spring: ...). The spring determines settling, so a duration and curve on that transition do not control its path. Open spring-retarget and move the target again before the first run settles. Observe that the value continues from its current position and velocity instead of jumping back to the original start. Compare that with spring-tween, where a tween’s duration and curve define a fixed time path.

```dart
// In build(); moved is a bool held by State.
NibMotion(
  animate: moved
      ? const NibAnim(x: 120)
      : const NibAnim(x: 0),
  transition: const NibTransition(
    spring: NibSpringDescription.gentle,
  ),
  child: const Icon(Icons.circle),
)
```

<!-- section: spring -->
## Describe a spring

NibSpringDescription stores mass, stiffness, and damping and converts them to Flutter’s SpringDescription. Its defaults are 1, 100, and 10. Use the named gentle, snappy, wobbly, or stiff descriptions, or fromDuration for a perceptual duration and bounce.

Most applications only need NibTransition(spring: ...). SpringSolver is the lower-level driver when you already own a MotionValue<double> and a TickerProvider.

<!-- api -->
| Name | Type | Default | Description |
| --- | --- | --- | --- |
| mass | double | 1.0 | Positive finite inertia. |
| stiffness | double | 100.0 | Positive finite pull toward the target. |
| damping | double | 10.0 | Non-negative finite resistance. |

<!-- section: driver-contract -->
## Use direct drivers only when you own the value

SpringSolver accepts a TickerProvider, MotionValue<double>, and spring description. animateTo takes a target in the same units as that value; an optional from resets the start position, while initialVelocity is in those units per second. With no override it can inherit MotionValue.velocity across retargets. Its Future completes on settlement, supersession, stop, or dispose. The completion callback is for natural settlement, so do not use it as the only cleanup path after cancellation.

InertiaSolver starts from the current value with a velocity, not a destination. Its optional min and max bounds can make it coast past an edge and spring back. drag defaults to 0.135; higher values closer to one coast farther. Keep local positions and local velocities in the same coordinate system before feeding either driver. For a drag receiver, 0.3.5 reports release velocity in receiver-local logical pixels per second. A global pointer velocity sent into a local simulation can produce a visibly wrong trajectory.

<!-- section: drivers -->
## Drive a value directly

SpringSolver.animateTo moves a MotionValue toward a target and can carry velocity across a retarget. InertiaSolver uses a FrictionSimulation; its drag parameter defaults to 0.135 and animateTo starts with a supplied velocity. Both drivers expose stop and dispose.

Keep velocity and position in matching units. The 0.3.5 drag path reports receiver-local logical pixels per second; do not feed a global pointer velocity into a local offset simulation without converting it.

<!-- section: driver-exercise -->
## Test interruption and disposal

Create a MotionValue<double> in State and drive it with a SpringSolver using that State’s TickerProvider. Animate to one target, retarget midway, then call stop and inspect value and velocity. Dispose both solver and value when the owner leaves. Repeat with InertiaSolver and a bounded range, including a release just beyond the bound. Compare the final value with the edge; it should settle there after overshoot.

This direct-driver exercise is useful when you need a value that is not naturally a NibMotion property. For a normal button, card, or route, the widget API already owns the ticker and property values. Prefer that higher-level path unless a measured use case requires independent simulation control.

<!-- section: lifecycle -->
## Own the low-level lifecycle

A direct driver needs a TickerProvider, an owned MotionValue, and explicit disposal. Do not keep a ticker alive after its route leaves. Test cancellation and rapid retargeting as well as the single uninterrupted path.

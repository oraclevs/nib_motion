---
{
  "id": "springs",
  "evidence": "MotionNib/motion/lib/src/physics/spring_description.dart; MotionNib/motion/lib/src/physics/spring_solver.dart; MotionNib/motion/lib/src/core/nib_transition.dart; MotionNib/motion/lib/src/core/nib_motion_controller.dart; MotionNib/motion/lib/src/core/nib_motion_widget.dart"
}
---

# Springs and interruption

Keep an interaction responsive when its destination changes. Learn the spring model, tune its response, and handle interruption correctly.

<!-- section: mental-model -->
## Spring model

A spring follows a destination from its current position and velocity. Use it for selection indicators, draggable objects, or panels that can reverse while moving. The user can change their mind before the animation finishes. A timed transition is a better fit when several events must occupy fixed intervals.

Stiffness pulls toward the target, damping resists motion, and mass changes inertia. The solver advances a Flutter SpringSimulation on a ticker and writes the result into a MotionValue. The simulation settles at a numerical tolerance; it does not have a guaranteed millisecond finish time.

NibTransition uses a spring when spring is non-null. Its duration and curve do not control that spring movement. Keyframe sequences have a different timed contract; see Keyframes before mixing the two models.

[Compare timed transitions](transitions.md)

<!-- section: initial-target -->
## Initial state and target

Create a Flutter app and add nib_motion. This complete example needs no website helpers or assets. NibMotion starts at initial and responds when animate changes. Keep the same widget key so a new target reaches the running animation instead of replacing its state.

Press Change target, then press it again before the square arrives. The square reverses from its current position. The reserved 260-pixel lane leaves room for the 160-pixel travel and square. A transform changes the painted position without reserving a new layout slot.

[Installation and package versions](installation.md)

```dart
import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

void main() => runApp(const MaterialApp(home: SpringLesson()));

class SpringLesson extends StatefulWidget {
  const SpringLesson({super.key});
  @override
  State<SpringLesson> createState() => _SpringLessonState();
}

class _SpringLessonState extends State<SpringLesson> {
  bool right = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: 260, height: 96, child: Align(
        alignment: Alignment.centerLeft,
        child: NibMotion(
          initial: const NibAnim(x: 0),
          animate: NibAnim(x: right ? 160 : 0),
          transition: const NibTransition(spring: NibSpringDescription(
            mass: 1, stiffness: 180, damping: 18,
          )),
          child: const SizedBox(width: 48, height: 48,
            child: ColoredBox(color: Colors.amber)),
        ),
      )),
      FilledButton(
        onPressed: () => setState(() => right = !right),
        child: const Text('Change target'),
      ),
    ])),
  );
}
```

<!-- section: parameters -->
## Parameters

Change one coefficient while keeping the target distance constant. More damping reduces oscillation; higher stiffness usually makes the response start faster. Mass affects both acceleration and settling, so changing it can also change overshoot. Values are simulation coefficients, not measurements of a physical object on screen.

The constructor validates finite values in debug mode. Mass and stiffness must be positive; damping may be zero. Zero damping can keep an animation oscillating and is unsuitable when later work waits for settlement. toFlutter substitutes safe defaults for invalid unchecked values in release mode; validate external settings before constructing the description.

<!-- api -->
| Name | Type | Default | Description |
| --- | --- | --- | --- |
| mass | double | 1.0 | Positive, finite inertia coefficient. |
| stiffness | double | 100.0 | Positive, finite attraction coefficient. |
| damping | double | 10.0 | Finite resistance coefficient, greater than or equal to zero. |

<!-- section: choose-values -->
## Presets and configuration

Use a named description as a starting point. These are actual NibSpringDescription constants. The preview’s Balanced option is a local recipe setting of mass 1, stiffness 180 and damping 18; it is not another package preset.

NibTransition(spring: description), NibTransition.of(description), and NibMotion(spring: description) select a spring. Do not supply both NibMotion.spring and NibMotion.transition. NibTransition.springGentle, springSnappy and springWobbly are convenient constants.

NibTransition.springWith(duration: ..., bounce: ...) converts a perceptual duration and bounce into coefficients at mass 1. Defaults are 500 ms and bounce 0. Duration must be at least 1 ms; bounce is strictly between -1 and 1. Zero bounce is critically damped; positive values oscillate; negative values are overdamped. Perceptual duration is not a completion deadline.

| Description | Mass | Stiffness | Damping |
| --- | --- | --- | --- |
| gentle | 1 | 120 | 14 |
| snappy | 1 | 300 | 20 |
| wobbly | 1 | 180 | 12 |
| stiff | 1 | 400 | 28 |

```dart
final response = NibTransition.springWith(
  duration: const Duration(milliseconds: 450),
  bounce: 0.25,
);
// Or: const NibTransition(spring: NibSpringDescription.gentle)
```

<!-- section: retarget -->
## Retargeting

Changing animate on the same NibMotion retargets its active values. A SpringSolver starts from the current MotionValue position and carries its velocity unless another starting state is supplied. Do not replace the widget key or reconstruct an externally owned MotionValue for each target change.

The playground lets you change distance and all three coefficients. Press Send right and then Send left while the tile is still moving. You should see a continuous reversal. Higher damping can make that reversal less oscillatory, but it does not make the target change instantaneous.

1. Try the default response, then reverse it mid-flight.
2. Increase damping and repeat the same gesture.
  - Keep distance and stiffness unchanged so the comparison has one variable.
  - Watch the path immediately after reversal and the final settling response.
3. Enable reduced motion and repeat; the chosen destination must remain clear.

[Open mid-flight spring retarget](https://www.nibmotion.xyz/playground/spring-retarget)

<!-- section: experiment -->
## Velocity

NibMotionController.velocityOf(NibProperty.x) reads the current x velocity in logical pixels per second. Other properties use their own value units per second. This is a live value, not a screen refresh-rate or performance measurement.

For direct SpringSolver use, a nonzero initialVelocity overrides inherited velocity. The current API treats initialVelocity: 0 as the default: with no from value it still inherits MotionValue.velocity. To start at rest deliberately, pass from: value.value or reset the value’s velocity. This distinction matters when switching from a drag or another driver.

Calling controller.set(target) jumps immediately and resets property velocity unless keepVelocity is true. Use it for a deliberate snap or reset, not for ordinary continuous retargeting.

[Motion values and driver ownership](motion-values.md)

<!-- section: completion -->
## Completion and cancellation

Awaiting SpringSolver.animateTo or NibMotionController.start waits until its operation resolves. Resolution also happens when motion is superseded, stopped, or its widget is disposed. The Future alone does not prove that the requested target was reached.

SpringSolver.onComplete runs when that simulation settles. A controller listener is a general change notification and can also run after set or stop. Keep business state separate from animation state; do not use a notification as proof that a save, upload, or purchase succeeded.

If asynchronous UI work follows a start call, check mounted and a request generation after awaiting. Increment the generation on a new request or stop. For workflows that require arrival, also verify the current target and position or use the appropriate driver completion callback.

> An animation completing is presentation feedback. Application success must come from application state.

<!-- section: spring-mistakes -->
## Ownership and lifecycle

The minimal declarative example needs no controller: NibMotion owns and disposes its internal drivers. For imperative control, create NibMotionController once in State, pass it to the widget, and dispose it with that State. Recreating a controller in build loses the existing attachment.

controller.stop freezes attached properties at their current values. Retained velocity can be reused by the next spring; set the same position without keepVelocity when you want a fresh start. If you create a SpringSolver and MotionValue yourself, stop and dispose the solver first, then dispose the value and any derived listeners you own.

An offscreen ticker, a disposed widget and a paused preview have different lifecycle meanings. Test route departure and rapid repeated input. Do not assume that hiding a widget has disposed an external driver.

[Controller start, set, stop and sequence](controllers.md)

<!-- section: safety -->
## Accessibility

NibMotion respects the system reduced-motion setting and NibMotionConfig. With reduced motion enabled, its target is applied immediately. Keep labels, focus and the final selected state useful without travel or overshoot. The recipe’s buttons provide a keyboard and touch alternative to dragging.

The documentation stays still while you read. Replay starts an intentional demonstration; Pause and Reduce motion are separate choices. Test the final state with motion disabled before relying on movement to communicate meaning.

[Reduced motion and accessible feedback](accessibility.md)

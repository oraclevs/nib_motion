---
{
  "id": "controllers",
  "evidence": "MotionNib/motion/lib/src/core/nib_motion_controller.dart; MotionNib/motion/lib/src/core/nib_motion_widget.dart"
}
---

# Controllers

Drive one or more NibMotion widgets from an imperative event.

<!-- section: ownership -->
## Create the handle in State

NibMotionController attaches to each NibMotion receiving it. The same controller can drive several widgets. Create it in the owning State, pass it through controller, and dispose it in State.dispose; NibMotion does not take ownership of the external handle.

```dart
class FadeLogo extends StatefulWidget {
  const FadeLogo({super.key});
  @override
  State<FadeLogo> createState() => _FadeLogoState();
}

class _FadeLogoState extends State<FadeLogo> {
  final controller = NibMotionController();

  @override
  Widget build(BuildContext context) => Column(children: [
    NibMotion(controller: controller, child: const FlutterLogo()),
    TextButton(
      onPressed: () => controller.start(
        target: const NibAnim(opacity: 0),
      ),
      child: const Text('Fade'),
    ),
  ]);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
```

<!-- api -->
| Name | Type | Default | Description |
| --- | --- | --- | --- |
| controller | NibMotionController? | null | Externally owned handle attached to this widget. |
| dispose() | void | caller action | Release the external controller from the owning State. |

<!-- section: walkthrough -->
## Follow one command from button to pixels

In the example, State owns the controller for as long as the route owns the button and logo. NibMotion attaches its animator during its lifecycle. Pressing Fade asks each attached widget to animate toward opacity zero and returns a Future that completes when the animation settles or is superseded. The callback is a command result, not a guarantee that the widget is still on screen when it resolves. Check mounted before changing State after awaiting it.

set(target) jumps to the target immediately. By default it clears each property’s velocity; keepVelocity: true preserves momentum for a following start. stop() freezes the current values and resolves the pending animation Future. motionValueOf(property) reports the first attached widget’s live value, so it is unsuitable as an aggregate reading when one controller drives several children. velocityOf reports units per second for that property.

<!-- section: commands -->
## Choose the right command

start(target:) animates to a NibAnim; start(keyframes:) plays one keyframe sequence; start() replays the widget’s entrance. Only one of target and keyframes may be supplied. set applies a target immediately, stop freezes the current values, and repeat toggles the loop.

sequence runs NibMotionSequenceStep values in order, waiting for each animation and optional wait before the next step. The returned Future is useful for ordering work. A spring can look settled before its Future resolves.

<!-- api -->
| Name | Type | Default | Description |
| --- | --- | --- | --- |
| start() | Future<void> | replay entrance | Optionally take target or keyframes, never both. |
| set(target) | void | none | Apply a NibAnim immediately. |
| stop() | void | none | Freeze attached widgets at current values. |

<!-- section: sequence-caveat -->
## Coordinate sequences with the host lifecycle

NibMotionSequenceStep has a required target, an optional transition, and an optional wait after that step. sequence awaits each start and wait in order. The implementation does not expose a separate sequence-cancellation token: stop resolves the current animation but the sequence can continue to its next step. If the screen may leave midway, keep a host generation or mounted check around the orchestration and do not assume stop cancels future steps.

Exercise this with two steps: fade to 0, wait briefly, then fade to 1. Trigger the sequence twice quickly and navigate away during the wait. Decide whether overlapping requests should be ignored, restarted, or serialized in your screen logic. Dispose the controller in State.dispose. A controller whose widget detached has no pixels to drive, and a disposed controller should not be reused by a newly mounted screen.

Calling start with no target and no keyframes replays the attached widget’s entrance. Calling it with both target and keyframes violates the API assertion. When several widgets share the controller, start returns after all attached animators’ Futures resolve, so the slowest one determines when an await continues. Keep the controller scoped to widgets that should genuinely move together; use separate handles when independent cancellation or timing matters. If no widget is attached yet, start has nothing to drive.

<!-- section: scope -->
## Prefer declarative state for ordinary changes

A changing animate value is enough for most UI state. Reach for a controller when the host must replay, stop, or coordinate a sequence from an external event. If a controller is replaced, the old one detaches; dispose any controller no longer owned by the screen.

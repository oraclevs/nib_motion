---
{
  "id": "motion-values",
  "evidence": "MotionNib/motion/lib/src/values/motion_value.dart; MotionNib/motion/lib/src/values/derived_motion_value.dart; MotionNib/motion/lib/src/core/nib_motion_values.dart"
}
---

# Motion values

Connect changing data directly to paint properties.

<!-- section: put-values-in-state -->
## Create values once in State

Put the progress MotionValue in a State field, not inside build. Build can run for unrelated reasons; creating a new value there would discard the current position and leave old listeners behind. Create the two derived values from that source in fields or initState. The live example starts progress at 0.5, so x begins halfway between -62 and 62 and opacity halfway along 0.3 to 1.

In build, pass those derived objects to NibMotionValues(translateX: x, opacity: opacity). The render layer listens to the values. A Slider can use a ValueListenableBuilder to display the current thumb value; its onChanged writes progress.value. That ValueListenableBuilder rebuilds the slider for its label, while the animated child’s paint path does not need a new child build on every progress update.

<!-- section: source -->
## Create one source value

MotionValue<T> is a ValueListenable and ChangeNotifier. Setting value notifies listeners synchronously when the value changes; assigning the same value sends no notification. A plain assignment resets recorded velocity to zero. The live slider owns one MotionValue<double> and sets it from user input.

Use transform for a general mapping or mapRange for piecewise linear numeric mapping. mapRange needs at least two stops and clamps outside the input range by default. Its result is another MotionValue that updates when the source changes.

```dart
final progress = MotionValue<double>(0.5);
final x = progress.mapRange([0, 1], [-62, 62]);
final opacity = progress.mapRange([0, 1], [0.3, 1]);
```

<!-- api -->
| Name | Type | Default | Description |
| --- | --- | --- | --- |
| value | T | constructor initial | Notifies listeners synchronously when it changes. |
| transform | DerivedMotionValue<S, T> | none | Map source changes with a function. |
| mapRange | DerivedMotionValue<double, double> | clamp: true | Piecewise linear mapping with at least two stops. |

<!-- section: connect -->
## Feed the render object

NibMotionValues accepts external values such as translateX, opacity, rotate, color, and borderRadius. For a property you supply, NibMotion reads your value instead of driving its internal spring or tween for that property. The child does not need a build on each value tick.

The source and both derived values belong to the creating State. NibMotion listens to them but never disposes them; dispose the derived listeners and then the source when that State leaves.

```dart
NibMotion(
  motionValues: NibMotionValues(translateX: x, opacity: opacity),
  child: const FlutterLogo(),
)
```

<!-- section: follow-one-change -->
## Trace one slider movement

Drag the live slider toward its right edge. It writes a value near one to progress. mapRange converts that to an x offset near 62 logical pixels and opacity near one. Drag toward zero and the tile moves left while fading toward 0.3. Both outputs are derived from the same source, so they stay synchronized without two independent setState fields.

mapRange accepts matching input and output stop lists with at least two finite positions; input stops must increase strictly. It linearly interpolates between neighboring stops and clamps outside the input range by default. Use transform when the relationship is not a piecewise numeric range. A simple boolean target is usually clearer with animate.

<!-- section: measure -->
## Check the full frame

The paint path avoids rebuilding the child for each MotionValue change. It does not make a heavy shader, clip, or large composited scene free. Profile build and raster time separately in the target app before claiming a frame budget.

<!-- section: release-values -->
## Dispose the values you created

A derived MotionValue subscribes to its source. Dispose both derived values before disposing progress in State.dispose, then call super.dispose. NibMotion owns its internal values, but it does not dispose the external objects supplied through NibMotionValues. The same ownership rule applies if scroll or gesture code holds an external value.

If the slider still appears to drive a removed screen, a value or listener probably outlived its State. Check subscriptions and route disposal. If the tile does not move, verify you passed translateX rather than a new unused value, and that your source assignment differs from its previous value. A repeated assignment of the same value intentionally sends no listener notification.

<!-- section: what-to-learn-next -->
## Use the value where it helps

Try making opacity constant while leaving translateX linked. Then map three input stops, such as 0, 0.5, and 1, to make the middle position distinct. Keep the source in zero-to-one units and x in logical pixels so the mapping is easy to inspect. Scroll motion shows another producer of MotionValues; Performance explains how to measure the whole rendered frame instead of inferring speed from this small example.

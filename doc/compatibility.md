# Compatibility and known limits

## SDK requirements

The package declares Flutter `>=3.29.0` and Dart `>=3.0.0 <4.0.0` in
[`pubspec.yaml`](../pubspec.yaml). Use the Dart SDK bundled with a supported
Flutter installation; the Dart constraint alone does not establish support for
running this Flutter package with Dart 3.0. CI checks Flutter 3.29.0 and 3.47.8.

NibMotion has no direct pub dependencies beyond Flutter. The example app adds
Material widgets; the package also contains optional navigation helpers.

## Rendering

Core transform and opacity animation updates `RenderNibMotion` during paint.
This avoids rebuilding the animated child on each tick. `NibValueBuilder`
deliberately rebuilds its builder subtree, and application listeners can do the
same. Blur, tint, clipping, and shaders can add rendering work even without
widget rebuilds. See [performance](performance.md) for measured workloads and
their limits.

`NibShaderEffect(sampleChild: true)` requires Flutter's shader image-filter
support. On unsupported renderers, it paints the child unchanged. `NibGlass`
uses its blur/tint fallback when the shader path is unavailable. Shimmer and
dissolve also have loading/failure fallbacks. A successful web build establishes
compilation, not identical shader output across browsers and GPUs.

The shader test lane runs with `--enable-impeller`. Device visuals and frame
times still need checks on your target hardware. No cross-platform frame-rate
or competitor-speed guarantee follows from the test suite.

## Layout and interaction

- Shared `layoutId` transitions need a `NibLayoutScope`, different widget keys,
  and an unmount/remount within the 250 ms snapshot window. Two simultaneously
  mounted owners with the same ID do not form a shared transition.
- Lazy-list reorders animate mounted items. An item recreated after leaving the
  cache has no retained origin. Re-composited sliver boundaries can show a new
  position for one frame before FLIP starts.
- Size FLIP scales content by default. Clip mode keeps the final child size;
  shrinking cannot preserve pixels that the new child no longer paints.
- Perspective layout/reorder geometry is unsupported. Reordering under rotation,
  near-singular transforms, and pop exits across independently transformed clips
  are outside the verified geometry contract.
- Drag bounds and snap points use offsets in the receiver's local logical
  pixels. During finger-following, controller velocity reads can be zero;
  release velocity is handed to the settling driver.

See [layout](layout.md) for coordinate spaces, timing, and supported slivers.

## Accessibility and lifecycle

`NibMotionConfig` follows `MediaQuery.disableAnimations` unless overridden.
Decorative motion stops or jumps to its final state; essential finger-following
remains. Exiting presence children are excluded from pointer input, focus, and
semantics. Read the [accessibility policy](accessibility.md) before supplying
external motion values or custom drivers: those have no automatic context from
which to read a platform preference.

Dispose controllers, solvers, derived values, and externally owned
`MotionValue`s. `NibMotion` does not dispose values supplied through
`motionValues`. `NibTimeline.play()` does not update its scrub progress; cancelling
pending entries can leave that run's future unresolved. See
[timeline cancellation](timeline.md#cancellation-limit).

## Water rendering

`NibWaterSurface` and its layer-sampling policies are stable public APIs. They operate
on a designated, finitely bounded Flutter background subtree. Platform views,
content outside that subtree, inverse-warp hit testing, and total GPU-memory
guarantees are outside their contract. The input texture budget is not a budget
for engine intermediates. Use `onStatus` to see the actual rendering path, and
keep a fallback for presentation-critical scenes. See [water](water.md).

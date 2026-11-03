---
{
  "id": "performance",
  "evidence": "MotionNib/motion/doc/performance.md; MotionNib/motion/lib/src/core/render_nib_motion.dart; MotionNib/motion/lib/src/values/motion_value.dart"
}
---

# Performance

Measure build, layout, paint, raster, and retention separately.

<!-- section: paint -->
## Understand the fast path

A MotionValue notification can make RenderNibMotion mark paint dirty without rebuilding the child on each frame. This is a property of the package path, not a promise that every assembled screen is cheap. Opacity may change compositing needs; blur, clips, shadows, and shader effects add their own work.

The live slider makes this data path visible. It does not collect frame timings. A smooth debug preview cannot establish a production frame budget.

<!-- section: profile -->
## Profile a representative screen

Use a profile build on target hardware. Record SDK, renderer, device, frame count, build duration, raster duration, and retained memory separately. Scroll, interrupt animations, and dispose repeated screens while collecting the trace.

A pure-Dart parser or MotionValue benchmark measures computation. It cannot stand in for Flutter layout, rasterization, GPU presentation, or physical touch latency.

<!-- section: measurement-plan -->
## Make the comparison fair

Choose one real screen and one repeatable interaction first, such as moving a keyed card ten times while a list scrolls. Keep device, SDK, build mode, renderer, workload, and item count fixed between a baseline and a candidate. Warm up the shader and widget paths before sampling. Record raw frame timings and the number of samples; a handful of frames cannot support a precise high percentile. Run the same gesture after every code change so a smoother recording is tied to a concrete edit.

Flutter’s build, layout, and raster timings answer different questions. A MotionValue write may skip rebuilding its child but still ask a render object to paint. A layout FLIP still begins with a real layout change from the host. Blur or a fragment shader may be dominated by raster work. If the Flutter frame graph shows raster spikes, reducing Dart allocation alone is unlikely to solve the visible hitch.

<!-- section: budget -->
## Check what stays alive

Controllers, externally owned MotionValues, and manually created bridges need disposal. Layout snapshots and presence exits can retain geometry until a transition finishes. Compare a stable idle state before and after repeated create-dispose cycles rather than only measuring a single animation.

<!-- section: retention-exercise -->
## Check churn and ownership

Use linked-objects to see how one value can drive another, then put the same interaction inside a route that is repeatedly opened and closed. Create the external MotionValue in State, remove any manual listener, and dispose the value after the widgets that read it leave the tree. Take a heap snapshot at a settled idle point, repeat many route cycles, let exits and timers finish, and take another idle snapshot. Compare retained instances, not just peak memory during the animation.

For layoutId handoffs, snapshots are intentionally kept for a short window after detachment. A single retained snapshot immediately after removal is expected. Growth that continues after the snapshot window and garbage collection needs investigation. Measure detached-snapshot timer allocation under sustained churn separately; the cleanup regression proves release behavior, not that allocation cost is negligible. Record the profile trace and candidate revision with the observation.

<!-- section: diagnose -->
## Match a symptom to the pipeline

If the frame spends time building, look for parent setState calls that rebuild too much of the screen or many per-item keys changing together. If layout is high, inspect expanding children, intrinsic measurement, and lazy-list churn. If raster is high, isolate clips, opacity layers, blur, shadows, and shaders one at a time. If memory climbs, check external controllers, values, subscriptions, and an exit that never reaches completion. Profile on target hardware before deciding a threshold or announcing a speedup.

When comparing a proposed optimization, preserve the unmodified baseline workload and run it again after the change. A new device temperature, browser backend, build mode, or list length can erase the meaning of the comparison. Keep pure-Dart computation timings separate from Flutter frames and from display presentation. If a change reduces one timing but worsens interaction correctness or retained state, it is not a useful win for that screen.

# Performance

## Design

* `MotionValue` change → `markNeedsPaint` on one render object. No `setState`,
  no rebuild (guarded by `test/runtime/no_rebuild_test.dart`).
* Drivers write one value per property per frame; `update` costs one extra
  field write over the plain setter.
* `MotionValue.computed` is lazy: N dependency writes per frame cost N cheap
  notifications and **one** evaluation, at paint.

## Benchmarks

```
flutter test benchmark/motion_benchmarks.dart
```

These measure Dart-VM CPU cost only (no raster), for *relative* before/after
comparison on one machine. Frame-time/raster claims need device lanes.

Recorded 2026-09-29 (Linux, Flutter 3.47.3, debug-mode `flutter test`, one run,
noisy — compare trends, not absolutes):

| Benchmark | Result |
|---|---|
| `value =` + 1 listener | 0.057 µs/op |
| `update(v, velocity:)` + 1 listener | 0.042 µs/op (no measurable overhead vs setter) |
| 1000 `mapRange` derived values updated per frame | 0.26 ms/frame |
| `computed` over 8 deps (8 writes + 1 read) | 0.9 µs/frame |
| 500 concurrent springs, 60 frames | 1.1 ms/frame incl. test harness |
| 200 `NibMotion` springing, 60 frames | 2.3 ms/frame incl. harness; **0** child rebuilds |
| `NibPresence`, 100 items × 40 toggles | 22 ms per toggle incl. `pumpWidget` |

No optimisation was made on the strength of these numbers: nothing showed a
bottleneck worth the complexity. Presence churn (22 ms/toggle with 100 items in
a test harness) is the one to profile first if a real-app report appears.

## Second measurement pass (2026-09-29)

`flutter test benchmark/motion_benchmarks_extended.dart`. Linux, Flutter 3.47.3,
debug-mode `flutter test` (fake clock, no raster, JIT), each benchmark run 3
times, **median** shown. Run-to-run spread is large (often 2x on the first run),
so differences under ~30% are noise.

| Benchmark | Median | Notes |
|---|---|---|
| `AnimationController` + `AnimatedBuilder` x300 (x + opacity) | 10.4 us/frame/widget | 300 active tickers, 0 child rebuilds |
| `NibMotion` spring x300 (x + opacity) | 8.3 us/frame/widget | **600** active tickers (one per animated property), 0 child rebuilds |
| 100 `NibMotion`, animate x only | 5.1 us/frame/widget | 2 layers in the tree |
| same + `blur: 8` | 13.7 us/frame/widget | **+1 `ImageFilterLayer` per widget** (201 layers) |
| same + `tint` | 11.8 us/frame/widget | +1 `ColorFilterLayer` per widget |
| Wrap of 200, reorder + 5 frames, `layout: none` | 1.6 ms/frame | baseline |
| same, `layout: position` | 4.2 ms/frame | +2.6 ms over baseline |
| same, `layout: both` | 3.8 ms/frame | |
| `NibLayoutGroup` Column of 200 | 5.7 ms/frame | different tree (Column), not directly comparable |
| `NibPresence` 100 items, enter+exit props, per toggle | 11.7 ms | `pumpWidget` only |
| Stack of the same `NibMotion`s (no presence) | 4.4 ms | |
| Stack of plain `NibMotion`s | 2.3 ms | |
| `NibPresence` of plain `NibMotion`s | 6.4 ms | orchestration only |
| `mapRange` fan-out 1 / 10 / 100 / 500 / 1000 nodes | 0.26 / 3.4 / 12 / 74 / 224 us/frame | |
| `computed` over 1 / 10 / 100 / 500 / 1000 deps | 0.35 / 0.83 / 7.6 / 41 / 88 us/frame | one read per frame |
| `MultiSpringSolver<Offset>` x300 | 1.7 us/frame/solver | 15000 notifications / 50 frames |
| 2x `SpringSolver` x300 pairs | 1.7 us/frame/pair | 30000 notifications (2x) |

### What this does and does not show

* **Shown:** animating with `NibMotion` costs the same order of CPU as a
  hand-written `AnimationController` + `AnimatedBuilder` (8.3 vs 10.4 us, within
  noise) and neither rebuilds the child. `MultiSpringSolver` halves
  notifications versus two scalar solvers with no CPU difference here.
* **Shown:** blur and tint each add one compositing layer per widget and roughly
  2-3x the per-widget CPU of a plain translate. Use them on few widgets, not on
  every item of a long list. Raster cost (blur is GPU-heavy) is **not
  measured**.
* **Shown:** `layout: position` on 200 reordered items costs about +2.6 ms per
  frame in this harness. On a 60 Hz budget of 16.7 ms that is not free; it is
  dominated by the per-item measure/invert, not by animation.
* **Shown:** `NibPresence` overhead is real. 100 items toggled: 6.4 ms with plain
  children versus 2.3 ms for an equivalent `Stack`. Adding enter/exit props
  roughly doubles mount cost in both. Isolating which part of the
  orchestration dominates was **inconclusive**: the three wrapper widgets
  (`IgnorePointer`/`ExcludeSemantics`/`ExcludeFocus`) showed no measurable
  cost (3.7-9 ms spread), so the remainder is entry bookkeeping/GlobalKeys, not
  proven.
* **Not shown:** raster time, real devices, allocation counts, release/AOT
  numbers. All numbers above are debug-mode JIT.

## Scope measurement check (2026-10-14)

The scoped `RepaintBoundary` fix measures ordinary descendants after layout.
The existing 200-item debug benchmark was run from the committed baseline and
the updated working tree on the same host and Flutter 3.47.3. Median time per
frame for a Wrap reorder plus five frames, in microseconds:

| Layout | Baseline | Updated |
|---|---:|---:|
| `none` | 1486 | 1512 |
| `position` | 4474 | 4354 |
| `both` | 4050 | 4032 |
| `NibLayoutGroup` Column | 3901 | 3931 |

The differences are far below the runs' spread; this check does not establish
a performance improvement or regression. Raster and device costs still need
measurement.

## Not yet measured (needs hardware)

* Android low-end Impeller-GLES device (the report cites 2–3× Skia-GL raster
  cost on an Adreno 610 for shader/blur-heavy scenes).
* iOS/Metal, desktop GPUs, Web CanvasKit/Wasm frame percentiles.

Procedure: run the example app in `--profile` on the target, open the
performance overlay (`NibPerfOverlay`), and record UI/raster frame percentiles
for: 100 transforms + opacity, FLIP reorder of 50 items, `NibShimmer`/`NibGlass`
full-screen. Do not extrapolate flagship-device results to low-end Android.

## Real-frame measurements, Linux desktop (2026-10-01)

First measurements with real engine frame timings (`FrameTiming` build/raster/
total) in a **profile-mode** Linux build, instead of the fake-clock numbers
above. Harness: `example/perf/perf_main.dart` (12 scripted scenarios, 1.5 s
warm-up + 6 s each, prints `PERF_RESULT` JSON lines, exits when done).

Machine: Arch Linux 7.2.7, Intel UHD Graphics 620 (Kaby Lake-R GT2, integrated),
Wayland session (`wayland-1`, `:0`), Flutter 3.47.3, renderer: **Impeller,
OpenGLES backend** (`embedder_surface_gl_impeller`, "OpenGLESSDF"). Window size
and refresh rate were not controlled or recorded.

Reproduce:

```
cd example
flutter build linux --profile -t perf/perf_main.dart
./build/linux/x64/profile/bundle/nib_motion_example | grep PERF_RESULT
```

Build note: this machine has no `clang++`, which Flutter's Linux build requires
(`flutter doctor` reports the Linux toolchain as incomplete). The build was done
with a PATH shim mapping `clang`/`clang++` to `gcc`/`g++` in a temp directory;
nothing in the repo or system was changed. Install clang for a supported setup.

Two runs, p50 of total frame span in ms (run 1 / run 2). Run-to-run spread is
**20-40%**, so only large differences mean anything.

| Scenario | total p50 | raster p50 | frames in 6 s |
|---|---|---|---|
| 300 `NibMotion` springs (x + opacity) | 42.9 / 37.4 | 24.4 / 21.0 | 233 / 256 |
| 300 `AnimationController` baseline (same visuals) | 40.4 / 40.1 | 23.5 / 23.0 | 223 / 228 |
| 100 `NibMotion`, x only | 31.6 / 24.5 | 18.9 / 15.7 | 280 / 350 |
| 100 + blur | 47.4 / 32.0 | 27.4 / 19.9 | 205 / 298 |
| 100 + tint | 37.0 / 22.6 | 21.4 / 14.7 | 247 / 349 |
| 100 + rotateY | 33.1 / 39.5 | 19.2 / 22.8 | 266 / 226 |
| 200-item Wrap reshuffle, `layout: none` | 19.2 / 14.2 | 15.4 / 10.3 | 6 / 6 (nothing animates) |
| 200-item Wrap reshuffle, `layout: position` FLIP | 42.0 / 30.0 | 23.6 / 17.9 | 222 / 267 |
| `NibPresence` 100-item churn | 40.0 / 32.3 | 23.1 / 20.0 | 131 / 150 |
| 500 `mapRange` values feeding transforms | 44.9 / 43.5 | 25.1 / 23.9 | 234 / 227 |
| Full-screen `NibShimmer` | 2.9 / 5.5 | 0.7 / 0.8 | 359 / 359 |
| `NibGlass` moving over a gradient | 12.0 / 9.1 | 1.8 / 1.6 | 303 / 302 |

What this shows:
- **`NibMotion` vs a hand-written `AnimationController` tween:** same frame cost
  (42.9/37.4 vs 40.4/40.1 ms total p50). Neither is faster; the workload is
  raster-bound on this GPU, and build time (about 8 ms p50 for 300 widgets) is
  similar for both.
- **Nearly every animated scenario exceeds 16.7 ms** (hundreds of dropped frames
  per scenario, about 40 fps). Even the plain 100-box baseline does. With the
  AnimationController baseline equally slow, the limit here is this integrated
  GPU through Impeller-GLES (and the unrecorded window size), not `nib_motion`.
  Do not read these as "nib_motion drops frames on a normal device".
- **Blur / tint / rotateY / FLIP:** their p50s are inside the run-to-run spread of
  the x-only case (e.g. blur 47.4 then 32.0; x-only 31.6 then 24.5), so this data
  cannot separate their cost. Blur's added compositing layers (see the layer
  counts above) remain the best-supported reason to use it sparingly.
- `NibShimmer` and `NibGlass` frames are cheap (raster p50 under 2 ms). I did not
  verify from the frame data alone that the shader program loaded rather than
  falling back to painting the child; the 359 frames show its ticker was running.

Not proven: any other GPU, other renderers (Skia, Vulkan, Metal), low-end
Android, iOS, web, window-size/refresh-rate dependence, or release-mode (AOT
profile is used here, not `--release`). Numbers are medians of one 6 s window per
scenario per run.

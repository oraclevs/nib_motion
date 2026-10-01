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

## Not yet measured (needs hardware)

* Android low-end Impeller-GLES device (the report cites 2–3× Skia-GL raster
  cost on an Adreno 610 for shader/blur-heavy scenes).
* iOS/Metal, desktop GPUs, Web CanvasKit/Wasm frame percentiles.

Procedure: run the example app in `--profile` on the target, open the
performance overlay (`NibPerfOverlay`), and record UI/raster frame percentiles
for: 100 transforms + opacity, FLIP reorder of 50 items, `NibShimmer`/`NibGlass`
full-screen. Do not extrapolate flagship-device results to low-end Android.

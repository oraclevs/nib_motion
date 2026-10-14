# NibMotion Master Implementation Tracker

Status legend: `[ ]` not started · `[~]` in progress · `[x]` done + verified · `[!]` blocked · `[-]` deliberately rejected

## Mission

Evolve `nib_motion` into one coherent motion runtime: reactive `MotionValue`s with
velocity, physics-aware interruption, gesture/scroll/layout/presence/variants
sharing one model, centralised accessibility, measured performance — without
copying competitor APIs or adding dependencies. Source of truth is this repo;
`deep-research-report(1).md` (2026-09-28) is guidance only.

## Current state (2026-10-14)

The 0.3.2 work is on `feat/runtime-0.3.2`. pub.dev still lists 0.3.1; the branch has not been published. The six passes below completed most of the original gap analysis. The current limits are recorded in the sixth pass and the resumption check near the end of this file.

## Baseline (verified 2026-09-29)

- Version 0.3.1. Dart `>=3.0.0 <4.0.0`, Flutter `>=3.10.0`. Zero pub deps beyond Flutter SDK.
- 72 lib files (~11k LOC), 59 test files. Baseline: `flutter analyze` clean; `flutter test` 302 pass.
- CI: `.github/workflows/ci.yml` (+ publish). No benchmarks, no golden animation sheets.
- Architecture: `NibMotion` owns one `MotionValue` per property → `RenderNibMotion`
  repaints via `markNeedsPaint` (no rebuilds). Drivers: `SpringSolver`,
  `InertiaSolver`, per-property `AnimationController` tweens. Scopes: Variants,
  Presence, Replay. FLIP via `NibLayoutGroup`+`FlipRecorder`.

## Existing Capabilities (verified in source)

MotionValue + `transform`/`mapRange` derived values · springs (presets), inertia ·
`NibAnim`/`NibTransition` · variants w/ stagger/delayChildren · presence (exit) ·
whileTap/Hover/Focus/Drag/InView · drag (axis, constraints, elastic, snap, release
modes) · NibDraggable/Pinch/SwipeDismiss · keyframes · timeline + animation sequence ·
scroll (motion bridge, parallax, reveal) · path motion/draw · text effects ·
GPU shaders (shimmer, dissolve, glass) · nav shell · debugger/inspector/perf overlay ·
`NibMotionConfig` (reduced motion + default transition) · `NibMotionController`.

## Research Gap Analysis

| Capability | Competitor(s) | NibMotion current state (verified) | Gap | Decision | Priority |
|---|---|---|---|---|---|
| Velocity-preserving retarget | fluid_motions, flutter_physics, Motor, animated_to | Only spring→spring while ticker active. `MotionValue` has no velocity. Tween→spring, inertia→spring, stop→spring start at 0 velocity | Real | Implement: `MotionValue.velocity`, drivers publish it, springs start from it | P0 |
| Interrupted-animation futures | — (found by audit) | Superseded spring/tween/delayed futures never complete (`TickerFuture.then` waits on primary; spring completer replaced) | **Bug** | Fix: futures resolve on supersede/stop | P0 |
| Hit-test/paint-transform coherence | layout_motion (paint-phase) | `RenderNibMotion` paints transforms but had no `applyPaintTransform`/`hitTest`; gesture wrappers sat outside transform | **Bug (fixed)** | Fixed + tests | P0 ✔ |
| Presence re-entry mid-exit | layout_motion | Key re-added during exit stays visually exited | **Bug** | Fix: animate back to `animate` | P0 |
| Presence child ordering | layout_motion | Stack order = insertion order, reorders ignored | Bug | Fix | P1 |
| FLIP interruption from painted transform | layout_motion | `controller.set(delta)` replaces in-flight offset → jump when interrupted; position only (no size) | Real | Fix (accumulate in-flight offset); size FLIP later | P0/P1 |
| `layout: true` zero-config | layout_motion | Only via `NibLayoutGroup` (Column) | Gap | Adapt: later | P1 |
| Shared `layoutId` | layout_motion, Framer | none | Gap | Defer | P2 |
| Derived-value DAG (multi-source, batching, cycles) | Cue typed tracks | single-source `transform`/`mapRange` only | Gap | Implement `MotionValue.combine` (multi-source), lazy dedupe; batching evaluated by benchmark first | P1 |
| Motion tokens | Motor | Only gentle/snappy/wobbly/stiff | Small | Adapt: neutral tokens on `NibSpringDescription`/`NibTransition` | P2 |
| Decay/bounds/snap physics as first-class | Motor, flutter_physics | `InertiaSolver` (friction only, no bounds); drag has own bounds | Gap | Improve `InertiaSolver` w/ bounds + velocity publish | P1 |
| Implicit/`animated_to` ergonomics | animated_to | `NibMotion(animate:)` already retargets on rebuild; no position-implicit widget | Partial | Adapt via layout API | P1 |
| Keyframes/timelines | Cue, Motor | exist (`NibKeyframe`, `NibTimeline`, `NibAnimationSequence`) | Docs/tests thin | Already covered → test cancellation | P1 |
| Scroll-linked | Cue, animate+ | exists | ok | Already covered | — |
| Reduced motion | layout_motion | `NibMotionConfig.shouldReduceMotion` central; global static override | ok, verify coverage | Audit | P0 |
| Devtools/scrubber | Cue | debugger + inspector exist | Docs | Document | P2 |
| Animation-sheet goldens | — | none | Gap | Add | P1 |
| Benchmarks | — | none | Gap | Add (measure first) | P1 |
| Wasm/GLES CI lanes | — | none | needs hardware/CI | Wasm build lane feasible; GLES device → blocked | P1 |
| flutter_animate's 100 effects | animate+ | presets only | — | **Reject** (effect zoo; composable `NibAnim`/keyframes cover it) | — |
| Depend on competitor pkgs | — | — | — | **Reject** | — |
| Rust/native | — | — | — | **Reject** (no profiling evidence) | — |

### Research vs repo discrepancies
- Report claims velocity contract is "partial": confirmed, narrower than stated (spring→spring only).
- Report says README documents paint-driven MotionValue: true, matches source.
- Report did not mention (found in audit): unresolved futures, transform-blind hit testing, presence re-entry.

## Architecture Decisions

- **AD-1 Velocity lives on `MotionValue`** (explicit, written by drivers via `MotionValue.update(v, velocity:)`), not sampled from a clock. Deterministic in tests; plain `value =` means "jump" (velocity 0). One mechanism serves spring, inertia, tween, drag, and layout takeover.
- **AD-2 Superseded animations resolve their futures** (complete, don't error). Natural-completion callbacks (`onComplete`) still fire only on settle.
- **AD-3 Interaction wrappers inside the transformed render object**, plus `applyPaintTransform`/`hitTest` on `RenderNibMotion`, so coordinate spaces match what is painted.
- **AD-4 Additive API only**; no removals.
- **AD-5 Version 0.3.2, not 0.4.0.** `nib_components` depends on `nib_motion: ^0.3.0` (caret on 0.x excludes 0.4.0); all changes are additive/bug fixes.
- **AD-6 Numeric trajectory goldens** instead of pixel goldens (see P1).
- **AD-7 Lazy `computed`** over eager for multi-source values; eager `transform`/`mapRange` kept for compatibility (notify-on-change semantics).
- **AD-9 Timeline/sequence stop contract preserved**: unlike animation futures (AD-2), `NibTimeline.play()`/looping `NibAnimationSequence.play()` futures intentionally never complete after `stop()`/`pause()`; that is documented and tested, so it was not changed.
- **AD-8 Reduced motion policy**: essential finger-following stays, decorative/settling motion jumps, loops don't start.

## P0 — Foundations / Correctness

- [x] Hit testing + `localToGlobal` follow paint transform (`PaintTransformHitTest` mixin on `RenderNibMotion`, `NibDraggable`, `NibPinch`); gesture wrappers inside transform (`test/runtime/hit_test_transform_test.dart`). `NibSwipeDismiss` intentionally keeps its detector on the stationary box.
- [x] `MotionValue.velocity` + `update`; `DerivedMotionValue` velocity via `mapRange` slope (`interruption_test.dart`)
- [x] `SpringSolver`/`InertiaSolver` publish velocity, start from `value.velocity`, settle exactly on target
- [x] Tween driver publishes velocity (finite difference)
- [x] Superseded/stopped/delayed futures resolve; newest delayed target wins; controller safe after dispose
- [x] Presence re-entry mid-exit animates back (`presence_lifecycle_test.dart`)
- [x] FLIP interruption continuity (painted-origin recording + `keepVelocity`) (`flip_interruption_test.dart`)
- [x] Reduced-motion audit: 12 widgets patched via `NibReducedMotionMixin`/`watchReducedMotion` (`reduced_motion_test.dart`, 20 tests). `NibTimeline` unchanged (no context; entries route through NibMotion)
- [x] Disposal tests for derived/computed chains (`computed_motion_value_test.dart`); solver dispose resolves futures

## P1 — Competitive Parity

- [x] `MotionValue.computed` / `ComputedMotionValue` (lazy, read-only). Cycle detection rejected: dependencies must pre-exist so cycles can't be built. Batching rejected: benchmark shows 1000-node fan-out 0.26 ms/frame; lazy read already coalesces.
- [x] `InertiaSolver` bounds + elastic overshoot; drag `inertia` release respects constraints; `snapProjection` (`inertia_solver_test.dart`, `drag_release_test.dart`)
- [x] Presence ordering (exiting children keep their slot)
- [x] FLIP size (scale and clip) + `layout:` API; see the second and third passes below.
- [x] Timeline cancellation: already covered by `nib_timeline_test.dart` (pause/stop/dispose). Found + fixed `NibAnimationSequence` double-run on `play()`-while-playing and `stop()`→`play()` (generation token; `sequence_replay_test.dart`). **Kept** the documented contract that `NibTimeline`/looping-`NibAnimationSequence` futures do not complete after stop/pause (explicit in docs + an existing test) — AD-9. Scrubbing: not implemented (defer).
- [x] Numeric trajectory goldens (`test/runtime/goldens/*.json`, 3 scenarios). Pixel `AnimationSheetBuilder` goldens rejected: platform/SDK-sensitive (CI pins 3.32, dev uses 3.47); the physics is pure math so snapshotting trajectories is deterministic.

## P2 — Differentiation / Ecosystem

- [x] Neutral motion tokens (`NibSpring`); see the second pass below.
- [x] Shared `layoutId` within `NibLayoutScope`; see the second pass below.
- [-] Companion packages: no separate package justified by the current API or measurements.

## Documentation

- [x] README positioning + corrected inaccurate examples
- [x] `doc/` architecture, interruption, motion-values, performance, accessibility
- [x] `doc/migration.md` (concept maps; competitor syntax deliberately not reproduced)
- [x] CHANGELOG 0.3.2 (not 0.4.0: `nib_components` pins `nib_motion: ^0.3.0`, and every change is additive → AD-5)

## Examples
- [x] Example app: 21 screens and 50 tests; see the fourth pass below.

## Benchmarks
- [x] `benchmark/motion_benchmarks.dart` (fan-out, springs, computed, widgets rebuild count, presence churn); numbers in `doc/performance.md`. No optimisation performed (no bottleneck evidenced).

## Testing
- [x] Baseline 302 tests green
- [x] Interruption suite (`interruption_test.dart`, 13 tests)
- [x] Presence rapid mount/unmount
- [x] FLIP transformed-parent + moved-container geometry: FLIP now measures in the group's local space (`FlipRecorder(ancestor:)`); 2 regression tests failed before (wrong-size inversion under scale, spurious FLIP when the container moves)

## Compatibility / Migration
- All changes additive so far. Behaviour change: gesture wrappers now transform with the box (bug fix).

## CI
- [x] Wasm build lane added to `.github/workflows/ci.yml`; verified locally: `flutter build web --wasm` of the example compiles (compile-only evidence, runtime not verified).

## Completed

Final verification 2026-09-29: `dart format --set-exit-if-changed .` clean · `flutter analyze --fatal-infos` clean · `flutter test` **371 pass** (baseline 302; +69) · `dart pub publish --dry-run` only warns about uncommitted changes · `grep TODO|FIXME|HACK|print(` in `lib/` empty · **downstream**: `nib_components` (814 tests) passes against this working copy via `dependency_overrides` in a scratch copy · Wasm compile of the example succeeds.

Bugs found by audit and fixed, each with tests that failed first:
1. Transform-blind hit testing / `localToGlobal` (`RenderNibMotion`, `NibDraggable`, `NibPinch`); dragged widgets could not be re-grabbed.
2. Interrupted animation futures hung (spring/tween/delayed/stop/dispose); stale delayed targets fired later; controller notified after dispose (exposed once futures resolved).
3. Velocity lost on spring→stop→spring, tween→spring, inertia→spring, FLIP.
4. Presence re-entry left child faded out; presence ignored reorders.
5. FLIP interruption jump; FLIP wrong under scaled ancestor; FLIP fired when only the container moved.
6. Reduced motion ignored by 12 widgets.
7. `NibAnimationSequence` ran twice on `play()` while playing / `stop()`→`play()`.
8. Inertia release ignored drag constraints.
9. README examples referenced non-existent API.

## Remaining after the first pass (historical snapshot)
- `layout: true` widget-level API and size (scale) FLIP; shared `layoutId`; sliver-aware motion.
- Neutral motion tokens (`NibSpring.spatialFast` …).
- Timeline scrubbing; visual spring/timeline inspector; graph view in `NibMotionDebugger`.
- Device benchmark lanes (Android Impeller-GLES, iOS, desktop, Web) — hardware.
- Example app screens for the new behaviours (the existing `example/lib/main.dart` was left unchanged; behaviours are demonstrated by tests and docs only).
- Dev-only `NibMotionDebugger` does not yet expose velocity.


## Second pass — verified competitor comparison (2026-09-29)

The first pass used the research paper as guidance only and did not verify competitors at source. This pass verified each competitor from pub.dev/GitHub (README, CHANGELOG, pubspec, and for `layout_motion`/`animated_to` raw source), and compared against our code. Caveat: page summaries were produced by a small model (API names reliable, exact numbers less so); Cue/animate+ `lib/` source was not read, so their internal quality and runtime behaviour remain unverified.

### Corrections to the research paper
- `layout_motion` repo is `meylis1998/layout_motion` (paper said `realmeylisdev`); it **already has shared layout IDs** (`MotionLayoutScope/Id/Group`), so `layoutId` is parity, not white space; its "paint-phase" transform is a `Transform` widget in an `AnimatedBuilder`; it does **not** retain velocity on interruption.
- `flutter_animate_plus` **documents** velocity-preserving retarget (`SpringAdapter`) and reduced motion in `AnimatePresence` (paper understated).
- Motor depends on `equatable`+`meta` (not zero-dep) and has an unreleased 2.0 rewrite (draft PRs); `animated_to` depends on Motor (its velocity retention is Motor's).
- Paper's Cue/Motor/`fluid_motions`/`flutter_physics` descriptions confirmed.

### Gap table — status after this pass
| Gap (verified) | Competitor | Status |
|---|---|---|
| Layout FLIP in any parent, position+size | layout_motion, animated_to | **Done**: `NibMotion(layout:)`, `NibLayoutScope`; size FLIP is *scale* (text stretches); **no clip variant** |
| Shared layout ids | layout_motion | **Done** (`layoutId`) |
| Reorder drag | layout_motion | **Done** `NibReorderable` (no auto-scroll, one axis, no spacing) |
| Pop exit + semantics/focus exclusion + stagger | layout_motion, animate+ | **Done** |
| Layout lifecycle callbacks | layout_motion | **Partial**: `onLayoutAnimationStart/Complete` only (no per-child enter/exit/move callbacks) |
| Slivers / lazy lists | layout_motion (partial), animated_to (fails) | **Not done** (documented unsupported) |
| LIS diff | layout_motion | **Rejected** (measurement-based FLIP already skips unmoved children) |
| Duration+bounce springs | Motor, flutter SDK | **Done** |
| Motion tokens | Motor, Cue | **Done** as NibMotion-defined values (not Material/Apple numbers) |
| Independent per-axis physics (Offset/Size/Rect/Color…) | Motor, flutter_physics | **Done** `MotionConverter`, `MultiSpringSolver` |
| Builder over animated value | Motor, flutter_physics | **Done** `NibValueBuilder` (rebuilds subtree per frame; springs only) |
| Custom Simulation (Gravity) | flutter_physics | **Done** `NibSimulationDriver` |
| Implicit padding/size/alignment widgets | flutter_physics `A*` | **Not done** as dedicated widgets: `NibValueBuilder`+converter covers it; layout `size` covers size |
| Continuous scroll/visibility progress | Cue | **Done** `NibViewportProgress` (1-frame lag, no reversed axes) |
| Page/tab progress binding | Cue | **Done** `NibPageProgress` (PageController); TabController not done |
| Reverse-direction motion | Cue | **Done** `reverseTransition`, `exitTransition` |
| Per-keyframe spring segments | Cue | **Done** `NibKeyframe.spring`/`NibSpringCurve` |
| Relative timeline (`then`/labels) | animate+ `ThenEffect` | **Done** `after`/labels |
| Timeline scrubber | Cue | **Done** `progress`/`seek`/`NibTimelineScrubber` (entries without `from` step at end; `play()` doesn't drive `progress`); no drag scrubber |
| Loop modes (seamless) | Motor | **Done** (own definition of seamless) on sequence + `NibMotion.loopMode` |
| 3D rotate | Cue, animate+ | **Done** `NibAnim.rotateX/rotateY` |
| Blur / tint | Cue, animate+ | **Done** `NibAnim.blur/tint` (paint-time layers; **no perf measurement yet**) |
| Generic shader effect | animate+ `ShaderEffect` | **Done** `NibShaderEffect` — real-program test **skipped** (harness cannot load fragment programs); never run with a real shader |
| Velocity in debugger, reduced-motion toggle | Cue, animate+ | **Done** |
| Dialog/route helpers | Cue | **Not done** (better in `nib_components`) |
| Sliver header integration (`FlexibleSpaceBar`) | Cue | **Not done** |
| Text/icon style acts, layout acts (padding/align animate layout) | Cue | **Rejected/deferred** (paint-phase core; use layout) |
| Hot-reload auto-restart | animate+ | **Not done** (low value) |
| Motor 2.0 devtools-style spring tuner | Motor | **Not done** |
| AnimationController baseline in benchmarks | Motor PR #323 | **Not done** |
| Example app screens | — | **Not done** |
| Device benchmark lanes (GLES etc.) | report | **Not done** (hardware) |

Verification after second pass: format clean · `flutter analyze --fatal-infos` clean · `flutter test` **499 pass, 1 skipped** · `nib_components` 814 pass against the working copy · fork-authored suites (layout 38 tests, physics/values/timeline ~113) re-run by me in the full suite.

### Third pass (examples, benchmarks, layout completion)
- Done: 9 demo screens + 11 smoke tests (`example/`), benchmarks vs `AnimationController` and perf numbers (`doc/performance.md`, `benchmark/motion_benchmarks_extended.dart`), clip-mode size FLIP (`layoutSizeMode`), `layoutTransition.delay`, per-child callbacks (`onChildEnter/Exit/Move`, aggregated start/complete), `NibPageProgress.tab`, `NibReorderable` spacing + auto-scroll. Suite now **524 pass, 1 skipped**.
- **Still open** (from `example/API_FEEDBACK.md`): no declarative read of a `NibMotion`'s velocity; `MotionValue<Offset>` cannot drive `NibMotion`; timeline scrubbing needs duplicated `from:`; `NibTimelineScrubber` imports Material; `NibPresence` FLIP needs three pieces of ceremony; `NibLayoutGroup` not rebuilt on the per-widget mechanism (its tests assert controller channels); `RepaintBoundary` missed-move; sliver support; dialog/route helpers; sliver header helper.
- Docs-only fixes from that feedback: `initial` is read once, drag geometry is relative, spring tokens need `.transition`, `layoutId` recipe.
- Perf, measured (debug-mode, medians): no meaningful difference vs `AnimationController` baseline; presence orchestration ~4 ms extra per 100-item toggle (cause unattributed, no change made); blur/tint add one layer per widget.

### Fourth pass (limits cleanup + remaining gaps)
Done: dialog/route helpers with back-swipe + shared hand-off, sliver progress/header, drag scrubber, spring tuner, hot-reload replay, velocity read, Offset adapter, timeline `from:` auto-derive, Material-free scrubber, `NibPresence.layout`, `NibLayout.inherit` opt-out, slivers/lazy lists in layout, RepaintBoundary moves (one frame late), viewport progress lag/reversed axes, `NibValueBuilder` tween/withChild, simulation final frame. Example app: 21 screens. Suite: **616 pass, 1 skipped**; example: 50 tests; `nib_components` 814 pass against the working copy; analyze `--fatal-infos` and format clean.

**Remaining limits (real):** `NibLayoutGroup` keeps its own FLIP (rewrite would require weakening its tests); RepaintBoundary case is one frame late; reverse-growth slivers and items re-created after leaving the cache extent; nested-scrollable progress relies on extrapolation; back-swipe has no route-below parallax and pops via `maybePop`; `sharedFrom` source is not hidden under the route; `NibValueBuilder` is rebuild-based by design; velocity reads 0 during a finger drag; `NibSpring` tokens not const; `NibSimulationDriver` has no end-velocity callback; Motor-2.0-style devtools beyond the tuner; device/raster benchmarks, pixel checks (blur, tint, 3D, clip, back-swipe, tuner) and a real-shader run remain **unverified**; Cue/animate+ source not read.

### Fifth pass (independent review + visual verification)
- **Review** found and fixed 6 real bugs (each with a red-first regression test): keyframe futures hanging; `controller.stop()` ignoring keyframe/loop animations; `NibLayoutFrameHook` registration leak; a mis-patched cleanup for `rotateX/rotateY/blur/tint` listeners (mine, from the NibAnim change); `NibLayoutScopeData` snapshot leak; plus seeded fuzz tests (`review_fuzz_test.dart`) for controllers, presence+layout (LTR/RTL), lists with FLIP while scrolling, route push/pop, value builders.
- **Visual verification** (rendered to PNG and inspected): blur, tint, 3D rotation, clip vs scale, sliver header, layered effects, real shader all PASS. Found and fixed 3 bugs: back-swipe showed white instead of the page below (route now non-opaque during gesture + `didStartUserGesture`); `NibReorderable` dragged item painted under siblings; `NibSpringTuner` ignored `initial`. Shader tests now run a real fragment shader via a test-only `NibShaderLoader.assetKeyResolver` hook.
- Suite **658 pass, 0 skipped**; example 50 pass; `nib_components` 814 pass against the working copy; analyze `--fatal-infos` + format clean. Coverage 86.2% (was 82.6%); `nib_glass.dart` still 0%.
- Still unverified: device/raster performance, on-device visuals, `NibGlass`, Cue/animate+ internals. Review suspicion not confirmed: `NibLayoutFrameHook` holds static state that nothing resets.

### Sixth pass (source-level verification + remaining builds)
- **Cue and flutter_animate_plus source were read** (cloned, ~26k lines): confirmed Cue passes velocity between tracks (normalized units, dropped on scrub), has **no** reduced motion, "coordination" is only a shared timeline scope (not variants); animate+ handles reduced motion in presence/implicit/adapters but not its core timeline. Probes found real bugs in OUR code (NaN poisoning, negative duration, reduced motion not applied mid-flight) — all fixed with tests.
- **Device performance:** first real frame timings on Intel UHD 620 / Impeller GLES (`example/perf/perf_main.dart`, `doc/performance.md`): NibMotion ≈ AnimationController baseline; blur/tint/rotateY/FLIP differences are inside 20-40% run-to-run noise (no claim). Not covered: other GPUs, Skia/Vulkan/Metal, low-end Android, iOS, web, release mode.
- **NibGlass:** coverage 0% → ~52%; real shader bug found and fixed (uSize overwritten by Impeller with the backdrop texture size → rim effects landed on a phantom rect); verified by rendered images in the Impeller test renderer only (**not on a device**).
- **Built:** `NibLayoutGroup` on the per-widget mechanism (tests unchanged, `NibLayoutChannelMode.translate`), back-swipe parallax, reverse-growth slivers, `NibSharedSource`, numeric validation, reduced motion mid-flight, `NibShaderEffect(sampleChild)`, `NibVisibility`, scrub release modes.
- Suite **736 pass** (+55 Impeller shader tests via `--enable-impeller`); example 50; `nib_components` 814; analyze/format clean.
- **Remaining:** per-property spring tolerance and eased mid-visible `whileInView` entrance (optional); on-device visuals/perf; whole-`ListView.builder` reorders only animate built items; items re-created after leaving the cache extent don't FLIP on arrival; position FLIP assumes the widget doesn't animate its own x/y; `NibVisibility` exit settings come from the last visible build; release-mode clamp paths are untested (asserts fire in debug); Skia has no `sampleChild`.

Honest caveats: tests for layout/presence were written alongside the implementation (fork reported mutation checks instead of red-first runs); blur/tint/3D have unit + layer-presence tests but no pixel or device verification; shader effect untested with a real program.

## Resumption check (2026-10-14)

- The active branch is `feat/runtime-0.3.2` at `a8ac6eb`; `pubspec.yaml` says 0.3.2. The three untracked example platform folders (`android/`, `linux/`, `web/`) were left alone.
- Baseline on Flutter 3.47.3: 736 package tests pass; `flutter analyze --fatal-infos` reports no issues.
- A current pub.dev check found `animated_to` 0.9.1 and `flutter_animate_plus` 5.1.0. Their newer features include hit-test boundary support and sliver/implicit effects. NibMotion already has transformed hit testing, sliver progress, `NibMotion(animate:)`, and value builders. No new API follows from that spot check. Sources: https://pub.dev/packages/animated_to and https://pub.dev/packages/flutter_animate_plus.
- `MotionValue<double>` accepted a non-finite initial value. `mapRange` accepted duplicate, descending, or non-finite stops and kept mutable caller lists. Construction now rejects non-finite doubles; `mapRange` rejects invalid stops and copies valid lists. Three regression tests failed before the fixes and pass after them.
- Verification after the fixes: 739 package tests pass, 50 example tests pass, `flutter analyze --fatal-infos` reports no issues, and changed Dart files pass `dart format --set-exit-if-changed`.
- `dart pub publish --dry-run` validated a 373 KB archive after `.pubignore` excluded the three untracked example platform folders. The precommit run warned only about the dirty git tree; the committed branch passed with 0 warnings. Device visuals and cross-platform frame timing still need the hardware listed below.

## Blocked / Needs Decision
- Android Impeller-GLES / iOS / desktop / Web device benchmark lanes: need hardware. Procedure documented in `doc/performance.md`; **no platform performance claim is made**.

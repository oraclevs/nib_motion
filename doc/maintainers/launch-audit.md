# Launch audit: 2026-11-02

NibMotion already implements the motion system described in the new README.
The main launch gaps were discoverability, outdated examples, overly broad
claims, missing contributor guidance, and release checks. This candidate changes
documentation, examples, package metadata, and release tooling. The animation
engine is unchanged; the two library-file edits correct timeline comments.

## Baseline and scope

- Baseline: `main` at `166891c762f2579e470b6bb25c564b0ac95ad407`.
- Published package checked on November 2: `0.3.5`. The candidate is `0.3.6`.
- Latest discovered Git tag and GitHub Release: `v0.3.0`. Historical tags must
  not be backfilled through the publishing workflow.
- Inventory: 107 library Dart files, 129 test Dart files, and 93 unique export
  paths in [the public barrel](../../lib/nib_motion.dart). All export paths
  resolve. These counts describe files, not independently validated features.
- The package has no direct pub dependencies beyond the Flutter SDK. The
  [SDK constraints](../../pubspec.yaml) require Flutter 3.29.0 or later and a
  compatible bundled Dart SDK.

The source, tests, repository guides, example entry points, assets, benchmark
qualifications, and workflows were reviewed for the claims used in the landing
page. This is a launch audit, not a proof that every public method is defect-free.

## 1. Implemented and tested

| Capability | Source and test evidence |
| --- | --- |
| Declarative targets, transitions, variants, keyframes | [Core implementation](../../lib/src/core/), [widget tests](../../test/widgets/), [transition tests](../../test/core/nib_transition_test.dart) |
| Spring retargeting and velocity handoff | [Spring solver](../../lib/src/physics/spring_solver.dart), [interruption tests](../../test/runtime/interruption_test.dart), [trajectory fixtures](../../test/runtime/trajectory_golden_test.dart) |
| Reactive scalar and composite values, derived/computed values, custom simulations | [Values](../../lib/src/values/), [physics](../../lib/src/physics/), [simulation-driver tests](../../test/runtime/physics_simulation_driver_test.dart), [computed-value tests](../../test/runtime/computed_motion_value_test.dart) |
| Gesture states, drag constraints, release modes, pinch and swipe | [Gesture implementation](../../lib/src/gestures/), [drag-release tests](../../test/runtime/drag_release_test.dart), [gesture tests](../../test/gestures/) |
| Position/size FLIP, shared layout snapshots, mounted-item reordering | [Layout implementation](../../lib/src/layout/), [shared-layout tests](../../test/runtime/layout_shared_test.dart), [reorder tests](../../test/runtime/layout_reorderable_test.dart), [clip-mode tests](../../test/runtime/layout_clip_test.dart) |
| Presence, exits, list staggering and visibility | [Presence](../../lib/src/presence/), [list implementation](../../lib/src/list/), [lifecycle tests](../../test/runtime/presence_lifecycle_test.dart), [visibility tests](../../test/runtime/hardening_visibility_test.dart) |
| Scroll/viewport values, timelines, relative entries and scrubbing | [Scroll](../../lib/src/scroll/), [timeline](../../lib/src/timeline/), [relative-timeline tests](../../test/runtime/timeline_relative_test.dart), [progress tests](../../test/runtime/progress_values_test.dart) |
| Text, paths, presets, navigation, shader effects and glass | [Text](../../lib/src/text/), [paths](../../lib/src/path/), [navigation](../../lib/src/nav/), [shader implementation](../../lib/src/shaders/), [shader tests](../../test/shaders/) |
| Reduced-motion policy, debugging, spring tuner and replay tools | [Accessibility guide](../accessibility.md), [debug tools](../../lib/src/debug/), [reduced-motion tests](../../test/runtime/hardening_reduced_motion_test.dart), [tuner tests](../../test/runtime/helpers_tuner_test.dart) |

Core paint-property animation avoids rebuilding its child each tick, guarded by
[the rebuild test](../../test/runtime/no_rebuild_test.dart). `NibValueBuilder`
and application listeners can rebuild. This distinction replaces the earlier
blanket claim that animation never rebuilds widgets.

## 2. Implemented with known limits

- Springs can inherit velocity; tweens do not honor initial velocity in the
  same way. Explicit value assignment and stopping have their own semantics;
  see [interruption](../interruption.md).
- Shared `layoutId` transitions require a scope and replacement of one owner
  with another within the snapshot window. Two mounted owners do not create a
  shared transition. Offscreen lazy items have no retained origin.
- Perspective, near-singular transforms, and some independently transformed
  clipping arrangements are outside the verified layout contract. Clip-size
  animation cannot retain pixels that the final child no longer paints. See
  [layout limits](../layout.md).
- `NibTimeline.play()` does not drive scrub `progress`. Cancelling pending
  entries can leave that run's future unresolved; already-started controller
  animations continue. `seek()` derives omitted `from` values from preceding
  targets and initial state. See [timeline cancellation](../timeline.md#cancellation-limit)
  and [its regression tests](../../test/runtime/timeline_relative_test.dart).
- Shader support and fallbacks depend on the renderer. Web compilation and
  an Impeller test pass do not establish identical visuals on every GPU.
- Externally owned controllers and motion values need disposal. External
  drivers must apply the application's accessibility policy themselves.

[Compatibility](../compatibility.md) collects these limits. The existing
[performance report](../performance.md) keeps its workload, machine, renderer,
and measurement qualifications. No new device benchmark was run, and this
candidate makes no competitor-speed or universal frame-rate claim.

## 3. Renderer-specific capabilities

[Water rendering](../water.md) is part of the stable public API. Its renderer
and sampling limits remain explicit.
Its sampling modes operate on a designated finite Flutter background subtree.
Platform views, inverse-warp hit testing, and a bound on total GPU memory are
outside the contract. Input-texture budgets do not cover engine intermediates.
Use rendering status and a fallback when demonstrating it on an unfamiliar
renderer. The presentation runbook uses stable motion examples first.

## 4. Planned or incomplete

There is no new engine feature promised by this release. The old runtime task
list is [archived](history/runtime-development-2026-10-14.md); checked or unchecked
historical items are not a current roadmap.

Remaining work includes representative device/raster measurements, broader
renderer visual checks, and owner-controlled release protection/trusted
publishing setup. Timeline cancellation semantics and unsupported layout
geometry remain documented limits, not fixes claimed by `0.3.6`. Publication,
installation from the new pub.dev archive, and its rendered package page require
the [approved release process](release.md).

## 5. Documentation gaps addressed

The new [guide index](../README.md) connects older `.mdx` tutorials with the
newer runtime-contract guides. The README now exposes springs and interruption,
gesture/drag behavior, shared layouts and presence, scroll/orchestration,
visual effects, accessibility, and development tools as coherent groups.

New compatibility, troubleshooting, and water guides make the
important limits discoverable. Migration guidance acknowledges the actual
strengths of Flutter Animate, Motor, and Fluid Motions; the supporting
[positioning research](positioning.md) records versions and sources.

Two complete README applications live in [the example app](../../example/lib/readme/).
[Tests](../../example/test/readme_test.dart) check that their source matches the
README and exercise entrance completion and spring retargeting. Contextual
guide fragments remain distinct from complete application entry points.

## 6. Incorrect or stale claims corrected

- Removed claims that NibMotion lacks visual timeline scrubbing or supports
  only scale-based layout size animation; the scrubber and clip mode already
  exist. Corrected stale sliver and simulation documentation.
- Corrected invalid variants construction, a nonexistent spring preset,
  `NibDrawPath` usage, missing example support widgets, and controller/value
  ownership in examples.
- Replaced website-shaped `/docs/...` links inside repository guides with
  repository-relative links. Kept existing guide paths for integrations.
- Corrected package shader registration advice: the dependency declares its
  shader assets; consumers do not repeat those declarations.
- Kept the combined `llms.txt` at the root because it is also used by the Nib
  website and components documentation. Excluded it and maintainer material
  from the pub archive rather than deleting useful reference material.
- Replaced stale task status with links to this audit and the release checklist.
- Added contributor, support, conduct, and security guidance. Private GitHub
  vulnerability reporting was enabled and verified before linking it.

## Validation evidence and limits

Local validation for the candidate passed:

| Check | Result |
| --- | --- |
| Flutter 3.29.0 package formatting, analyzer and tests | Clean; 847 tests passed |
| Flutter 3.29.0 example analyzer and tests | Clean; 55 tests passed |
| Flutter 3.47.8 package formatting, analyzer and tests | Clean; 847 tests passed |
| Flutter 3.47.8 example analyzer and tests | Clean; 55 tests passed |
| Impeller shader test lane | 55 tests passed |
| Example Wasm builds | Both `lib/main.dart` and `lib/demos.dart` built |

The first guide extraction contains 56 code blocks: 55 match the current guide
text exactly and one navigation example adds imports in the harness. Analysis
on Flutter 3.47.8's Dart SDK passed with no issues. The harness suppresses only
unused-import diagnostics. The manifest records each source path and block
number; this check covers compilation, not the runtime behavior of all guides.

The other 88 guide fences also pass static analysis on the same SDK in a
separate harness with typed surrounding state and placeholder child widgets.
Together the manifests account for all 144 Dart fences under `doc/`. This
establishes that the snippets use valid APIs in the supplied context; it does
not turn fragments into standalone applications or establish every example's
runtime behavior. The delivery report retains the manifests and logs.

The combined `llms.txt` has 80 Dart fences. All 29 motion fences pass static
analysis with imports and typed application context where needed. The remaining
51 component fences are outside this package's API audit. The delivery report
retains the motion manifest and records the runtime coverage separately.

Hosted CI, a clean committed publishing dry run, and the exact reviewed commit
remain release gates. See [the checklist](release.md) for the owner approval
boundary and post-publication verification.

## 0.3.4

* Keep duration-and-bounce spring parameters identical on Flutter 3.29 and
  newer SDKs without requiring the constructor introduced after 3.29.
* Keep exiting layout-enabled children at their painted bounds under rotated,
  nonuniformly scaled presence builders.
* Bundle Cupertino icon assets in the example Web build.
* Require Flutter 3.29 or newer because the shader APIs used by this package
  are unavailable in earlier supported SDKs.
* Keep drag, swipe, and reorder coordinates in their local spaces under scaled
  ancestors, including release velocity and reorder thresholds.
* Preserve the painted transform and child layout size when a presence exit is
  popped from a translated or scaled layout builder.
* Release detached layout snapshots after the shared-transition window, even
  when the scope receives no more layout records. Changing an attached
  `layoutId` or scope also removes the old snapshot.
* Point README links at the GitHub documentation because `doc/` is excluded
  from the pub archive.

## 0.3.3

* Render the approved ink mark in the pub.dev README with a PNG export. The SVG remains in the package as the editable source.

## 0.3.2

Runtime correctness release: interruption, coordinate spaces, presence, reduced
motion. All API changes are additive.

### ivent integration fixes
* `NibMotion` now rechecks viewport visibility after ancestor layout changes,
  including changes that do not rebuild the motion widget or move a scroll offset.
* Deferred repeat loops no longer run against a replaced or disposed controller.
* `NibPresence` reports missing and duplicate child keys before a child can be
  silently lost from its keyed collection.
* The bottom navigation indicator supports a liquid water style with a shader
  path and a gradient fallback, and stops moving for reduced-motion users.

### Final hardening
* `NibVisibility` now uses the exit target and timing supplied on the hide build.
* FLIP under a cached `RepaintBoundary` starts before paint for ordinary scoped boxes. Lazy sliver items retain the after-frame fallback.
* Verified that default layout channels compose with explicit x/y animation and that evicted lazy-list items reenter without a stale FLIP.
* The example now bundles Material icons so its Web build renders icons correctly.

### Fixed
* `MotionValue<double>` rejects non-finite initial values. `mapRange` rejects invalid stops and copies the stop lists, so a later caller edit cannot change an active mapping.
* Hit testing and `localToGlobal` now follow the painted transform of
  `NibMotion`, `NibDraggable` and `NibPinch`; gesture wrappers moved inside the
  transform. Previously a translated/scaled widget could not be tapped or
  re-grabbed where it was painted, and FLIP measured layout instead of paint.
* Futures returned by `animateTo`/`controller.start` no longer hang when the
  animation is superseded, stopped, delayed-then-replaced or its widget is
  disposed; they complete. `NibMotionController` no longer notifies after
  dispose.
* A delayed animation that had not started is cancelled by a later animation on
  the same properties (a stale target could fire afterwards).
* `NibPresence`: re-adding a child during its exit now animates it back instead
  of leaving it faded out; children follow the new order (exiting ones keep
  their slot).
* `NibLayoutGroup`: interrupting a FLIP no longer jumps; it continues from the
  painted position with its velocity.
* Springs settle exactly on their target with zero velocity.
* Reduced motion is honoured by `NibText*`, `NibTypewriter`, `NibDrawPath`,
  `NibPathMotion`, `NibFlip`, `NibShimmer`, `NibDissolve`, `NibDraggable`,
  `NibPinch`, `NibSwipeDismiss` and `NibNavBar` (previously only `NibMotion`).
* README examples corrected (`NibTransition.springSnappy`, `controller.start`,
  `motionValues:`).

### Added/Fixed (hardening pass, from reading Cue and flutter_animate_plus source)
* Numeric validation: springs, transitions and drivers reject NaN/infinite/zero-mass inputs (`ArgumentError` in debug, ignored in release) so a `MotionValue` can no longer be poisoned with NaN.
* `NibMotion` reacts when reduced motion turns on mid-animation (springs, tweens, delays, keyframes, loops finish).
* `NibShaderEffect(sampleChild: true)` feeds the child to the shader as sampler 0 (Impeller).
* `NibVisibility` (single-child show/hide with retained exit), `NibScrubRelease` modes on `NibTimelineDragScrubber`.
* `NibGlass`: rim refraction/highlight placed in the glass rect instead of the whole layer; non-finite `lightDirection` handled.
* `NibLayoutGroup` now runs on the per-widget FLIP; reverse-growth slivers; `NibPageRoute(parallax:)`; `NibSharedSource`.

### Fixed (review pass)
* Keyframe futures no longer hang when superseded/disposed; `controller.stop()` now stops keyframe and loop animations.
* Layout frame-hook and shared-layout snapshot leaks fixed; render-object listener cleanup for `rotateX/rotateY/blur/tint` corrected.
* `NibPageRoute(backSwipe)` shows the page underneath while dragging; `NibReorderable` paints the dragged item on top; `NibSpringTuner` honours its `initial` spring.

### Added (third pass)
* **Routes:** `NibModalRoute`, `showNibDialog`, `NibPageRoute` (opt-in edge `backSwipe`, `sharedFrom` grow-from-caller). Route stays until its exit settles. See `doc/routes.md`.
* **Sliver:** `NibSliverProgress`, `NibSliverHeaderDelegate` (progress as a `MotionValue`, safe to listen to). `layout:` now works in `ListView`/`GridView`/slivers (scroll-content space); `NibLayoutFrameHook` catches moves under a `RepaintBoundary` (sliver fallback can start one frame late).
* **Layout:** `layoutSizeMode: clip|scale`, `layoutTransition.delay`, `NibLayout.inherit` (default) so a child can opt out of `NibLayoutDefaults` with `NibLayout.none`; `NibPresence.layout(axis:)`; per-child `onChildEnter/Exit/Move`; `NibReorderable` spacing and auto-scroll; `NibPageProgress.tab`.
* **API friction:** `NibMotionController.velocityOf/velocities/motionValueOf`, `NibMotionValues(offset:)` + `NibOffsetMotionValue`, timeline `from:` derived automatically, widgets-only `NibTimelineScrubber`, `NibTransition.of(spring)` and `NibMotion(spring:)`, debug note when `initial` changes.
* **Tools:** `NibTimelineDragScrubber`, `NibSpringTuner`, `NibHotReloadReplay`.
* **Fixes:** `NibViewportProgress` publishes in the same frame and handles reversed/RTL scrollables; `NibValueBuilder` gains `transition:` and `withChild`; `NibSimulationDriver` lands exactly on its end.
* Example app: 21 demo screens (`flutter run -t lib/demos.dart`), 50 smoke/behaviour tests.

### Added (second pass, from the verified competitor comparison)
* **Layout:** `NibMotion(layout: NibLayout.position|size|both, layoutId:, layoutTransition:, onLayoutAnimationStart/Complete)` and `NibLayoutScope` — FLIP for any parent (Wrap, Stack, Row, Column, RTL), position and size, measured in layout space, interruption keeps painted position and velocity. Shared `layoutId` transitions across parents. `NibReorderable` (long-press drag reorder). `NibPresence`: `exitLayout: pop`, `stagger`/`staggerFrom`, `layoutBuilder`; exiting children are excluded from semantics and focus. See `doc/layout.md`.
* **Physics/values:** `NibSpringDescription.fromDuration(duration:, bounce:)` and `NibTransition.springWith`; `NibSpring` motion tokens (NibMotion-defined values); `MotionConverter` + `MultiSpringSolver` for independent per-axis physics on Offset/Size/Rect/Alignment/EdgeInsets/Color; `NibValueBuilder<T>`; `NibSimulationDriver` (run any Flutter `Simulation`); `NibSpringCurve`; `NibKeyframe.spring` (spring feel per keyframe segment). See `doc/physics.md`.
* **NibAnim:** `rotateX`, `rotateY` (perspective 3D), `blur`, `tint`.
* **Transitions:** `NibMotion.reverseTransition` (release/leave-view), `NibMotion.exitTransition`, `NibMotion.loopMode`.
* **Progress values:** `NibViewportProgress`, `NibPageProgress`.
* **Timeline:** relative timing (`after`, labels), `progress`/`seek`, `NibTimelineScrubber`; `NibLoopMode` (restart/pingPong/seamless) on `NibAnimationSequence.loop`. See `doc/timeline.md`.
* **Shaders:** `NibShaderEffect` (user fragment program with `MotionValue` uniforms), `NibShaderLoader.load`.
* **Debug:** velocity in the live-values view; reduced-motion toggle in `NibMotionDebugger`.

### Added (first pass)
* `MotionValue.velocity` and `MotionValue.update(value, velocity:)`; drivers
  publish velocity and new drivers start from it (spring/inertia/tween/drag/FLIP
  handoff). `mapRange` carries velocity through the mapping.
* `MotionValue.computed` / `ComputedMotionValue`: lazy multi-source derived
  values.
* `InertiaSolver.animateTo(velocity:, min:, max:)` with elastic overshoot and
  `boundsSpring`; `NibMotion` drag `inertia` release now respects
  `NibDragConfig.constraints`.
* `NibDragConfig.snapProjection`: pick the snap point a flick is heading to.
* `SpringSolver.animateTo` / `InertiaSolver.animateTo` return a `Future<void>`.
* `NibMotionConfig.watchReducedMotion` (subscribing lookup).
* `NibMotionController.set(..., keepVelocity:)`.
* Docs: `doc/` (architecture, interruption, motion values, accessibility,
  performance, migration), benchmarks in `benchmark/`, numeric trajectory
  goldens in `test/runtime/goldens/`.

## 0.3.1

* Fixed `NibScreenStack` swallowing taps on the incoming screen while its
  entrance transition was still settling.

## 0.3.0

* **Liquid Glass**: new `NibGlass` widget — a physically-modelled glass dome
  over the backdrop (Apple's Liquid Glass material), with Snell's-law
  refraction, chromatic aberration, and a light-driven specular highlight,
  rendered by the bundled `liquid_glass.frag` shader.
* **Glass nav bar**: `NibNavBarStyle` gains `glass`, `glassTint`, `glassBlur`,
  and `glassHighlight` — render `NibNavBar`/`NibScaffold`'s bar as a live
  liquid-glass surface.
* Added the `liquid_glass` shader asset (`NibShaderAssets.liquidGlass`) and
  loader (`NibShaderLoader.liquidGlass()`), preloaded alongside the other
  built-in shaders.
* Exported `NibGlass` from the package barrel.

## 0.2.1

* Added example app demonstrating core primitives.
* Fixed `curly_braces_in_flow_control_structures` lint issues.
* Improved pub.dev package description and metadata.
* Added CI/CD via GitHub Actions.

## 0.2.0

Framework expansion: text animation, GPU shaders, presets, gestures,
timeline orchestration, scroll utilities, path animation, and debug tools.

* **Text**: `NibText` (per-character/word/line stagger), `NibTypewriter`,
  `NibGradientText`, `NibTextReveal`, `NibTextConfig`.
* **Shaders**: GLSL `shimmer`/`dissolve`/`gradient_sweep` fragment shaders,
  `NibShimmer`, `NibDissolve`, `NibShaderLoader`; `NibMotionConfig.init()` to
  preload shaders and set process-wide defaults at startup.
* **Presets**: `NibAnimPresets` (shake/bounceIn/pulse/rubberBand/wiggle/
  fade*/zoom* constants), `NibShake`, `NibBounce`, `NibPulse`, `NibFloat`,
  `NibFlip`, `NibRubberBand`.
* **Gestures**: `NibDraggable` (bounded/elastic drag with snap-back/target),
  `NibPinch` (pinch-to-zoom), `NibSwipeDismiss`.
* **Timeline**: `NibTimeline` / `NibTimelineEntry` for multi-controller
  orchestration, `NibAnimationSequence` fluent builder
  (`animate`/`wait`/`call`/`loop`).
* **Scroll**: `NibParallax`, `NibScrollReveal`.
* **Path**: `NibPathMotion` (move a widget along a `Path`), `NibDrawPath`
  (progressively reveal a stroked `Path`).
* **Debug**: `NibMotionDebugger`, `NibPerfOverlay`, `NibMotionRegistry`.
* **Framework**: `NibMotionProvider`, `Widget.animate()/.shimmer()/
  .revealOnScroll()` extensions, `int.ms`/`int.seconds` duration shorthand.
* **Fix**: `NibNavBar` icons intermittently failed to render in release/AOT
  builds (most visibly the first item, sometimes all of them) — the old
  implementation pre-rendered each icon to a bitmap captured from an
  off-screen `RepaintBoundary` that sat fully occluded behind the bar's
  `CustomPaint` every frame, which the engine can skip rasterizing in
  release builds. Icons are now real `Icon` widgets scaled via
  `Transform.scale`, which stay crisp at any scale with no bitmap, no
  off-screen capture, and no race.

## 0.1.0

Initial release.

* `NibMotion`: declarative, physics-based animation widget driving opacity,
  translation, scale, rotation, skew, color, border radius, and box shadow
  via `initial`, `animate`, and `exit`.
* `NibAnim` / `NibTransition`: immutable animation snapshots and
  tween/spring transition descriptions, with `springGentle`, `springSnappy`,
  and `springWobbly` presets.
* Spring physics (`NibSpringDescription`, `SpringSolver`) and inertia-based
  coasting (`InertiaSolver`) for natural motion.
* Gesture-driven animation: `whileTap`, `whileHover`, `whileFocus`.
* Dragging via `NibDragConfig` — axis locking, constraints, elastic
  resistance, snap points, and spring-back/inertia/stay release behavior.
* `NibPresence`: plays `exit` animations for removed children before
  unmounting them.
* `NibVariants`: named animation states that propagate from a parent
  `NibMotion` to descendants, with `staggerChildren`/`delayChildren`.
* `NibMotionController`: imperative control of animations and multi-step
  sequences from outside the widget tree.
* `NibKeyframe` / `computeAnimFromKeyframes`: multi-stop enter animations.
* `NibMotionList`: a `NibMotion`-wrapped, optionally-staggered list.
* `NibLayoutGroup`: animates children to their new positions on layout
  changes using the FLIP technique.
* `ScrollMotionBridge` / `NibScrollMotion` / `NibMotionValues`: tie
  `MotionValue`s directly to scroll position, bypassing the animation
  system entirely.
* `MotionValue<T>` / `DerivedMotionValue` / `mapRange`: reactive value
  containers with derived/mapped values.
* `NibMotionConfig`: app-wide defaults and reduced-motion support.

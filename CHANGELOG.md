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

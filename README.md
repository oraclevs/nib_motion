<p align="center">
  <img src="https://www.nibmotion.xyz/brand/nib-mark.svg" alt="Nib logo with a fountain nib forming the I" width="180" />
</p>

<h1 align="center">NibMotion</h1>

<p align="center">
  Declarative animation for Flutter with springs, gestures, layout transitions, and shaders.
</p>

<p align="center">
  <a href="https://pub.dev/packages/nib_motion"><img src="https://img.shields.io/pub/v/nib_motion.svg?label=pub.dev&color=02569B" alt="pub.dev version" /></a>
  <a href="https://pub.dev/packages/nib_motion/score"><img src="https://img.shields.io/pub/points/nib_motion?color=02569B" alt="pub points" /></a>
  <a href="https://github.com/oraclevs/nib_motion/blob/main/LICENSE"><img src="https://img.shields.io/github/license/oraclevs/nib_motion?color=02569B" alt="license" /></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/platform-flutter-54C5F8.svg" alt="platform: flutter" /></a>
</p>

<p align="center">
  <a href="https://www.nibmotion.xyz">Website</a> ·
  <a href="https://www.nibmotion.xyz/examples">Examples</a> ·
  <a href="https://www.nibmotion.xyz/playground/spring-retarget">Playground</a> ·
  <a href="https://www.nibmotion.xyz/docs/motion/introduction">Documentation</a> ·
  <a href="https://pub.dev/packages/nib_motion">pub.dev</a>
</p>

---

## Preview

<p align="center">
  <img src="https://raw.githubusercontent.com/oraclevs/nib_motion/main/assets/nib_preview.gif" alt="NibMotion preview" width="720" />
</p>

## App demo

<p align="center">
  <img src="https://raw.githubusercontent.com/oraclevs/nib_motion/main/assets/daily_focus.gif" alt="Daily Focus app demo" width="340" />
</p>

---

## How it works

NibMotion lets you describe a widget's starting state, target state, and
transition in one place. Use a spring when the movement should respond to
interruption; use a tween when timing matters more.

The basic `NibMotion` widget does not require a controller. One is available
when an interaction needs imperative control. Underneath, `MotionValue`s carry
velocity, drivers (spring / tween / inertia / drag) that hand momentum to each
other, and render objects that repaint without rebuilding. Gestures, scroll,
layout, presence and shaders all sit on that same model — see
[doc/architecture.md](https://github.com/oraclevs/nib_motion/blob/main/doc/architecture.md).

---

## Installation

Requires Flutter 3.29 or newer. The package depends only on the Flutter SDK.

```bash
flutter pub add nib_motion
```

```dart
import 'package:nib_motion/nib_motion.dart';
```

---

## Quick start

```dart
NibMotion(
  initial: const NibAnim(opacity: 0, y: 20),
  animate: const NibAnim(opacity: 1, y: 0),
  child: const Text('Hello NibMotion'),
)
```

---

## Features

| Category | Features |
|---|---|
| **Core** | Declarative API, physics-based springs, zero external dependencies |
| **Gestures** | `whileTap`, `whileHover`, `whileDrag`, `whileFocus` |
| **Variants** | State-driven UI with cascading parent → child propagation |
| **Presence** | Exit animations before unmount |
| **Viewport** | Scroll-triggered entrance animations |
| **Layout** | `NibMotion(layout:)` FLIP for position + size under tested affine parents, shared `layoutId`, `NibReorderable`, `NibLayoutGroup` |
| **Motion Values** | Reactive values with velocity, `mapRange`, lazy `MotionValue.computed` — no widget rebuilds |
| **Physics** | Springs (mass/stiffness/damping or duration+bounce), `NibSpring` tokens, bounded inertia, independent per-axis physics (`MultiSpringSolver`), custom `Simulation`s, velocity handoff between drivers |
| **Keyframes** | Multi-step animations with easing control |
| **Text** | Per-char/word/line — `NibText`, `NibTypewriter`, `NibGradientText`, `NibTextReveal` |
| **Shaders** | GPU effects — `NibShimmer`, `NibDissolve` |
| **Liquid Glass** | `NibGlass` with shader refraction where supported and a blur fallback; glass `NibNavBar`/`NibScaffold` |
| **Water (experimental)** | `NibWaterController` and `NibWaterSurface` for bounded decorative droplets and waves over a captured Flutter subtree |
| **Navigation** | `NibNavBar` with spring-driven pill, dot, line, highlight, or liquid water indicators |
| **Presets** | `NibShake`, `NibBounce`, `NibPulse`, `NibFloat`, `NibFlip`, `NibRubberBand` |
| **Gestures+** | `NibDraggable`, `NibPinch`, `NibSwipeDismiss` |
| **Timeline** | `NibTimeline`, `NibAnimationSequence` for orchestration |
| **Path** | `NibPathMotion`, `NibDrawPath` |
| **Scroll** | `NibParallax`, `NibScrollReveal` |
| **Debug** | `NibMotionDebugger`, `NibPerfOverlay` |
| **Accessibility** | One reduced-motion policy (`NibMotionConfig`) honoured by every animated widget |

Layout and gesture coordinates are local logical pixels. The current geometry
regressions cover scaled reorder, rotated/nonuniform presence bounds and drag,
and hit exclusion during pop exits. Perspective, near-singular transforms,
reorder under rotation, and pop exits that must preserve an ancestor clip
across coordinate spaces are outside the verified contract. See the
[layout geometry contract](https://github.com/oraclevs/nib_motion/blob/main/doc/layout.md)
for the tested cases and lifecycle rules.

---

## Usage

### Gesture animations

```dart
NibMotion(
  whileTap: const NibAnim(scale: 0.95),
  whileHover: const NibAnim(scale: 1.05),
  child: YourWidget(),
)
```

### Variants

```dart
NibMotion(
  variants: {
    'open': NibAnim(y: 0, opacity: 1),
    'closed': NibAnim(y: 20, opacity: 0),
  },
  initial: 'closed',
  animate: isOpen ? 'open' : 'closed',
  child: YourWidget(),
)
```

### Keyframes

```dart
NibMotion(
  keyframes: [
    NibKeyframe(at: 0.0, value: NibAnim(opacity: 0, y: 30)),
    NibKeyframe(at: 0.6, value: NibAnim(opacity: 1, y: -5)),
    NibKeyframe(at: 1.0, value: NibAnim(opacity: 1, y: 0)),
  ],
  child: YourWidget(),
)
```

### Exit animations (presence)

```dart
NibPresence(
  children: [
    if (visible)
      NibMotion(
        key: const ValueKey('item'),
        initial: const NibAnim(opacity: 0, y: 20),
        animate: const NibAnim(opacity: 1, y: 0),
        exit: const NibAnim(opacity: 0, y: 20),
        child: YourWidget(),
      ),
  ],
)
```

### Viewport animations

```dart
NibMotion(
  initial: const NibAnim(opacity: 0, y: 30),
  whileInView: const NibAnim(opacity: 1, y: 0),
  viewport: const NibInViewConfig(amount: 0.2),
  child: YourWidget(),
)
```

### Layout animations (FLIP)

```dart
NibLayoutGroup(
  children: tasks.map((t) => TaskCard(t)).toList(),
)
```

### Spring physics

```dart
NibMotion(
  animate: const NibAnim(x: 100),
  transition: NibTransition.springSnappy,
  child: YourWidget(),
)
```

Springs are **interruptible**: change `animate` mid-flight and the new motion
starts from the current position *and velocity*, whatever driver was running
(spring, tween, inertia, drag). See [doc/interruption.md](https://github.com/oraclevs/nib_motion/blob/main/doc/interruption.md).

### Reactive motion values

```dart
final progress = MotionValue<double>(0);
final boost = MotionValue<double>(1);

// Single source, eager, velocity flows through the mapping:
final opacity = progress.mapRange([0, 1], [0.2, 1]);

// Several sources, lazy — evaluated when painted:
final scale = MotionValue.computed(
  [progress, boost],
  () => 0.9 + progress.value * 0.1 * boost.value,
);
```

See [doc/motion-values.md](https://github.com/oraclevs/nib_motion/blob/main/doc/motion-values.md).

### Drag with inertia, bounds, and snap

```dart
NibMotion(
  drag: NibDragConfig(
    constraints: Rect.fromLTRB(-200, 0, 200, 0),
    releaseMode: NibDragReleaseMode.inertia, // coasts, bounces off the bounds
  ),
  child: YourWidget(),
)

NibMotion(
  drag: NibDragConfig(
    snapPoints: [Offset(0, 0), Offset(0, 300)],
    snapProjection: Duration(milliseconds: 150), // a flick reaches the next point
  ),
  child: YourWidget(),
)
```

### Liquid glass

```dart
NibGlass(
  refractiveIndex: 1.2,
  chromaticAberration: 0.03,
  thickness: 20,
  child: const Text('Liquid Glass'),
)
```

Shader refraction depends on the renderer. On unsupported renderers, the glass
uses a frosted blur fallback.

### Liquid navigation indicator

`NibNavBar` can draw a liquid indicator that travels between items. The shader
has a gradient fallback, and reduced motion leaves the indicator at rest.

```dart
NibNavBar(
  items: items,
  currentIndex: selectedIndex,
  onIndexChanged: (index) => setState(() => selectedIndex = index),
  indicator: const NibNavIndicatorStyle(type: NibNavIndicatorType.liquid),
)
```

### Scroll-linked motion

```dart
final bridge = ScrollMotionBridge(controller: scrollController);

NibMotion(
  motionValues: NibMotionValues(
    opacity: bridge.scrollY.mapRange([0, 200], [1, 0]),
  ),
  child: YourWidget(),
)
```

### Imperative controller

```dart
final controller = NibMotionController();

NibMotion(
  controller: controller,
  child: YourWidget(),
);

await controller.start(target: const NibAnim(scale: 1.2));
```

### Reduced motion

```dart
NibMotionConfig(
  reducedMotion: true,
  child: MyApp(),
)
```

---

## Philosophy

For continuous motion, `MotionValue` notifications repaint the render object
without rebuilding the widget tree on every frame. Discrete content changes,
such as a typewriter advancing to its next character, still rebuild when they
need to. `NibFlip` also rebuilds its focus and semantics wrappers when the
visible face changes.

---

## Examples and support

Browse [motion examples](https://www.nibmotion.xyz/examples), read the
[guides](https://www.nibmotion.xyz/docs/motion/introduction), or try the
[playground](https://www.nibmotion.xyz/playground/spring-retarget).
The [example app](https://github.com/oraclevs/nib_motion/tree/main/example)
contains runnable demos. From its directory, run `flutter pub get`, then
`flutter run -t lib/demos.dart`.

The experimental water surface samples its designated Flutter background.
Existing callers keep the legacy snapshot path. Opt in with
`sampling: NibWaterSampling.live`, device-relative `NibWaterQuality`, clear/depth
`NibWaterMaterial` optics and a bounded `NibBubbleEmitter`. The live path retains
real underwater widgets and composites their sampled pixels once. Failed sampling
shows direct content; this fallback is not refraction. Platform views and pixels
outside the subtree are unsupported. The model is decorative 2D/2.5D, with original
hit-test geometry. Browser parity and sustained performance across physical
devices remain unverified.

For bugs and feature requests, [open an issue](https://github.com/oraclevs/nib_motion/issues)
with a small reproduction, your Flutter version, platform, and renderer.

## License

MIT — see [LICENSE](LICENSE).

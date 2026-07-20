<p align="center">
  <img src="https://raw.githubusercontent.com/oraclevs/nib_motion/main/assets/niblogo.png" alt="NibMotion Logo" width="120" />
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/oraclevs/nib_motion/main/assets/nibbanner.png" alt="NibMotion Banner" width="100%" />
</p>

<h1 align="center">NibMotion</h1>

<p align="center">
  A declarative, physics-based animation framework for Flutter — inspired by Framer Motion.
</p>

<p align="center">
  <a href="https://pub.dev/packages/nib_motion"><img src="https://img.shields.io/pub/v/nib_motion.svg?label=pub.dev&color=02569B" alt="pub.dev version" /></a>
  <a href="https://pub.dev/packages/nib_motion/score"><img src="https://img.shields.io/pub/points/nib_motion?color=02569B" alt="pub points" /></a>
  <a href="https://github.com/oraclevs/nib_motion/blob/main/LICENSE"><img src="https://img.shields.io/github/license/oraclevs/nib_motion?color=02569B" alt="license" /></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/platform-flutter-54C5F8.svg" alt="platform: flutter" /></a>
</p>

<p align="center">
  <a href="https://www.nibmotion.xyz/motion">Live Demo</a> ·
  <a href="https://www.nibmotion.xyz/docs">Documentation</a> ·
  <a href="https://pub.dev/packages/nib_motion">pub.dev</a>
</p>

---

## Preview

<p align="center">
  <img src="https://raw.githubusercontent.com/oraclevs/nib_motion/main/assets/nib_preview.gif" alt="NibMotion preview" width="720" />
</p>

## App Demo

<p align="center">
  <img src="https://raw.githubusercontent.com/oraclevs/nib_motion/main/assets/daily_focus.gif" alt="Daily Focus app demo" width="340" />
</p>

---

## Why NibMotion?

Flutter animations require `AnimationController` boilerplate, tweens everywhere, and complex rebuild logic. NibMotion replaces that with a simple mental model:

> Describe how your UI should look in different states — NibMotion handles the rest.

**No controllers. No tweens. Just state.**

---

## Installation

```bash
flutter pub add nib_motion
```

```dart
import 'package:nib_motion/nib_motion.dart';
```

---

## Quick Start

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
| **Layout** | FLIP animations for reorder/resize |
| **Motion Values** | High-performance reactive values — no widget rebuilds |
| **Keyframes** | Multi-step animations with easing control |
| **Text** | Per-char/word/line — `NibText`, `NibTypewriter`, `NibGradientText`, `NibTextReveal` |
| **Shaders** | GPU effects — `NibShimmer`, `NibDissolve` |
| **Liquid Glass** | `NibGlass` — Apple-style glass with real refraction, chromatic aberration & specular light; glass `NibNavBar`/`NibScaffold` |
| **Presets** | `NibShake`, `NibBounce`, `NibPulse`, `NibFloat`, `NibFlip`, `NibRubberBand` |
| **Gestures+** | `NibDraggable`, `NibPinch`, `NibSwipeDismiss` |
| **Timeline** | `NibTimeline`, `NibAnimationSequence` for orchestration |
| **Path** | `NibPathMotion`, `NibDrawPath` |
| **Scroll** | `NibParallax`, `NibScrollReveal` |
| **Debug** | `NibMotionDebugger`, `NibPerfOverlay` |
| **Accessibility** | Automatic reduced-motion support |

---

## Usage

### Gesture Animations

```dart
NibMotion(
  whileTap: const NibAnim(scale: 0.95),
  whileHover: const NibAnim(scale: 1.05),
  child: YourWidget(),
)
```

### Variants (State System)

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

### Exit Animations (Presence)

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

### Viewport Animations

```dart
NibMotion(
  initial: const NibAnim(opacity: 0, y: 30),
  whileInView: const NibAnim(opacity: 1, y: 0),
  viewport: const NibInViewConfig(amount: 0.2),
  child: YourWidget(),
)
```

### Layout Animations (FLIP)

```dart
NibLayoutGroup(
  children: tasks.map((t) => TaskCard(t)).toList(),
)
```

### Spring Physics

```dart
NibMotion(
  animate: const NibAnim(x: 100),
  transition: NibTransition.spring(NibSpringDescription.snappy),
  child: YourWidget(),
)
```

### Liquid Glass

```dart
NibGlass(
  refractiveIndex: 1.2,
  chromaticAberration: 0.03,
  thickness: 20,
  child: const Text('Liquid Glass'),
)
```

### Scroll-Linked Motion

```dart
final scrollY = ScrollMotionBridge(controller: scrollController);

NibMotion(
  animate: NibAnim(opacity: scrollY.mapRange([0, 200], [1, 0])),
  child: YourWidget(),
)
```

### Imperative Controller

```dart
final controller = NibMotionController();

NibMotion(
  controller: controller,
  child: YourWidget(),
);

await controller.animateTo(const NibAnim(scale: 1.2));
```

### Reduced Motion

```dart
NibMotionConfig(
  reducedMotion: true,
  child: MyApp(),
)
```

---

## Philosophy

NibMotion is built around one idea:

> UI should be described, not animated manually.

It gives Flutter a motion model closer to modern UI frameworks like Framer Motion — but fully native, performant, and Flutter-optimized. **Animating never triggers a widget rebuild** — `MotionValue` notifications call `markNeedsPaint` directly on the render object.

---

## License

MIT — see [LICENSE](LICENSE).

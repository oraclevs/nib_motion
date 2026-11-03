---
{
  "id": "api",
  "evidence": "MotionNib/motion/lib/nib_motion.dart; MotionNib/motion/llms.txt"
}
---

# API reference

Find the public entry point for a concrete animation job.

<!-- section: first-choice -->
## Pick the smallest useful entry point

For a button that fades or moves between two known states, begin with NibMotion and NibAnim. NibAnim describes target properties such as opacity, x, y, scale, and rotation. NibTransition describes timing: a spring uses mass, stiffness, and damping; a tween uses duration and curve. Keep the resting target in animate and let Flutter state decide when to change it. A controller is useful only when an event must command an animation independently of a build.

If you need an item to move because Row, Column, or Wrap changed its layout, use layout and stable keys. If an item is removed but needs an exit, place keyed children under NibPresence. These two families can work together, but an ordinary NibAnim translation will not update the parent’s layout slot. The layout and presence guides show where each wrapper belongs.

```dart
// In build().
NibMotion(
  initial: const NibAnim(opacity: 0, y: 12),
  animate: const NibAnim(opacity: 1, y: 0),
  transition: const NibTransition(duration: Duration(milliseconds: 300)),
  child: const Text('Ready'),
)
```

<!-- section: core -->
## Start with the public barrel

Import package:nib_motion/nib_motion.dart. NibMotion, NibAnim, NibTransition, NibSpringDescription, MotionValue, and NibMotionValues cover most state-to-paint interactions. NibMotionController is optional when a host needs imperative start, stop, set, or sequence.

NibMotion accepts a required child, initial and animate states, temporary gesture states, keyframes, viewport state, layout options, and an optional controller. Only add the features the interaction needs.

<!-- section: families -->
## Choose the matching family

NibPresence handles removal; NibLayoutScope and layout options handle measured movement; NibScrollReveal and NibScrollMotion connect visibility and scroll position. NibText, NibDrawPath, NibPathMotion, NibTimeline, and route widgets solve different kinds of sequencing.

The barrel also exports shaders, presets, physics drivers, and debug overlays. Most apps should use the higher-level widgets before constructing a SpringSolver or RenderNibMotion directly.

<!-- section: value-or-widget -->
## Decide who owns changing values

When a value changes every frame or follows input directly, a MotionValue can connect the input to painting without rebuilding the child for each tick. It has a current value, listeners, and velocity for numeric motion. NibMotionValues maps external values to NibMotion properties; the caller creates and disposes those external values. A controller, by contrast, tells one or more widgets to begin, stop, or sequence an animation and exposes the first attached widget’s property value when needed.

For path drawing and path following, choose NibDrawPath or NibPathMotion and their own controllers. For text, use NibText for units, NibTextReveal for a block clip, and NibTypewriter for discrete character changes. For scroll-linked progress, start from the scroll family. Each public family has different ownership and update rules; avoid building directly on a render object until the higher-level widget is demonstrably inadequate.

<!-- section: reading-reference -->
## Use the generated reference as a map

The API browser lists declarations exported by the public package barrel, with their source documentation and member signatures. Search for a type after you know the behavior you want, then read its constructor defaults and callbacks in context. A signature tells you that a parameter exists; it cannot explain how layout space, cancellation, or accessibility behave. This guide links those decisions to the deeper topic pages.

As a practice task, build the small fade above, then replace the tween with NibTransition.springGentle and compare interruption while toggling the parent state. Next inspect NibMotionController in the API browser and decide whether the use case actually needs start() or if a changing animate value is simpler. Run the snippet against the exact dependency graph in your pubspec.lock; the 0.3.6 gallery candidate is separate from the hosted 0.3.5 API.

<!-- section: boundaries -->
## Check ownership and version

The widget owns its internal animation values. The caller owns a controller, a MotionValue passed through NibMotionValues, and a directly created ScrollMotionBridge. Read the guide for that family before wiring disposal.

These Motion guides target published 0.3.5. Version 0.3.6 remains a review candidate. Check pubspec.lock when comparing an older example or API reference.

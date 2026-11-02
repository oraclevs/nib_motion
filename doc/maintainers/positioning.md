# Positioning review

Research date: November 2, 2026. This is a maintainer reference for public copy,
not a feature-parity scorecard.

## Selected message

**Motion that follows your UI.**

Build Flutter interfaces with declarative targets, interruptible springs,
gestures, layout transitions and GPU effects. Connect them through reactive
motion values, with APIs for scroll, orchestration and exit lifetimes.

The headline describes a concrete relationship: the interface can change its
target while motion is running. It also leaves room for layout and presence,
which are important parts of the package beyond individual effects. The copy
speaks to developers evaluating a framework and leads to an install and a small
working example.

Two alternatives were considered:

- “Motion that feels alive.” Short and expressive, but generic enough for almost
  any spring library. It gives the reader less information.
- “Describe the next state. Keep the motion.” Emphasizes state and interruption,
  but can imply that every transition preserves velocity. Tweens do not accept
  an initial velocity; the selected wording avoids that ambiguity.

The writing diagnosis was a full rewrite with an existing technical voice.
Keep the source-backed substance, expose the main argument early, and move
detailed reference material out of the landing page. The writer is a maintainer
who can explain a moving card and its lifecycle without a sales pitch.

## Current alternatives

Versions were checked through pub.dev's package API and their published source
archives. The comparisons below describe supported entry points, not everything
an application could build with each package.

| Approach | Verified APIs and strengths | Relevant NibMotion distinction |
|---|---|---|
| [Flutter Animate 4.5.2](https://pub.dev/packages/flutter_animate/versions/4.5.2) | Chainable `.animate()` effects, sequencing, `Animate.target` for state changes, external controllers, adapters including `ScrollAdapter`, and `ShaderEffect`. Its `Animate` implementation drives an `AnimationController`. | NibMotion exposes target properties and spring transitions alongside drag release, measured layout and presence lifetimes. Explain that combined workflow; do not call Flutter Animate stateless or limited to entrance effects. |
| [Motor 1.1.0](https://pub.dev/packages/motor/versions/1.1.0) | `MotionBuilder`, `SingleMotionBuilder`, `MotionConverter`, sequences and `MotionDraggable`. `MotionController.animateTo` starts simulations with current per-dimension velocities unless overridden. | NibMotion adds its own widget-level layout/presence and render-object motion-value APIs. Velocity continuity and multidimensional springs are shared concepts, not unique claims. |
| [Fluid Motions 0.0.5](https://pub.dev/packages/fluid_motions/versions/0.0.5) | `.fluidInteractable()`, `.fluidDraggable()`, `FluidTransform`, `FluidContainer`, action buttons and switches. Its spring simulations use controller or drag-release velocity. | Its exported surface focuses on physical interactions and active/inactive widgets. NibMotion's documented surface also includes layout, presence, scroll orchestration and shader primitives. Do not infer quality or speed from package size or version. |
| [Flutter SDK physics](https://api.flutter.dev/flutter/physics/SpringSimulation-class.html) | `SpringSimulation` accepts initial position, target and velocity, and can drive an `AnimationController`. | NibMotion packages coordination around these kinds of motion concerns. Flutter itself can implement physics and preserve velocity when application code supplies it. |

Source inspected: `flutter_animate/lib/src/animate.dart` and its adapter/effect
exports; Motor's `motion_controller.dart` and `motor.dart`; Fluid Motions'
export barrel, `fluid_interactable.dart`, `fluid_draggable.dart` and state
widgets. Recheck these sources before using this comparison for a later release.

## Evidence behind the NibMotion argument

- [Public exports](../../lib/nib_motion.dart) establish which APIs consumers can
  import.
- [Motion values](../motion-values.md) and
  [render-object source](../../lib/src/core/render_nib_motion.dart) explain
  paint-driven property updates. Content changes and builder APIs may rebuild.
- [Interruption](../interruption.md) distinguishes spring velocity transfer,
  tween behavior, stops and explicit jumps.
- [Layout](../layout.md), [presence](../presence.mdx) and
  [accessibility](../accessibility.md) define behavior and limits.
- [Performance](../performance.md) includes reproducible harnesses and explicit
  measurement qualifications. No direct Flutter Animate speed comparison was
  established by this review.

Claims of best performance would require representative, reproducible workloads
on named devices and renderers, with versions, warm-up, samples and uncertainty
reported. Claims of broad production validation would require deployment and
device evidence. Neither belongs in this release's copy.

## Existing media review

| Asset | Inspection | Decision |
|---|---|---|
| `assets/nib_preview.gif` | 720 × 429; 12 seconds; 144 frames; 1,266,266 bytes. Shows text effects followed by the shader screen. Desktop title bar says `test_temp`. | Useful near the hero with an accurate text/shader caption. It does not demonstrate dragging or layout. |
| `assets/daily_focus.gif` | 340 × 658; 12 seconds; 144 frames; 3,580,363 bytes. Shows a task-list app with navigation. Desktop title bar is visible. | Secondary example of an interface using motion. Keep it below the quick start. |
| `assets/nibbanner.png` | Existing blue brand treatment, but its code includes `NibTransition.spring`, which is not a current named preset. Its exit snippet omits the required identity/context. | Retain as a historical asset; do not promote it as current API guidance or social preview. |

Both GIFs are recordings at 12 frames per second. They are demonstrations, not
performance measurements. The older text/shader showcase entry point is absent
from the checkout; the current runnable demos live under `example/`.

Preserve the existing logo. New recordings can remove desktop chrome and show
retargeting or layout directly when a capture environment is available. They
are not required to explain the existing APIs accurately.

## Repository metadata and social preview

The repository description was updated and read back on November 2:

> Physics-driven motion for Flutter: declarative animation, interruptible
> springs, gestures, shared layouts, scroll-linked values, and GPU effects.

Topics are `animation`, `dart`, `flutter`, `flutter-package`, `gestures`,
`layout-animation` and `spring-physics`. The homepage remains
`https://www.nibmotion.xyz`.

The owner can set a social preview without commissioning another asset:

1. Open the repository's **Settings**, then **General**.
2. Under **Social preview**, choose **Edit**, then **Upload an image**.
3. Select the existing `assets/nib-logo.png` (710 × 420, 19,888 bytes).
4. Check the preview crop and contrast on light and dark backgrounds before
   retaining it. Use the logo, not the outdated code banner.

This file meets GitHub's documented minimum image dimensions and size limit.
GitHub recommends 1280 × 640 for best display; that optional redesign can wait.
See [GitHub's social preview instructions](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/customizing-your-repositorys-social-media-preview).

# Migrating to NibMotion

Concept maps, not syntax translations. Competitor APIs change; check each
package's own docs for current signatures. NibMotion names below are verified
against this repository.

## flutter_animate → NibMotion

| flutter_animate idea | NibMotion equivalent | Difference that matters |
|---|---|---|
| `widget.animate().fadeIn().slideY(...)` chained effects | `NibMotion(initial: NibAnim(opacity: 0, y: 20), animate: NibAnim(opacity: 1, y: 0))` | One target snapshot, not a list of effects. Effects that are combinations of opacity/translate/scale/rotate/skew/color/radius/shadow are just `NibAnim` fields. |
| `.animate(target: 0/1)` | change `animate:` (or a variant name) | Retargets from current position **and velocity**; no controller to manage. |
| `onPlay: (c) => c.repeat()` | `repeatAnimationInLoop: true` / `controller.repeat()` | |
| Effect timelines with delays/intervals | `NibTimeline`, `NibAnimationSequence`, `NibTransition(delay:)`, `staggerChildren` | |
| Shader/blur effects | `NibShimmer`, `NibDissolve`, `NibGlass` | Uniforms are `MotionValue`s, no rebuild per frame. |
| ~100 named effects | not replicated | Deliberate: compose `NibAnim`/keyframes instead of maintaining an effect zoo. |

Conceptual shift: flutter_animate describes a *sequence played by a controller*;
NibMotion describes *states and how to move between them*, so interruption is
natural rather than an edge case.

## cue → NibMotion

| Cue idea | NibMotion equivalent |
|---|---|
| trigger (mount / toggle / hover / focus / scroll / visibility) | `animate` change, `whileHover`, `whileFocus`, `whileInView`, `ScrollMotionBridge` |
| actor + acts | `NibMotion` + `NibAnim` fields |
| motion law (spring/curve) | `NibTransition` (`spring:` or `duration`/`curve`) |
| keyframes / timelines | `NibKeyframe` + `keyframes:`, `NibTimeline` |
| scrubbing (external progress) | drive a `MotionValue` and use `motionValues:` / `mapRange` |
| animation scrubber tool | `NibMotionDebugger`, `NibMotionRegistry` (live values) — no visual scrubber yet |

## animated_to → NibMotion

| animated_to idea | NibMotion equivalent |
|---|---|
| animate a widget between layout positions when it moves | `NibLayoutGroup` (FLIP, position) |
| spring retargeting keeps velocity | built in: `SpringSolver` and every `NibMotion` retarget inherit `MotionValue.velocity` |
| per-widget zero-config | `NibMotion(layout: NibLayout.position)` — any parent (Wrap, Stack, Row, Column), no GlobalKey; see [layout.md](layout.md) |

## layout_motion → NibMotion

| layout_motion idea | NibMotion equivalent |
|---|---|
| keyed FLIP of list children | `NibLayoutGroup(children: […keyed…])` |
| retained exits | `NibPresence` + `NibMotion(exit:)` (keeps the child mounted, ignores pointer) |
| interrupt from the painted transform | done: FLIP measures the painted position and keeps velocity |
| size FLIP | `layout: NibLayout.size/both` (scale FLIP; no clip variant yet) |
| reorder gestures | `NibReorderable` |
| shared layout ids | `layoutId` + `NibLayoutScope` |
| pop exit | `NibPresence(exitLayout: NibExitLayout.pop)` |
| LIS move classification, sliver lists | not implemented (measurement-based FLIP skips unmoved children; slivers unsupported) |
| reduced motion | `NibMotionConfig` (global policy) |

# Product marketing context

Document version: v1  
Last updated: 2026-11-02

This working brief comes from the maintainer's launch mission and the package
source. Audience needs below are positioning hypotheses, not customer research.

## Product overview

NibMotion is a declarative, physics-driven motion framework for Flutter. It
connects animation targets, spring physics, gestures, reactive motion values,
layout, presence, scroll and visual effects. Developers describe the next state;
the framework handles the transition. It is an MIT-licensed package,
`nib_motion`, with no runtime pub dependencies beyond Flutter.

## Audience and jobs

Flutter developers building interactive applications are the primary audience.
They want cards that respond while moving, content that reflows when state
changes, and consistent motion across navigation and overlays. The adoption
decision is whether these connected primitives make an application's motion
easier to express and maintain.

The primary action is to install the package and run one example. The next
action is to try that interaction in an existing app. Contributor onboarding
should make a small reproduction, documentation correction or regression test
straightforward.

## Problem and differentiation

As interactions grow, application code must coordinate target changes, release
velocity, widget removal and layout changes. NibMotion provides APIs for those
jobs around a shared motion-value model. `NibMotion` paints continuous property
changes through its render object; `NibPresence` owns exit lifetimes; layout
primitives handle measured geometry changes.

Use this connection as the central argument. Springs, state-driven animation
and shader effects are not exclusive to NibMotion. The dated
[positioning review](../doc/maintainers/positioning.md) records the alternatives
and their strengths. There is no evidence for universal performance superiority
or for why customers choose NibMotion.

## Adoption questions

| Question | Honest answer |
|---|---|
| Does it fit my existing app? | Start with one widget or screen. Read the public API and migration guide before replacing existing motion. |
| Will it run well on my devices? | Profile the actual scene. Existing benchmark results have specific hardware and workload limits. |
| Is every feature equally mature? | No. Water is experimental. Shader support depends on the renderer; layout has a documented geometry contract. |

Familiarity with Flutter's controllers and an existing effects library can make
switching unnecessary for a small, finished animation. NibMotion is most useful
to evaluate when several interaction and lifecycle concerns need to work
together. It does not promise a visual animation editor or general fluid
simulation.

## Language and voice

Use the product name **NibMotion** and package identifier **`nib_motion`**.
Explain named APIs with observable behavior. Preserve the existing nib/ink
identity and Flutter-blue accents. Use the actual logo assets without redrawing
them.

| Voice | Practice | Example |
|---|---|---|
| Direct | Lead with what the developer can build. | “Motion that follows your UI.” |
| Technical | Tie an architectural claim to its scope. | “The core render object reads motion values during paint.” |
| Candid | Put limitations next to the affected feature. | “Water rendering is experimental.” |

Support copy should request a small reproduction. Launch copy should show an
interaction and link to its code. Avoid “best,” “production-proven,” “animate
anything,” unqualified “zero rebuilds,” and competitor speed claims. No customer
quotes, adoption figures, partnerships or testimonials have been verified.

## Proof and goals

The public export barrel, source, regression tests and runnable example screens
support capability claims. Performance claims must preserve the qualifications
in [performance.md](../doc/performance.md). Fresh validation results belong in
the release audit, not in permanent marketing slogans.

The immediate goal is a credible repository introduction for November 3, 2026.
GitHub, pub.dev and the documentation website should lead to a working install
and example. No conversion baseline or campaign results are available.

## Learnings

No audience or campaign results have been recorded.

## Changelog

- v1 (2026-11-02): Initial context from the launch brief, source inspection and
  current package research.

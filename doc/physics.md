# Physics, tokens and multi-axis values

## Springs by feel

`NibSpringDescription.fromDuration(duration:, bounce:)` builds a spring from
how it should feel: `duration` is the perceptual settling time and `bounce` is
`-1..1` (`0` = critically damped, positive overshoots, negative is overdamped).
Mass is fixed at 1. `NibTransition.springWith(duration:, bounce:, delay:)` is the
transition shortcut. Raw mass/stiffness/damping and the `gentle/snappy/wobbly/stiff`
presets still work.

## Tokens: `NibSpring`

Named by role, defined by NibMotion (each is a `fromDuration` of a duration and
bounce; they are **not** Material 3 or Apple numbers):

| Token | Feel |
|---|---|
| `spatialFast / Default / Slow` | movement and resizing, small overshoot (~300/450/700 ms) |
| `effectsFast / Default / Slow` | opacity/colour, never overshoot (~150/250/400 ms) |
| `interactive` | follows a finger, ~200 ms, no overshoot |
| `smooth`, `snappy`, `bouncy` | general purpose |

`NibSpring.smooth.transition` gives the matching `NibTransition`.

## Independent-axis physics

`MotionValue<double>` is one channel. For composite values, a `MotionConverter<T>`
splits `T` into scalar channels (`Offset`, `Size`, `Rect`, `Alignment`,
`EdgeInsets`, `Color`, `double`, or `MotionConverter.custom`) and
`MultiSpringSolver<T>` runs one spring **per channel**: each axis keeps its own
position and velocity, retargeting continues every axis's momentum, and the
composed value is written once per frame.

```dart
final pos = MotionValue<Offset>(Offset.zero);
final solver = MultiSpringSolver<Offset>(
    vsync: this, value: pos,
    converter: MotionConverter.offset, spring: NibSpring.spatialDefault);
solver.animateTo(const Offset(300, 40));        // x and y spring independently
solver.animateTo(Offset.zero);                  // both continue from their own velocity
```

* An outside assignment to the value between animations is a jump (velocities reset).
* `animateTo(..., immediate: true)` jumps (use for reduced motion).
* `MotionValue.velocity` stays scalar; read per-axis velocities from
  `solver.velocities`.

`NibValueBuilder<T>(target:, builder:)` wraps this for layout-affecting or
arbitrary values (`EdgeInsets`, `Size`, `Rect`, a `Color` for a painter). It
**rebuilds the builder subtree each frame**; prefer `NibMotion` for paint-only
properties. It honours `NibMotionConfig` reduced motion.

## Running any Flutter simulation

`NibSimulationDriver` runs any `Simulation` (`GravitySimulation`,
`ClampingScrollSimulation`, your own) on a `MotionValue<double>`, publishing
velocity so a spring or inertia can take over, and resolving its future when the
simulation finishes or is superseded/stopped. A simulation is written until its
`isDone`, so the final frame can pass its end by up to one frame of travel.

## Continuous progress values

* `NibViewportProgress` + `NibViewportProgressController`: `progress` (0 = about to
  enter, 0.5 = centred, 1 = fully left) and `visibleFraction` as `MotionValue`s.
  Listens to every ancestor `Scrollable`, measures against the nearest one, and
  never rebuilds. Values lag scrolling by at most one frame.
* `NibPageProgress(pageController)`: the fractional `page`, plus `closeness(i)`
  and `offsetFrom(i)` derived values.

## Not covered

Duration-based springs that also honour `mass` other than 1, a spring visualiser,
and per-channel velocity on `MotionValue<T>` for non-scalar `T`.

## Spring tokens as transitions

`NibTransition.of(NibSpring.smooth)`, `NibSpring.smooth.transition`, or the
shorthand `NibMotion(spring: NibSpring.smooth)` (mutually exclusive with
`transition:`).

## `NibValueBuilder`: tween, spring, and not rebuilding the static part

```dart
NibValueBuilder<Color>(
  target: color,
  transition: const NibTransition(
      duration: Duration(milliseconds: 300), curve: Curves.easeOut), // tween
  builder: (context, c) => ColoredBox(color: c),
)

NibValueBuilder<EdgeInsets>.withChild(
  target: padding,
  child: const ExpensiveCard(),                 // built once
  childBuilder: (context, p, child) => Padding(padding: p, child: child),
)
```

A tween interpolates every channel linearly through the curve and cannot carry
velocity, so a spring that takes over from a tween starts at rest.
`NibSimulationDriver` now settles on the simulation's exact end (bisected) rather
than one frame past it.

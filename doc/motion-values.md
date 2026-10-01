# MotionValue mental model

A `MotionValue<T>` is a `ValueListenable<T>` that also knows its **velocity**
(units/second, `0` for non-numeric `T`). Render objects listen to it and repaint
directly; nothing rebuilds.

```dart
final x = MotionValue<double>(0);
x.value = 10;                      // jump: notifies, velocity → 0
x.update(10, velocity: 300);       // what drivers do: value + momentum
```

## Derived values

| API | Sources | Evaluation | Velocity |
|---|---|---|---|
| `value.transform(fn)` | 1 | eager; notifies only if the result changed | 0 |
| `value.mapRange(in, out, clamp:)` | 1 | eager | source velocity × segment slope |
| `MotionValue.computed([deps], fn)` | any `Listenable`s | **lazy**: marked stale on change, computed on read | 0 |

`computed` reads happen at paint time, after every dependency finished
updating, so diamond graphs are consistent where it matters. A listener that
reads a computed value *synchronously while its source is still notifying* can
see an intermediate state of eager derived nodes — read in paint/layout instead.

Dependencies must exist before the value that uses them, so cycles cannot be
built; there is no cycle detection to pay for. Computed values are read-only
(`update` throws `StateError`).

## Lifecycle

Derived and computed values attach listeners to their sources. **Dispose them**
(or let their owning `State` do it) — `dispose()` detaches from every source
(`hasListeners` is public so tests can assert it). Disposing a chain bottom-up
is safe.

## Driving external values into NibMotion

```dart
final opacity = MotionValue<double>(1);
NibMotion(motionValues: NibMotionValues(opacity: opacity), child: …);
```

Externally supplied values are never disposed by the widget.

## Reading velocity and driving translate from an `Offset`

```dart
final controller = NibMotionController();
NibMotion(controller: controller, …);

controller.velocityOf(NibProperty.x);              // units/second, 0 at rest
controller.velocities;                             // snapshot of every NibProperty
controller.motionValueOf(NibProperty.x)!           // the live MotionValue:
    .addListener(() => print(...));                //   value + velocity, listenable
```

`motionValueOf` returns `null` until a `NibMotion` is attached (after its first
build).

To drive both translate channels from one `Offset` without rebuilds:

```dart
final offset = NibOffsetMotionValue();             // MotionValue<Offset> + x/y channels
NibMotion(motionValues: NibMotionValues(offset: offset), child: …);
MultiSpringSolver<Offset>(vsync: this, value: offset,
    converter: MotionConverter.offset, spring: NibSpring.smooth);
```

Any `MotionValue<Offset>` works; a plain one is split into two derived scalar
values owned by the widget. **Conflict rule:** an explicit `translateX` /
`translateY` in `NibMotionValues` wins on its axis; `offset` fills the other.
While `offset` drives a channel, `animateTo(x:)` on that channel is overwritten
by the next `offset` change.

# Routes: `NibModalRoute`, `showNibDialog`, `NibPageRoute`

Route helpers whose content moves with the same physics as `NibMotion`.
Widgets-only (no Material).

```dart
final ok = await showNibDialog<bool>(
  context: context,
  builder: (context) => ConfirmDialog(),
);
// or explicitly:
Navigator.of(context).push(NibPageRoute<void>(builder: (_) => Detail()));
```

## How it works

* The route (a `PopupRoute` / `PageRoute`) owns the barrier, `Navigator.pop`
  and result returning.
* The content is wrapped in a `NibMotion`. On `forward` it animates to
  `animate` (default identity), on `reverse` to `exit` (default `initial`).
* Because the content uses the normal driver runtime, a pop during the enter
  spring reverses from the current **position and velocity**, and
  `NibMotionConfig` reduced motion makes both directions jump.

## Options

| Option | Default |
|---|---|
| `initial` | dialog: `opacity 0, scale 0.92`; page: `opacity 0, y 32` |
| `animate` | `NibAnim.identity` |
| `exit` | `initial` |
| `transition` | a snappy spring |
| `duration` / `reverseDuration` | 350 ms / 250 ms |
| `barrierDismissible` / `barrierColor` | `true` / 50% black (dialog only) |
| `alignment` (dialog) | `Alignment.center` |

`reverseDuration` is how long the route stays mounted after a pop; the exit
motion is cut off when it elapses, so give slow exit transitions a longer
`reverseDuration`.

## Limits

* No shared-element (`layoutId`) hand-off between the route and its caller is
  wired up. `NibLayoutScope` would have to sit above the `Navigator`; this is
  untested and not claimed.
* No iOS-style interactive back-swipe: dismissal is `Navigator.pop`,
  barrier tap, or the platform back button.

## Edge back-swipe (`NibPageRoute(backSwipe: true)`)

Dragging from the start edge (left in LTR, right in RTL, a 24px strip) moves the
page with the finger. Releasing past 40% of the width, or flinging faster than
700 px/s, pops it: the release velocity is handed to the exit spring, so it keeps
moving instead of restarting. Anything less springs back. Taps in the strip still
reach the page, a route that refuses to pop (`maybePop` is false) springs back,
and the gesture works under reduced motion (finger-following is essential motion).
Off by default.

## Shared-element hand-off (`sharedFrom:`)

```dart
showNibDialog(context: context, sharedFrom: cardKey, builder: (_) => Detail());
```

The content grows out of the widget owning `cardKey` and shrinks back into it on
pop (position and size, measured when the route enters and again when it leaves).
If the source is not mounted, the normal `initial`/`exit` motion is used. The
source stays where it is (nothing is moved or hidden). This is a FLIP on the route's
own `NibMotion`, not the `NibLayoutScope` id mechanism: that mechanism only hands
off from an owner that has been *unmounted*, and a route's caller stays mounted.

## Route lifetime

`reverseDuration` is a minimum. A route is never removed before its exit
`transition` has come to rest (tween duration + delay, or the simulated spring
settle time), so the exit is never cut short.

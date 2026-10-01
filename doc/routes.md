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

* The `layoutId` mechanism of `NibLayoutScope` is not used for the route/caller
  hand-off (see `sharedFrom` below); it only hands off from an owner that has
  been unmounted.
* The back-swipe is opt-in per route (`backSwipe: true`), and the parallax
  below only moves routes that are `NibPageRoute`s.

## Edge back-swipe (`NibPageRoute(backSwipe: true)`)

Dragging from the start edge (left in LTR, right in RTL, a 24px strip) moves the
page with the finger. Releasing past 40% of the width, or flinging faster than
700 px/s, pops it: the release velocity is handed to the exit spring, so it keeps
moving instead of restarting. Anything less springs back. Taps in the strip still
reach the page, a route that refuses to pop (`maybePop` is false) springs back,
and the gesture works under reduced motion (finger-following is essential motion).
Off by default.

While the page is dragged, the route below **slides in from the side behind
it** (parallax): it starts `parallax` (default `0.3`) of a width off to the
side and eases to rest as the top page leaves, mirrored in RTL. Set
`NibPageRoute(parallax: 0)` on the route below to disable it. It only applies
to a covered `NibPageRoute` while a route above is being swiped (pushes and
ordinary pops never offset it), follows the top page's real position, so a
release that commits keeps moving it monotonically to rest, and a cancelled
swipe leaves it painted until the page has covered it again.

## Shared-element hand-off (`sharedFrom:`)

```dart
showNibDialog(context: context, sharedFrom: cardKey, builder: (_) => Detail());
```

The content grows out of the widget owning `cardKey` and shrinks back into it on
pop (position and size, measured when the route enters and again when it leaves).
If the source is not mounted, the normal `initial`/`exit` motion is used. The
source stays where it is. To hide it while the route stands in for it, wrap
it in `NibSharedSource(sourceKey: cardKey, child: …)`: it keeps its layout space
but paints nothing while any route using that key is open (several routes may
share one source) and reappears when the content has shrunk back over it.
Without `NibSharedSource` (a plain `GlobalKey`) the hand-off still animates and
the source stays visible underneath. This is a FLIP on the route's
own `NibMotion`, not the `NibLayoutScope` id mechanism: that mechanism only hands
off from an owner that has been *unmounted*, and a route's caller stays mounted.

## Route lifetime

`reverseDuration` is a minimum. A route is never removed before its exit
`transition` has come to rest (tween duration + delay, or the simulated spring
settle time), so the exit is never cut short.

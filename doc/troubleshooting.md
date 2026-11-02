# Troubleshooting

## An entrance does not replay after a rebuild

`initial` applies when the widget mounts. Change `animate` to move an existing
widget. Use `NibMotionController.start()` to replay its entrance, or
`NibMotionReplayScope` for several children. `NibHotReloadReplay` is useful
while editing examples. Check that `NibMotionGate` has been released and that
the entrance warm-up has elapsed.

## An exit disappears immediately

Keep the keyed `NibMotion` under `NibPresence`, or use `NibVisibility` for one
child. A widget removed by Flutter without presence cannot finish an exit.
Use stable data keys rather than list indices. Reduced motion removes the
transition intentionally.

## Shared layout does not animate

Place both instances inside one `NibLayoutScope`, give them the same `layoutId`
but different keys, and replace one with the other in the same rebuild.
Shared layout uses a recently unmounted owner's snapshot. For a route whose
source remains mounted, use `sharedFrom` and optionally `NibSharedSource`.

## Layout stretches text or flashes a new position

Use `layoutSizeMode: NibLayoutSizeMode.clip` when scale distortion is unwanted.
Check the [layout limits](layout.md#limits-deliberately-documented) for lazy
lists and `RepaintBoundary` timing. Test your transformed/clipped parent tree;
perspective layout geometry is not supported.

## A shader shows a plain child or a different glass effect

Check the renderer and the selected fallback before treating this as an
animation failure. `sampleChild` requires Flutter's shader image-filter
support. For water, inspect `onStatus`; capture submission time is not GPU time.
Include Flutter version, renderer, platform, and a minimal reproduction in a
[bug report](https://github.com/oraclevs/nib_motion/issues/new?template=bug_report.yml).

## A scroll effect accumulates listeners

Create `mapRange`, `transform`, and computed values once per owning state,
recreate them when their sources change, and dispose them before those sources.
Avoid creating derived values on every build without retaining their handles.
`NibScrollMotion` owns its bridge, but not derived values your builder creates.

## A timeline await never returns after cancellation

Cancelling timers prevents pending entries from starting. It does not complete
the cancelled run's `play()` future or stop already-started controllers. Keep
cancellation state in the caller and stop controllers separately. See the
[timeline contract](timeline.md#cancellation-limit).

## A spring token fails in a const expression

`NibSpring` tokens are `static final`. Remove `const` from that expression or
use a `const NibSpringDescription` preset. A spring description goes in
`NibMotion(spring:)`; use `.transition` when a `NibTransition` is required.

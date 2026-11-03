---
{
  "id": "getting-started",
  "evidence": "MotionNib/motion/lib/src/core/nib_motion_widget.dart"
}
---

# Start with motion

Build a short, staged entrance from opacity, vertical travel and timing.

<!-- section: first-step -->
## Let one widget arrive

Wrap a headline in NibMotion. initial describes its first appearance; animate describes its resting state. The preview starts each line slightly lower and transparent, then brings it to its normal position.

Start with the small wrapper below. Use the preview’s Copy minimal example for a complete Flutter app.

```dart
NibMotion(
  initial: const NibAnim(opacity: 0, y: 18),
  animate: const NibAnim(opacity: 1, y: 0),
  transition: const NibTransition(
    duration: Duration(milliseconds: 480),
    curve: Curves.easeOutCubic,
  ),
  child: const Text('A little motion. A clear beginning.'),
)
```

<!-- section: retarget -->
## Give the content an order

The headline leads and the supporting details follow. Each wrapper uses the same 480 ms transition, with delay increased by 90 ms per item. The preview plays once; Replay entrance explicitly starts a new entrance.

Delay belongs to this timed entrance. Use a spring for an interaction whose destination can change while it is moving; the next lesson builds that interaction.

<!-- section: state-and-identity -->
## Know what causes a new entrance

A normal parent rebuild keeps the same NibMotion element. Changing its animate value updates the target. Changing its key creates a fresh element and replays initial.

Replay entrance changes a generation key deliberately. Do not use a changing timestamp as a key for ordinary state updates: that would discard the current motion.

<!-- section: try-the-sample -->
## Change one thing at a time

Try y: 36 for a longer entrance or remove the per-item delay to let all details arrive together. Keep opacity: 1 and y: 0 as the explicit endpoint.

Translation affects painting, not the layout slot. Leave enough room for travel and keep interactive controls outside the moving content while learning.

<!-- section: troubleshoot-first -->
## If the entrance is not visible

Reduced motion should show the complete card immediately. Otherwise confirm that initial and animate differ and that the wrapper is newly mounted.

An entrance that has already finished stays finished on an ordinary rebuild. Use Replay entrance or a new key only when a replay is intended.

<!-- section: next -->
## Continue with a stateful interaction

Your first animation turns a bookmark into a responsive Save and Undo interaction. It uses a persistent spring target instead of a staged entrance.

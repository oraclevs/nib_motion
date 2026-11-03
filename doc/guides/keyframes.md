---
{
  "id": "keyframes",
  "evidence": "MotionNib/motion/lib/src/core/nib_keyframe.dart; MotionNib/motion/lib/src/core/nib_motion_widget.dart"
}
---

# Keyframes

Define the states of one motion sequence along normalized time.

<!-- section: one-sequence -->
## Follow three tracks on one clock

Each tile in this example has a list of NibKeyframe values. A keyframe records one tile’s state at a normalized position: 0 is the start, 0.5 is halfway, and 1 is the end. The three NibMotion widgets start together and use the same 2.4 second duration, so their positions stay coordinated.

Choose Scatter, Cross or Align to inspect the exact values at that stage. Amber moves across the top, teal crosses below it, and sage changes scale before the three form a row. The labels, colors and positions make each track easy to follow. The excerpt below is the amber track; Copy runnable example includes all three tracks and their controls.

<!-- api -->
| Name | Type | Default | Description |
| --- | --- | --- | --- |
| at | double | required | Normalized progress position from 0.0 to 1.0. |
| value | NibAnim | required | This one child’s state at the progress position. |
| curve / spring | Curve? / NibSpringDescription? | null / null | Shape the incoming segment; they are mutually exclusive. |

```dart
NibMotion(
  keyframes: const [
    NibKeyframe(at: 0, value: NibAnim(x: -72, y: -52, rotate: -0.16)),
    NibKeyframe(at: 0.5, value: NibAnim(x: 72, y: -48, rotate: 0.12)),
    NibKeyframe(at: 1, value: NibAnim(x: 62, y: 12, rotate: 0)),
  ],
  transition: const NibTransition(duration: Duration(milliseconds: 2400)),
  child: const Icon(Icons.star),
)
```

<!-- section: place-a-track -->
## Put one list on each moving child

A NibKeyframe list belongs to one NibMotion child. The amber excerpt puts that tile at x: -72, y: -52 at progress zero; sends it across the top to x: 72, y: -48 at halfway; and settles it near x: 62, y: 12 at one. Its rotate values are turns, so -0.16 and 0.12 tilt it in opposite directions before zero restores an upright endpoint.

The live scene contains three such lists and three controllers. Sharing a duration makes them cross together; it does not mean there is one keyframe list for all three tiles. Copy runnable example shows the whole State, including the controllers and disposal. If you only need one child, the excerpt is sufficient inside your own build method.

<!-- section: segments -->
## Shape each segment

The engine finds the two points around the current progress, normalizes progress inside that segment, then interpolates NibAnim properties. The curve on the upcoming keyframe shapes the segment arriving there; otherwise it uses the transition curve. A spring description on that upcoming keyframe can instead be sampled as a curve over the segment. A keyframe cannot set both curve and spring.

The overall sequence still uses NibTransition.duration. Supplying NibTransition.spring for the whole sequence does not turn the controller into a spring; its curve and duration path drives playback. This distinction matters when copying an older reference that says spring keyframes are unsupported.

<!-- section: time-and-easing -->
## Change time without changing the route

The default preview duration is 2.4 seconds. Move the duration slider toward 1.2 seconds and replay: Scatter, Cross, and Align still occur at progress 0, 0.5, and 1, but the interval between them shrinks. At 4.8 seconds those same states take longer. An at value is a fraction of the sequence, not a timestamp in milliseconds.

Between two neighboring keyframes, the implementation normalizes progress for that segment and interpolates NibAnim values. The next keyframe’s curve changes how its incoming segment eases. A spring on that keyframe is sampled as a segment curve; it can overshoot that keyframe before the segment ends. Curve and spring on the same keyframe are mutually exclusive. The overall controller remains timed by NibTransition.duration, even if an individual segment samples a spring response.

<!-- section: replay -->
## Replay and reduced motion

Replay calls start(keyframes: ..., transition: ...) on each NibMotionController. Selecting a stage first calls stop(), then set() with that stage’s state, so inspecting positions does not remount the tiles. Changing duration replays all three tracks using the new timing. Each controller is disposed with its State.

Reduced motion shows Align immediately and disables the travel controls. Each tile keeps its identity and label at the endpoint. Your app can also replay an entrance by changing its key, but that deliberately recreates the element and its local state.

<!-- section: keyframe-checks -->
## Inspect stages before trusting playback

Use the stage buttons to pause at Scatter, Cross, and Align. Check that every tile ends in a useful position and that labels remain distinct. Then replay and watch whether the crossings obscure a required control. A transform can move painted content without changing its original layout slot, so the scene reserves enough room for travel.

If a child seems to jump, check that the list describes the same property at the important stages and that its key is stable. If it seems to ignore a spring transition, remember the whole keyframe path uses a timed controller; put spring on an incoming NibKeyframe segment when you want that sampled feel. Next learn Timeline when several independent children need offset start times rather than merely shared progress.

# November 3 demonstration runbook

This script uses the existing example app. Source and control labels were
checked on November 2, 2026. Rehearse on the presentation machine before the
talk; source inspection does not verify that machine's renderer or frame rate.

## Prepare once

From the repository root:

```bash
flutter --version
flutter pub get
cd example
flutter pub get
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080 -t lib/demos.dart
```

Open `http://localhost:8080`. Leave the app running and open the
[README](../../README.md) plus
[retarget recipe](../../example/lib/recipes/retarget_card_recipe.dart) in the
editor. Use a desktop-sized browser window so the effects screen has room for
its three boxes. Confirm keyboard focus, pointer input and the projector's text
size. Check the operating system's reduced-motion setting; explain it if motion
is intentionally reduced.

Review the [new gallery media](showcase-media.md) and [per-example audit](showcase-audit.md)
before selecting footage. Use the fullscreen toolbar action for a clean presentation.
The Reduced motion screen has a known debug assertion after repeated policy toggles;
leave that sequence out until its separate runtime fix is reviewed.

Keep local copies of the existing
[text/shader recording](../../assets/nib_preview.gif) and
[Daily Focus recording](../../assets/daily_focus.gif) available as a fallback.
The recordings are illustrative; do not describe their capture rate as app
performance.

## Five-minute walkthrough

1. **Introduce the framework, 30 seconds.**
   “NibMotion is a physics-driven motion framework for Flutter. You describe the
   state your interface should reach. It connects springs, gestures, layout,
   scroll and exit animations through one motion-value model.”

2. **Describe a state, 45 seconds.**
   Show the README entrance example: `initial` sets the starting appearance and
   `animate` sets the destination. Open **Interruption** in the app. In
   **Copyable spring retarget recipe**, press **Move card**, then **Reset card**.
   Show the recipe's boolean target and `NibTransition.springSnappy`. Press
   again before the card settles to demonstrate retargeting.

3. **Hand control to the user, 60 seconds.**
   Return to the menu and choose **Drag, inertia, snap**. Fling the top box; it
   coasts within its bounds. Flick the bottom box with **snapProjection: 150 ms**
   enabled, then disable the switch and compare. Explain that release velocity
   can influence the destination.

4. **Change the interface, 75 seconds.**
   Open **Layout (FLIP)**. Press **Reverse**, resize a chip by tapping it, then
   open and close a card under **Shared layoutId**. Open **Presence** next.
   Remove a box, then immediately add it again using its action chip. Toggle
   **exitLayout: pop** to show when siblings reflow. These are ordinary state
   changes with explicit keys and exit targets.

5. **Show effects and accessibility, 45 seconds.**
   Open **Effects & tokens**. Press **Blur + tint**, then **Move** to compare the
   spring tokens. These paint effects are available in this screen; do not call
   this a custom fragment-shader demonstration. Open **Reduced motion**, leave
   **Reduce motion** enabled, and press **Toggle state**. The target updates
   immediately. Direct dragging still follows the pointer.

6. **Install and contribute, 45 seconds.**
   Show `flutter pub add nib_motion`, the
   [package page](https://pub.dev/packages/nib_motion),
   [documentation](../README.md) and [contribution guide](../../CONTRIBUTING.md).
   Invite developers to try one interaction and bring a small reproduction or
   documentation improvement. State the published version shown on pub.dev;
   distinguish a prepared release candidate from a published release.

For a longer slot, **Viewport progress** maps scroll progress to opacity,
scale, rotation and position. Scroll slowly through the cards and open
[the screen's source](../../example/lib/screens/progress_screen.dart).

## Optional shader segment

The existing text/shader recording shows shimmer and dissolve. Introduce it as
a recording. For a live shader segment, rehearse the existing native performance
harness separately with `flutter run --profile -d linux -t perf/perf_main.dart`
from `example/`, after generating Linux platform files and installing the Linux
toolchain. It runs twelve scenarios automatically, including shimmer and glass
at the end, and then exits. It is unsuitable as the only live demo.

Check that the intended shader path is active before making a shader claim.
Glass can show a blur fallback; shimmer can show an unchanged child if loading
fails. Verify the water rendering path on the presentation machine and keep a recorded fallback available.

If live rendering fails, use the local recording and continue with source.
Keep device-specific performance claims out of the talk unless that exact
scene and device have been measured.

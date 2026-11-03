# Portrait water showcase

Recorded November 3, 2026 from the owner's existing Lagoon application at
`/home/occ/Projects/Flutter/motion_nib_0_3`. The artwork, screens, navigation,
pearls and water configuration are the existing application. No replacement
application or animation overlay was used. These assets await owner selection.

## Application and renderer

The normal entry point is `lib/main.dart`. `App` opens `Lagoon` in
`lib/screens/lagoon.dart`. Two `NibWaterSurface` instances wrap the shore and
ocean scenes; each has its own `NibWaterController`. Their configuration uses
`surface: true`, live sampling and `NibWaterMaterial(refraction: 16, highlight: .6)`.
The hidden surface is paused. Both controllers and the focus nodes are disposed
when Lagoon unmounts.

The existing disturbance interaction handles pointer-down events and movement.
Taps add impulses at the pointer position; the swipe adds disturbances along its
path. The capture harness sends pointer events through Flutter's test binding
while the native application renders on the display in real time. It does not
replace the simulation or synthesize video frames.

| Setting | Recorded value |
|---|---|
| Application dependency | Local `nib_motion` 0.3.6 showcase candidate, via `pubspec_overrides.yaml` |
| Flutter / Dart | Flutter 3.47.8 stable / Dart 3.13.7 |
| Target | Linux desktop, profile build, Wayland |
| Engine renderer | Impeller, OpenGLESSDF (engine startup log) |
| Water backend | `layerSampler` |
| Shore status | `refractive` after shader loading |
| Ocean status | `refractive` after opening the second screen |
| Native window | 390×740 logical pixels, portrait |
| Capture | 494×960 pixels at 30 FPS, cropped inside the window border |

`NibWaterSurface.onStatus` reported the refractive path on both screens. No
fallback status appeared in the selected Linux run. Its diagnostic explicitly
says CPU submission is measured, while GPU completion and display age are not.
The recording's 30 FPS encoding is not a rendering-performance guarantee.
Water is a stable public API; this capture does not establish support on every
device. Web refraction was also observed during setup, but the final water
media comes entirely from Linux, as requested by the owner.

## Focused application fixes

- Give each custom button its own semantics container. Previously the shore
  button's accessibility action covered the entire page in the web semantics
  tree, so a background click could navigate. A regression test checks the
  button's label and bounds.
- Fit the animated heading's word units to its reserved single-line bounds.
  Their metrics differed from the invisible reference text, causing “magic”
  to wrap over “underwater.” The existing single-line test now includes the
  heading, and its changed 390-pixel golden was reviewed and refreshed.
- Forward optional water status callbacks through `App` and `Lagoon` for
  diagnostics. Normal application startup adds no diagnostic overlay.
- Add an opt-in native portrait window configuration and a separate integration
  capture test. Normal app startup never runs the recording choreography.

The package's `lib/` runtime is unchanged. The local app is not a Git repository;
[the focused patch](water-app.patch) preserves the source changes for review.
Original files and the previous golden are backed up outside the package under
`docs/verification/water-media-2026-11-03/original-app/` in the Nib workspace.
The patch expects that original app revision; check it with `git apply --check`
before applying it elsewhere. Regenerate the affected golden after reviewing
the heading fix. The app's artwork and complete source are not copied into this
package.

## Capture and replay

To explore the actual portrait app, from its directory:

```bash
NIBMOTION_CAPTURE_PORTRAIT=1 flutter run -d linux --profile -t lib/main.dart
```

Ensure the path override points to the 0.3.6 showcase checkout. For a repeatable
capture, choose a new, nonexistent marker path and run:

```bash
NIBMOTION_CAPTURE_PORTRAIT=1 flutter drive -d linux --profile \
  --driver=test_driver/showcase_capture.dart \
  --target=integration_test/showcase_capture_test.dart \
  --dart-define=CAPTURE_START=/tmp/nib-water-capture-start
```

Wait for `WATER_READY`. Check the portrait window, then record its interior using
`wf-recorder`. Determine the current output and window coordinates first; these
coordinates belong to the reviewed take, not every desktop:

```bash
wf-recorder -o eDP-1 -g '535,69 370x720' -r 30 -D \
  -c libx264 -p crf=16 -p preset=ultrafast -x yuv420p \
  -f /tmp/nib-water-portrait.mp4
# In another terminal, begin the real pointer sequence:
touch /tmp/nib-water-capture-start
# Stop wf-recorder with Ctrl+C after WATER_SCENE closing.
```

The test waits up to ten minutes for the marker, then performs two spaced taps,
a 1.1-second swipe, a dive, a pearl collection and a return. It checks both
refractive statuses and unmounts the app after a closing hold. The native test
passed. `integration_test` printed a plugin-registration warning on Linux;
`flutter drive` still received the results and exited successfully.

The reviewed raw take is retained outside the repository at
`docs/verification/water-media-2026-11-03/capture/water-portrait-1.mp4` in the Nib
workspace. Its 40.03 seconds include setup and closing hold. The master keeps
2.4–26.4 seconds; the GIF keeps 3.4–13.4 seconds, concentrating on home-screen
waves. Both play at real speed. The crop removes desktop chrome and rounded
window borders; it does not stretch a landscape view into portrait. The display
limits this portrait source to 960 pixels high, so it was not upscaled to 1080.

From this repository:

```bash
python3 tool/showcase_media.py --water /path/to/water-portrait-1.mp4
python3 -m unittest discover -s tool -p 'test_*.py'
```

The water option uses the reviewed cut intervals and dimensions. Revise those
constants after reviewing a new take. It writes separate water metadata and
leaves the existing gallery assets intact. Palette generation/application,
size checks and decoding are part of the script.

## Review and publication

Open [the offline comparison page](../../assets/showcase/index.html). Watch the
water MP4 for the full two-screen flow and the GIF for the ripple loop. Review
readability, wave strength, the heading fix and the first-frame crop before
approving the final media. No simulated waves or automatic production-app
triggers were added.

Both README GIFs use absolute HTTPS URLs on the showcase branch and link their
MP4s separately. The gallery GIF remains the first pub.dev screenshot. The old
Daily Focus GIF and application remain in the repository and gallery; only its
promotional README image was replaced. Release approval, merging PRs #5/#6 and
pub.dev publication are still pending.

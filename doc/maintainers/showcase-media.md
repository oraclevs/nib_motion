# Showcase media review

Recorded November 2, 2026; edited and validated November 3. These assets are
candidates for owner review, not an approved release announcement.

## View locally

Open [the offline media page](../../assets/showcase/index.html), or open each file:

| Asset | Format | Dimensions | Duration | Size |
|---|---|---|---|---|
| [Master recording](../../assets/showcase/nibmotion-showcase.mp4) | H.264, yuv420p, MP4, 30 FPS | 1920×1080 | 40.1 s | 1,025,571 bytes |
| [README loop](../../assets/showcase/nibmotion-showcase.gif) | GIF, infinite loop | 960×540 | 11.78 s | 845,428 bytes |
| [Poster](../../assets/showcase/nibmotion-poster.png) | PNG | 1920×1080 | Still | 288,258 bytes |

[Metadata and SHA-256 hashes](../../assets/showcase/metadata.json) identify the
source capture and outputs. FFmpeg decoded every output without an error.
The local browser played the MP4 through to 40.1 seconds without a media error
and loaded the GIF at its expected 960×540 dimensions.
The GIF's Netscape loop extension is set to zero (repeat indefinitely).
Its first and last scenes show the composed gallery overview; the first frame
is intentional because pub.dev uses it for the package thumbnail.

## Portrait water recording

The second promotional demonstration is the existing Lagoon app, captured on
Linux in portrait on November 3. See [the app assessment and capture workflow](water-showcase.md).
The gallery assets above remain byte-for-byte unchanged.

| Asset | Format | Dimensions | Duration | Size |
|---|---|---|---|---|
| [Water master](../../assets/showcase/nibmotion-water.mp4) | H.264, yuv420p, MP4, 30 FPS | 494×960 | 24 s | 3,482,812 bytes |
| [Water README loop](../../assets/showcase/nibmotion-water.gif) | GIF, infinite loop | 300×582 | 10 s | 3,650,310 bytes |
| [Water poster](../../assets/showcase/nibmotion-water-poster.png) | PNG | 494×960 | Still | 540,653 bytes |

[Water metadata](../../assets/showcase/water-metadata.json) records hashes and cut
intervals. The GIF samples real footage at 12 FPS, with centisecond GIF timing.
An earlier 320-pixel edit exceeded 4 MB; the reviewed 300-pixel version keeps the
same interactions within the publication budget. The master preserves the
native portrait capture resolution rather than upscaling it.

## What was captured

The running Flutter application was displayed fullscreen on a 1920×1080 Linux
Wayland monitor. `wf-recorder` captured the real display at 30 FPS. Browser
controls supplied real pointer and keyboard input. The capture contains no
browser chrome, editor panels, terminal, or notifications in the selected edit.
There are no generated animation frames, speed changes, interpolated motion,
voice-over, or performance claims. Source capture was the debug CanvasKit build;
release Wasm was checked separately.

The master uses these intervals from the 88.8-second reviewed take:

| Source interval | Scene |
|---|---|
| 2–5 s | Gallery identity and overview |
| 10.5–17.5 s | Declarative spring recipe retargeting |
| 23.2–31.7 s | Drag, constrained inertia and snap |
| 33.4–38 s | Layout reversal and rotation |
| 38.5–44.5 s | Presence removal and re-entry |
| 53–59.5 s | Text entrance and typewriter |
| 83–87.5 s | Gallery closing view |

Cuts remove idle time; animation inside each shot stays at real speed. The
orange spring recipe is the visible spring demonstration. The top velocity
track is not presented as a demonstrated interaction in this recording.
Shimmer was excluded because its current opaque shader covers the child.
Glass was excluded because this browser uses its frosted fallback. See the
[audit](showcase-audit.md) before selecting effects footage.

## Repeat the capture and edit

Run the gallery as described in [example/README.md](../../example/README.md).
Enter fullscreen using the toolbar, check that only the application is visible,
and keep viewport overrides unchanged while recording. Resizing the in-app
browser can exit fullscreen. Inspect the first captured frame before proceeding.

```bash
wf-recorder -o eDP-1 -r 30 -D -c libx264 -p crf=16 \
  -p preset=ultrafast -x yuv420p -f /tmp/nibmotion-capture.mp4
# Interact with the gallery, then stop the recorder with Ctrl+C.
```

Use the actual output name reported by `wf-recorder -L` on another machine.
Raw takes stay outside this package. Review the take, update `MASTER` and `GIF`
intervals in the edit script, then run from the repository root:

```bash
python3 tool/showcase_media.py /path/to/reviewed-capture.mp4
python3 -m unittest discover -s tool -p 'test_*.py'
```

The script checks input dimensions and cut bounds, encodes H.264 with fast-start
metadata, creates a palette with `palettegen`, applies it with `paletteuse`,
checks the GIF size, decodes all outputs, and records metadata. It needs Python,
FFmpeg and ffprobe. GIF frames are sampled at 18 FPS and represented using GIF's
centisecond timing; that timing is not an app frame-rate measurement.

## GitHub and pub.dev

The README uses an absolute HTTPS GIF URL on the showcase branch and links the
MP4 separately. Validate those URLs after pushing the branch. Do not change
references to `main` until the approved files exist there. Pub.dev supports
[screenshot images up to 4 MB](https://dart.dev/tools/pub/pubspec#screenshots);
both declared GIFs are below that limit. `.pubignore` includes both GIFs and excludes
the MP4s, posters, metadata, offline page and raw captures from the package archive.
The old GIFs remain in the checkout for comparison.

This task does not publish version 0.3.6. The new media has not been verified on
a newly published pub.dev package page. Its README image uses ordinary HTTPS
image markup; no video player, iframe or script is required for the inline GIF.

## Owner selection

Explore all 29 gallery pages, mark each decision and export the review JSON.
Watch the MP4 at normal speed and the GIF through at least two loops. Confirm
that the text is readable, the opening poster represents the product, and each
selected interaction explains a useful capability. Approve scenes individually;
keep the documented gradient policy and path-resume issues out of final claims
until their engine fixes receive separate review.

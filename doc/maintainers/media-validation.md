# Media integration validation — November 3, 2026

This update retains the gallery footage from PR #6 and adds a portrait recording
of the owner's existing Lagoon app. PR #6 remains stacked on PR #5; the 0.3.6
version and package runtime are unchanged. Owner selection and release approval
are still required.

## Executed checks

| Scope | Result |
|---|---|
| NibMotion dependencies | `flutter pub get` passed |
| Package formatting | 292 Dart files checked, zero changes |
| Package analysis | `flutter analyze --fatal-infos` passed after the generated screenshot asset was present |
| Package tests | 847 passed |
| Media and release tooling | 8 Python tests passed |
| Water application analysis | `flutter analyze --fatal-infos` passed |
| Water application tests | 11 passed, including repeated taps, navigation, reduced motion and disposal |
| Native capture integration | Passed with real Linux/Impeller rendering; both surfaces reported `refractive` |
| Source patch | `git apply --check` passed against the backed-up app source |
| Gallery preservation | MP4, GIF and poster SHA-256 hashes still match the previous metadata |
| Media decoding | FFmpeg decoded all six final assets without errors |
| GIF structure | Infinite-loop extension present; gallery has 212 frames, water has 120 frames |
| Browser playback | Both MP4s played to their ends (40.1 s and 24 s) without a media error |
| Browser GIF loading | Both images loaded at their expected natural dimensions |
| Archive contents | Both screenshot GIFs included; MP4s, posters, raw footage and maintainer files excluded |

The publishing dry run from the committed state passed with zero warnings. Its
file list includes both GIFs and reports a 4 MB compressed archive. MP4s, posters
and raw captures are excluded. Current hosted CI results are linked from PR #6.

The earlier web capture setup exposed a startup focus/layout error; deferring
its temporary capture control until the first frame resolved it. That setup was
removed when the owner selected native portrait capture. No web footage appears
in the final water assets. Native integration printed a Linux plugin-registration
warning, but the driver received results and exited successfully.

## Media outputs

| File | Format | Dimensions | Duration | Bytes |
|---|---|---|---|---|
| `nibmotion-showcase.mp4` | H.264/yuv420p, 30 FPS | 1920×1080 | 40.1 s | 1,025,571 |
| `nibmotion-showcase.gif` | GIF, infinite loop | 960×540 | 11.78 s | 845,428 |
| `nibmotion-poster.png` | PNG | 1920×1080 | Still | 288,258 |
| `nibmotion-water.mp4` | H.264/yuv420p, 30 FPS | 494×960 | 24 s | 3,482,812 |
| `nibmotion-water.gif` | GIF, infinite loop | 300×582 | 10 s | 3,650,310 |
| `nibmotion-water-poster.png` | PNG | 494×960 | Still | 540,653 |

The gallery remains the first pub.dev screenshot. Both GIFs fit the documented
individual 4 MB limit. MP4 encoding rate is not a measured GPU frame-rate claim.
The portrait capture is limited by this display's available window height; it
was not enlarged to manufacture a 1080-pixel source.

## Owner review

1. Open [the media page](../../assets/showcase/index.html), play both MP4s and
   watch each GIF through two loops. Confirm the portrait framing and wave
   strength before selecting the final water media.
2. Explore the gallery's 29 examples. Existing per-demo findings remain in
   [the audit](showcase-audit.md), including the gradient-text ticker and path
   pause/resume issues; this update makes no engine fixes.
3. Review [the Lagoon assessment and source patch](water-showcase.md), especially
   the heading fit and button semantics changes. The original app and older
   Daily Focus media remain available.
4. Review the branch README on GitHub. Its two inline GIFs use branch URLs,
   with separate full-video links. Change URLs to `main` only after approved
   integration, then verify them before publishing.

GitHub's default-branch README and pub.dev do not change merely because this
PR is updated. No merge, tag, or pub.dev release is part of this task.

---
{
  "id": "platform-limits",
  "evidence": "MotionNib/motion/pubspec.yaml; MotionNib/motion/doc/layout.md; MotionNib/motion/doc/performance.md; RELEASE_CANDIDATE_REPORT.md"
}
---

# Platform limits

Separate source behavior, tested geometry, and device evidence.

<!-- section: sdk -->
## Check the package constraints

The published 0.3.5 pubspec declares Flutter 3.29 or newer and Dart 3.0 or newer. Hosted archives can carry different constraints. Resolve the exact archive or path package used by your app, and run analysis and tests under that SDK rather than inferring support from source inspection alone.

<!-- section: runtime-check -->
## Check your actual dependency and renderer

A pubspec constraint declares what may resolve; pubspec.lock records what did resolve for an application. Start with flutter --version and the lockfile, then run flutter pub get, flutter analyze, and the relevant tests under the oldest SDK you claim to support. Repeat with the current stable SDK. A newer test tool can fail even if library source could run on an older SDK, so record test-tool and runtime constraints separately.

For Flutter web, identify the renderer or Wasm backend used by the served release build. A Wasm test runner proves its test module executed in Wasm, but it does not identify the backend of a separately built site. Inspect the served build, exercise text, navigation, and shader assets there, and note the browser version. Desktop emulation of a mobile viewport is useful for layout checks but is not a physical mobile browser result.

<!-- section: geometry -->
## Stay inside the measured geometry

Selected scaled and rotated affine cases have regression tests. Perspective, near-singular transforms, rotated reorder, and pop exits requiring preservation of a clip across coordinate spaces remain outside the verified contract. A transform can alter both paint and hit behavior, so check both.

<!-- section: geometry-checklist -->
## Test the interaction that depends on geometry

For a reorder, record where an item is painted, which child receives a tap during movement, where focus goes after the move, and what a screen reader announces. For a drag, compare the reported release velocity with movement in the receiving widget’s local logical pixels per second. For a pop exit, check clipping and hit testing while the old visual remains over the new layout. Numeric widget tests are more informative than a test that only avoids an exception.

Near-zero scale can make coordinate conversion unstable. Perspective transforms and rotated reorder are not within the 0.3.5 verified layout and reorder contract. If your application requires one of those combinations, keep a simpler interaction for now or establish an application-specific test on the target platform. Do not infer support for every transform from the passing uniform-scale regression.

<!-- section: exercise -->
## Build an evidence note for one screen

Take the keyed-reorder demo into the screen where your app will use it. Record the candidate package revision, Flutter version, target device, renderer, and exact steps to move an item during a scroll. Save a short recording and any logs. Repeat with reduced motion enabled and verify that the final order, focus, and tap target remain correct. This note gives a reviewer a concrete result to accept or a reproducible limit to investigate.

When the required device is unavailable, keep the check pending. A software-rendered widget test can verify final positions and callbacks; it cannot substitute for physical touch or a GPU shader result. Write the scenario and expected observations so another tester can run the same interaction later. If the product chooses to exclude a platform or transform combination, record that scope decision explicitly instead of treating an unexecuted test as a pass.

<!-- section: hardware -->
## Keep device gates distinct

Widget tests, software rendering, and a compiled APK cannot certify physical touch, GPU shader output, screen-reader operation, or iOS Safari. Record actual launches and interactions for those targets when they become available. Treat any missing physical result as a pending gate or an explicitly scoped support limit.

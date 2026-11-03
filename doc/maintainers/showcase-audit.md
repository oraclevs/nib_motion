# NibMotion showcase audit

Audit dates: November 2–3, 2026. Candidate package version: 0.3.6.

This report separates source inspection, widget tests and browser observations.
A widget pass does not establish browser rendering, shader availability or frame
rate. The owner has not approved any new presentation or recording yet.

## Scope and evidence

The original registry contains 21 entries. Their titles and ordering are locked
by `example/test/demo_audit_test.dart`; the gallery must preserve every entry.
Daily Focus and both README quick starts are additional existing applications,
not replacements for those 21 entries. New coverage is listed separately below.

Source inspection covered all 21 screens, their shared scaffold, the retarget
recipe, Daily Focus, both README quick starts, the smoke tests, the example
pubspec, and the presentation runbook. Manual ownership review covered each
controller, motion value, derived value, scroll listener and asynchronous
completion in those sources. Widget checks use 375×812 and 1440×900 logical
pixels, both normal and reduced motion, plus targeted interaction cases. The
original smoke tests remain in place.

The focused audit suite completed: 71 passing tests and one explicit skip for
the reproduced gradient-text runtime issue described below. All original demos
opened and disposed at both viewports under both motion policies (84 opening
configurations). Twenty rapid-control/navigation cases passed; Reduced motion
was exercised separately and failed on repeated policy toggles. “Code assessment” describes what the example presents; it is not a claim
that a human has watched it in every supported renderer.

The complete package suite passed 847 tests. The complete example suite passed
212 tests with the one documented skip. Package and example dependency
resolution and analysis with fatal infos passed on Flutter 3.47.8. Formatting
checked 292 Dart files without changes. JavaScript and Wasm gallery builds
passed. Seven Python tooling tests passed. These counts do not include the
deliberately failing engine reproductions retained for separate review.

Severity: **S1** blocks a demonstration or leaves it unusable; **S2** materially
hurts interaction, accessibility or a common viewport; **S3** affects explanation
or presentation polish. Priority **P0** is required before owner review, **P1**
is useful for the first recording, **P2** can follow the initial launch.

## Original demonstrations

| Demo and source | Capability | Functional evidence | Presentation assessment | Known issue / improvement | Priority | Official showcase recommendation | Recording recommendation |
|---|---|---|---|---|---|---|---|
| [Interruption](../../example/lib/screens/interruption_screen.dart) | SpringSolver velocity retention, declarative retargeting and a reusable card recipe | Widget open/dispose pass; browser opens at 1440px and 375px | Two tracks make retargeting easy to compare; the recipe provides a keyboard-operable action | Imperative retarget now respects reduced motion; pointer tracks still need clear target hints | P1 | Keep; owner review pending | Strong: tap Move, Reset before settling |
| [Drag, inertia, snap](../../example/lib/screens/drag_screen.dart) | Constrained inertia and projected snap destinations | Widget open/dispose pass; browser opens at 1440px and 375px | Two distinct tracks make projection comparison understandable | Drag remains a pointer/touch demonstration; explain that constraint coordinates are local | P1 | Keep; owner review pending | Strong: fling, then compare projection switch |
| [Presence](../../example/lib/screens/presence_screen.dart) | Keyed exits, re-entry, stagger and pop layout | Widget open/dispose pass; browser opens at 1440px and 375px | Numbered boxes and add/remove chips give an explicit interaction | Colored boxes are functional samples; a content-card version would communicate a product use case better (S3) | P1 | Keep; owner review pending | Strong: remove/re-add before exit completes |
| [Layout (FLIP)](../../example/lib/screens/layout_screen.dart) | Size/position FLIP, shared layout ID and reorder | Widget open/dispose pass; browser opens at 1440px and 375px | Three sections show different layout changes; Reverse is easy to discover | Shared cards and resize squares are pointer-only; long-press reorder needs instruction (S2 accessibility) | P1 | Keep with documented input limitation; owner review pending | Strong: Reverse and shared card expansion |
| [Reduced motion](../../example/lib/screens/reduced_motion_screen.dart) | Scoped motion policy for transforms, text and drag settling | Initial state passes; browser reproduced repeated-toggle failure | One visible switch makes accessibility behavior observable | S1: repeated policy toggles crash NibGradientText in debug; minimal reproduction below. Initial reduced state is safe. | P0 | Hold final approval until S1 resolved | Do not record repeated toggles |
| [Effects & tokens](../../example/lib/screens/fx_screen.dart) | Perspective transforms, blur/tint and six spring tokens | Widget open/dispose pass; browser opens at 1440px and 375px | Button-driven comparison is direct; labels explain spring timing | Paint effects are not custom fragment shaders; use that exact distinction in narration | P1 | Keep; owner review pending | Strong if wide enough for three effect tiles |
| [Timeline](../../example/lib/screens/timeline_screen.dart) | Labels, relative start times and seeking | Widget open/dispose pass; browser opens at 1440px and 375px | Staged title/subtitle/button resemble a real entrance sequence | Timeline `progress` reflects seek position, not live playback; scrubber is not a playback playhead (S3) | P1 | Keep with explanation; owner review pending | Good after replay/reset is verified |
| [Multi-axis values](../../example/lib/screens/multi_axis_screen.dart) | Independent Offset springs and Color interpolation | Widget open/dispose pass; browser opens at 1440px and 375px | Moving dot plus velocity readout teaches axis behavior | Fixed a 33 px phone overflow and unnamed color controls (S2); labeled chips now wrap | P0 | Keep after responsive fix; owner review pending | Secondary: useful but less self-explanatory than Interruption |
| [Viewport progress](../../example/lib/screens/progress_screen.dart) | Scroll progress mapped to opacity, scale, rotation and parallax | Widget open/dispose pass; browser opens at 1440px and 375px | Cards visibly respond to their position in the viewport | Scroll-linked motion follows input; reduced motion should leave the cards readable | P1 | Keep; owner review pending | Strong: slow continuous scroll |
| [Routes](../../example/lib/screens/routes_screen.dart) | Dialog, modal, page transition, back swipe and shared bounds | Widget open/dispose pass; browser opens at 1440px and 375px | Explicit route buttons and return values make behavior verifiable | Modal transitions may cover gallery controls until closed; back swipe is touch/pointer only, with a back-button alternative | P1 | Keep; owner review pending | Good: shared card dialog gives the clearest visual |
| [Sliver header + list FLIP](../../example/lib/screens/sliver_screen.dart) | Collapsing sliver header and list reflow | Widget open/dispose pass; browser opens at 1440px and 375px | Header collapse and row insertion are recognizable UI behaviors | Header delegate and derived values now have stable ownership and disposal; remove icons now have names | P0 | Keep after ownership fix; owner review pending | Strong: scroll then insert/remove |
| [Timeline drag-scrub](../../example/lib/screens/timeline_scrub_screen.dart) | Inferred start values, relative labels, drag seeking | Widget open/dispose pass; browser opens at 1440px and 375px | Three labeled tiles make temporal ordering clear | Slider provides keyboard alternative; `progress` still reports seek position only | P1 | Keep with explanation; owner review pending | Good: scrub forward and backward |
| [Spring tuner](../../example/lib/screens/tuner_screen.dart) | Live physical parameters and step-response plot | Widget open/dispose pass; browser opens at 1440px and 375px | Plot and controls are useful to developers choosing a spring | The plot demonstrates solver response; it is not a device performance benchmark | P2 | Keep as developer tool; owner review pending | Secondary: slower explanatory footage |
| [Velocity + Offset adapter](../../example/lib/screens/velocity_screen.dart) | Live controller velocity and external Offset value binding | Widget open/dispose pass; browser opens at 1440px and 375px | Fling/readout and tap/move panels connect physics to values | Targets are now constrained to keep the box visible and respect reduced motion; spatial pad still needs pointer/touch input (S2 accessibility) | P1 | Keep with input limitation; owner review pending | Secondary: overlaps Interruption |
| [NibPresence.layout](../../example/lib/screens/presence_layout_screen.dart) | Column/row/wrap layout, pop/sync exit and FLIP | Widget open/dispose pass; browser opens at 1440px and 375px | Axis chips let a reviewer compare layout behavior | Fixed a 49 px row overflow after repeated Add (S2) with horizontal scrolling | P0 | Keep after overflow fix; owner review pending | Good: wrap removal shows gap closure |
| [Layout size modes](../../example/lib/screens/layout_modes_screen.dart) | Scale versus clip, delayed layout and repaint boundaries | Widget open/dispose pass; browser opens at 1440px and 375px | Side-by-side content makes stretching versus clipping visible | Small text is deliberate test content, not ideal promotional typography; narrow layouts must wrap the comparison | P2 | Keep as technical example; owner review pending | Secondary: requires narration |
| [NibValueBuilder](../../example/lib/screens/value_builder_screen.dart) | Spring/tween interpolation and stable child subtree | Widget open/dispose pass; browser opens at 1440px and 375px | Shared target makes timing differences easy to compare | Fixed the orange child stretching across the ListView; it now retains the intended box width | P1 | Keep after sizing fix; owner review pending | Good: compare both drivers in one shot |
| [Page, tab, viewport progress](../../example/lib/screens/pages_screen.dart) | Page dots, tab indicator and reversed viewport progress | Widget open/dispose pass; browser opens at 1440px and 375px | Familiar paging/tab interactions communicate value | Fixed derived-listener allocation on each layout by caching and disposing the mapped offset (S2 overhead) | P0 | Keep after ownership fix; owner review pending | Good: page swipe and tab selection |
| [Directional transitions](../../example/lib/screens/transitions_screen.dart) | Separate reverse/exit timings, loop modes and spring keyframes | Widget open/dispose pass; browser opens at 1440px and 375px | Paired loops make ping-pong versus restart visible | Loops must stop when screen is removed; hold gesture is pointer-oriented, other controls are keyboard operable | P1 | Keep; owner review pending | Good: short paired-loop shot |
| [Hot reload replay](../../example/lib/screens/hot_reload_screen.dart) | Development-time entrance replay | Widget open/dispose pass; browser opens at 1440px and 375px | Entrance cards are visible in release web builds | Actual hot reload requires a debug development session; a public static deployment cannot demonstrate editing (S3) | P2 | Keep, labeled developer-only behavior; owner review pending | No: use a separate developer tutorial |
| [Custom Simulation](../../example/lib/screens/simulation_screen.dart) | Gravity simulation and chained bounces | Widget open/dispose pass; browser opens at 1440px and 375px | Drop button and bounce count make the physics easy to read | Superseded driver futures complete; original callback could restart old bounce chains after rapid Drop (S1), fixed with run generation guard | P0 | Keep after restart fix; owner review pending | Good: one clean drop |

## Other existing applications

| Example and source | Capability | Functional evidence | Presentation and limitations | Priority | Showcase / recording recommendation |
|---|---|---|---|---|---|
| [Daily Focus](../../example/lib/main.dart) | Task interactions, navigation, variants, list entrance, layout, presence and scroll values in one app | Widget open/dispose pass; browser opens at 1440px and 375px | Dashboard now passes at 343×700, 375×812 and 1440×900 after badge/header overflow fixes. Calendar, Stats and Profile are labeled placeholder screens; light palette is intentional. Do not imply persistent task data or completed calendar features. Async toast checks mounted and identity; controllers and scroll values dispose. | P1 | Include; record the dashboard. Owner approval pending. |
| [README entrance](../../example/lib/readme/entrance.dart) | Declarative initial/animate state with a spring | Exact-source and target-state tests pass; browser opens | Minimal teaching example with a real animated entrance. Presentation chrome belongs to the gallery, not the copied API snippet. | P1 | Include; brief introduction footage. Owner approval pending. |
| [README retarget](../../example/lib/readme/retarget.dart) | Tap-driven spring retarget with scale and rotation | Exact-source and retarget tests pass; browser opens | Clear primary control and reversible state. Keep the README's copied source synchronized. | P1 | Include; strong short recording candidate. Owner approval pending. |

## New feature demonstrations

These five screens add public API coverage beyond the original registry. Their
widget tests passed at 375×850 in light mode and 1100×850 in dark mode, including
reduced motion, controls, and disposal. They use theme colors and scroll within
the gallery panel. Browser rendering and owner approval remain separate checks.

| Example and source | Capability and controls | Executed evidence | Limits and recording recommendation |
|---|---|---|---|
| [Text in motion](../../example/lib/screens/showcase_text.dart) | `NibText` word/character staggering, `NibTypewriter`, `NibTextReveal`; select a treatment and replay | Typewriter reaches the complete sentence; replay resets it; mode changes and reduced-motion completion pass | Uses words, characters, typewriter and mask reveal, not the gradient-text API. A short word entrance or typewriter scene is suitable after browser/owner review. |
| [Shader studio](../../example/lib/screens/showcase_effects.dart) | `NibDissolve`, `NibShimmer`, `NibGlass`; select an effect, replay dissolve, toggle shimmer | Effect selection, shimmer control, fallback rendering, and disposal pass; browser CanvasKit debug check confirms dissolve shows the finished card | Widget tests deliberately use unavailable shader assets to check fallback behavior. The panel separately reports shader loading and glass support. Shimmer obscures the card with an opaque sweep; see the visual limitation below. Record dissolve after owner review. Glass on Flutter web is a frosted fallback, not a refraction demo. |
| [Follow a path](../../example/lib/screens/showcase_paths.dart) | `NibPathMotion` and `NibDrawPath` share a curve; Replay and Pause control both | Render progress advances, holds while paused, and restarts after replay; reduced motion shows arrival immediately | Pause/play has the runtime issue documented below. The screen offers Pause and Replay without claiming resume. Both effects use the same three-second duration and curve; this is illustrative timing, not a synchronization guarantee. |
| [Coordinated states](../../example/lib/screens/showcase_variants.dart) | Named variants, propagated stagger, `NibPulse`, `NibFloat`, `NibBounce`; rest/lift, replay, preset toggle | State controls, preset toggle, reduced motion, and disposal pass | Pulse and float repeat; bounce is one entrance. Tickers stop when presets are paused or the screen is removed. Record stagger first; keep optional loops brief. |
| [Navigation flow](../../example/lib/screens/showcase_navigation.dart) | `NibNavBar` spring indicator with `NibScreenStack`; switch destination and fade/shared-axis/slide transition | Visible destination changes and reduced-motion transitions pass | Uses a pill indicator and illustrative destination content. This does not demonstrate the liquid navigation shader or persistent application data. Suitable for a compact tab-transition scene after browser/owner review. |

`example/test/showcase_features_test.dart`: 12 tests passed. Log:
`nib-showcase-features-test.log`. Targeted analysis and formatting passed. These
checks do not measure frame time or prove visual parity across renderers.

Water was not added to the core gallery in this audit; the separate Lagoon showcase covers it. Its receiver
sampling and GPU behavior need a confirmed target renderer; existing stable
APIs cover the missing presentation groups without making that experiment the
audience's first experience.

## Fixes and runtime boundaries

Fixes in this task belong to example code. No engine change is approved by this
report. In particular, `NibSimulationDriver.run()` documents that stopping or
superseding a run completes its future. A demo must distinguish a completed
bounce from an obsolete run before chaining a new simulation.

Direct `SpringSolver` and `MultiSpringSolver` calls are low-level APIs. Their
caller owns the reduced-motion decision; the gallery cannot assume a wrapper
will stop a solver started directly by an example.

`NibTimeline.progress` is a seek position. Pressing Play does not advance the
scrubber thumb. Cancellation can also leave the returned play future pending
when a scheduled entry has not fired. The examples do not await that future or
present it as a completion signal. These documented runtime limits remain
visible in the review; they are not hidden with a replacement animation.

## Known runtime issue: path pause and play

**S2, separate engine review required.** Both `NibPathMotionController.play()`
and `NibDrawPathController.play()` are documented as resuming playback. In the
current implementation, pausing and then calling `play()` starts a new ticker
clock with `_startTime = Duration.zero`. Progress returns to the beginning on
the next tick instead of continuing from the held position.

[Minimal failing tests](repros/path_pause_play.dart):

```bash
cd example
flutter test ../doc/maintainers/repros/path_pause_play.dart
```

With a one-second linear path, pause at 600 ms, wait 200 ms, then play for 100 ms.
Expected resumed progress: `0.7`. Observed progress: `0.1` for both the moving
marker and drawn stroke. Both reproductions were executed on Flutter 3.47.8 and
failed that resume expectation; the paused position itself stays fixed. Source:
[`NibPathMotion._play`](../../lib/src/path/nib_path_motion.dart) and
[`NibDrawPath._play`](../../lib/src/path/nib_draw_path.dart).

The new showcase exposes Pause and an explicit Replay action. No engine code
was changed, and the reproduction remains outside the passing showcase suite
as a documented failing test for a later runtime fix.

## Shimmer visual limitation

The CanvasKit debug browser check showed a flat ochre rectangle with a moving
dark band in Shader studio's Shimmer mode. The card's text, icon, and rounded
corners were hidden even though the shader loaded. Dissolve separately settled
to the expected rounded gradient card with its text and icon visible.

This matches the current rendering code. [`RenderNibShimmer.paint`](../../lib/src/shaders/nib_shimmer.dart)
paints the child, then draws a shader rectangle over its whole bounds.
[`shimmer.frag`](../../lib/shaders/shimmer.frag) mixes two colors without sampling
or masking the child. The demo supplies opaque colors, so the rectangle covers
the child; its dark-theme surface color also makes the sweep darker than its
base. The [real-shader test](../../test/shaders/nib_shader_real_test.dart) checks
that shimmer replaces a white child's pixel color. It does not establish that
text, shapes, or transparent corners remain visible.

The loaded status establishes shader availability, not a successful card
overlay. This state should not be presented as a polished shimmer-card example
or used for launch footage. No renderer-wide claim follows from this single
browser check, and no engine behavior was changed in this task.

## Web identity

The web title, description, app name, theme color, favicon, and install icons
now identify NibMotion. Icons are resized derivatives of the existing
`assets/nib-logo.png`; the favicon crops its central nib. No new illustration
or logo was generated. Maskable icons leave the mark inside the central safe
area. The Flutter base-href placeholder and bootstrap script are unchanged.

Manifest JSON, icon references, output dimensions, and the loader/base-href
strings were checked. Browser installation and operating-system icon masking
were not tested.

## Known runtime issue: gradient policy changes

**S1, separate engine review required.** On Flutter 3.47.8, mounting
`NibGradientText` under reduced motion, then setting the policy to false, true,
and false again throws: `_NibGradientTextState is a SingleTickerProviderStateMixin
but multiple tickers were created.` The same sequence occurs through the
Reduced motion demo's switch. The `_startTicker()` method disposes its ticker,
then calls `createTicker()` again on a single-ticker provider.

[Minimal failing test](repros/gradient_reduced_motion.dart):

```bash
cd example
flutter test ../doc/maintainers/repros/gradient_reduced_motion.dart
```

Expected: the gradient resumes and freezes as the policy changes. Actual: the
second resume asserts in `lib/src/text/nib_text_gradient.dart` at ticker creation.
The reproduction was executed and failed. The normal audit suite explicitly
skips this one repeated-toggle case, with the issue linked in its source; it
still checks this screen's initial rendering in both motion policies. No engine
code or substitute effect was introduced to conceal the failure. Browser reproduction also triggered cascading framework assertions. A full page
reload restored the app. Export review notes before testing this sequence. The affected page is unsuitable for
final approval until the engine fix is separately reviewed.

## Executed focused validation

- `flutter test test/demo_audit_test.dart --reporter expanded`: 71 passed, one
  skipped for the known runtime issue. Log: `nib-showcase-demo-audit-final.log`.
- Baseline tests reproduced palette overflow, row overflow, stale simulation
  completions and Daily Focus narrow-layout overflow before the example fixes.
- Both policies were checked on entry for all 21 original screens. Tab-key focus
  traversal did not throw. This does not establish full keyboard equivalence for
  spatial drag, tap-pad or long-press interactions; those limits are recorded.
- Disposing each tested screen left zero scheduled transient frame callbacks.
  This checks active Flutter tickers, not a heap profiler or browser GPU memory.
- Rapid Drop restarts retained one bounce chain and the final run reached rest.
  Repeated page width/tab changes and presence row additions stayed usable.

## Browser and media evidence

All 29 pages opened in the Chromium-based in-app browser at 1440×1000 and
375×812 logical pixels. The complete sequence was traversed with Next/Previous;
no page was removed to pass the audit. Representative visual checks covered the
overview, springs, drag, layout, presence, shader studio, text and navigation.
Every row above also has a source-based presentation assessment; visual parity
across all browsers is not established.

Executed interactions included rapid spring recipe retargeting, actual pointer
drags on both inertia/snap tracks, layout Reverse/Rotate, presence remove/re-add,
sliver insertion/removal, repeated Drop, destination changes, text replay and
shader selection. Search narrowed to Text in motion; keyboard clearing plus the
Accessibility filter left Reduced motion. Light/dark controls and the compact
drawer worked. Daily Focus originally reset the URL: embedding its themed home
without a second MaterialApp fixed that; navigation, refresh, Back and Forward
then preserved the daily-focus route.

Browser errors: the deliberate reduced-motion toggle reproduction produced the
documented ticker assertion and cascading framework errors. A development hot
restart separately produced one disposed EngineFlutterView assertion; a full
reload restored rendering. These are not presented as a clean debug console.
Shimmer loaded but covered its child as documented above. Glass reported its
frosted fallback. No Safari, Firefox or physical-phone test was performed.

The release Wasm preview loaded `main.dart.mjs` and `main.dart.wasm`, rendered
the gallery, and responded to the spring recipe controls. Its console reported
no errors during this check. The local static server does not provide
cross-origin isolation headers, so Skwasm reports single-threaded operation.
No heap, GPU or frame-time profiling was performed.

Actual 1920×1080, 30 FPS desktop capture used wf-recorder and UI interaction with
the running Flutter app. [Media notes](showcase-media.md) contain the edit,
file metadata, playback checks and owner review instructions. Raw recordings
stay outside the package. No rendered substitute animation was used.

## Owner review

1. Open the verified preview URL from the delivery report. Test desktop and phone widths.
2. Visit every original entry, Daily Focus, both README examples and each new entry.
3. Try each stated interaction, then replay and leave while it is still moving.
4. Check normal motion, reduced motion, light/dark presentation, keyboard controls and source links.
5. Mark each entry Approved or Needs improvement in review mode; leave concrete notes and export the results.
6. Watch the actual GIF and MP4. Approve individual scenes and the opening poster before selecting final public media.
7. Keep PR #5 unmerged and package 0.3.6 unpublished until the separate release approval.

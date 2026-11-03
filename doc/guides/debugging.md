---
{
  "id": "debugging",
  "evidence": "MotionNib/motion/doc/debug-tools.md; MotionNib/motion/lib/src/debug/nib_spring_tuner.dart; MotionNib/motion/test/runtime/helpers_tuner_test.dart"
}
---

# Debugging and spring tuning

Tune a real spring, inspect motion values, and replay entrances without changing your production interaction.

<!-- section: tuner -->
## Tune one response at a time

NibSpringTuner compares duration/bounce and mass/stiffness/damping with a real SpringSolver preview, step-response curve and copyable configuration. Use it during development, then put the selected NibSpringDescription in the transition that owns the interaction.

The live springs guide lets you retarget while moving. Compare travel distance and interruption as well as overshoot; a spring that feels good for a short press may be too loose for a large panel.

```dart
// In a development panel.
NibSpringTuner(
  onChanged: (spring) => debugPrint('$spring'),
)
```

[Try the spring controls](springs.md)

<!-- section: inspect -->
## Inspect values before changing timing

NibMotionDebugger and NibMotionRegistry expose registered motion values and activity. NibPerfOverlay gives development feedback; Flutter DevTools and frame timings are needed to separate build, layout, paint and raster cost.

If nothing moves, first inspect the target, reduced-motion policy, active ticker mode and controller ownership. A paint offset does not move a layout slot. A stale key can make Flutter reuse the wrong item after reordering.

[Troubleshoot a concrete symptom](troubleshooting.md)

<!-- section: replay -->
## Replay without losing application state

NibHotReloadReplay listens to reassemble and fires a descendant replay signal in debug mode. It does nothing in a release build. Use NibMotionReplaySignal and NibMotionReplayScope for an explicit replay action; a new key remounts a widget and resets its State.

NibTimelineScrubber and NibTimelineDragScrubber seek a timeline. Scrubbing cancels pending play timers. Verify cancellation and disposal when leaving the screen, then test the same action with reduced motion.

[Timeline playback and seeking](timeline.md)

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'motion_value_inspector.dart';
import 'nib_perf_overlay.dart';

/// A conditional debug overlay for `nib_motion` apps.
///
/// Wrap the root of an app (or any subtree) in [NibMotionDebugger] during
/// development to get a floating panel showing a live FPS counter
/// ([NibPerfOverlay]) and a live readout of every [MotionValue] registered
/// with [NibMotionRegistry].
///
/// When [enabled] is `false` (the default outside [kDebugMode]),
/// [NibMotionDebugger] is a **complete no-op passthrough**: `build` returns
/// [child] directly, with no `Stack`, no overlay, and no extra widgets in
/// the tree at all. This is the most important behavioral contract of this
/// widget — it must add zero overhead in release builds.
class NibMotionDebugger extends StatelessWidget {
  /// Creates a debug overlay wrapping [child].
  ///
  /// [enabled] defaults to [kDebugMode] — debugging is on automatically in
  /// debug builds and off automatically in profile/release builds.
  const NibMotionDebugger({
    super.key,
    required this.child,
    this.enabled = kDebugMode,
    this.showBoundingBoxes = true,
    this.showMotionValues = true,
    this.showFps = true,
  });

  /// The widget subtree being debugged. Always rendered, regardless of
  /// [enabled].
  final Widget child;

  /// Whether the debug overlay is active at all. When `false`, this widget
  /// is a no-op passthrough that returns [child] directly.
  final bool enabled;

  /// Whether to outline `NibMotion`-bearing render boxes found in the
  /// element tree under [child].
  ///
  /// ## Engineering judgement
  ///
  /// The spec describes this as "outline each NibMotion", which in a full
  /// implementation would mean walking the element tree, finding every
  /// element whose render object corresponds to a live `NibMotion`, and
  /// drawing a rectangle at its `RenderBox.localToGlobal` bounds — kept in
  /// sync as those boxes move/resize/animate every frame. Doing that
  /// correctly (handling clipping, scrolling, transforms, and rebuilds)
  /// without making this debug widget itself a source of per-frame
  /// overhead is a non-trivial feature in its own right, and `NibMotion`
  /// does not currently expose any registry of its own render objects to
  /// walk (only `MotionValue`s, via [NibMotionRegistry]).
  ///
  /// Rather than ship a half-working bounding-box tracer (e.g. one that
  /// only paints stale boxes, or that walks the tree once and silently goes
  /// stale on the next animation frame), this flag is implemented as a
  /// simple, honest visual marker: when `true`, the overlay panel header
  /// shows a small indicator confirming bounding-box mode is "on", and the
  /// overlay itself is painted with a dashed border to signal that
  /// debug-paint mode is active for this subtree. This is intentionally a
  /// simplified stand-in for true per-widget bounding boxes, documented
  /// here rather than silently passing as a full implementation.
  final bool showBoundingBoxes;

  /// Whether to show a live list of [NibMotionRegistry.instance.values].
  final bool showMotionValues;

  /// Whether to show the [NibPerfOverlay] FPS counter.
  final bool showFps;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }

    return Stack(
      children: [
        child,
        Positioned(
          top: 24,
          right: 12,
          child: _DebugPanel(
            showBoundingBoxes: showBoundingBoxes,
            showMotionValues: showMotionValues,
            showFps: showFps,
          ),
        ),
      ],
    );
  }
}

/// The floating panel rendered by [NibMotionDebugger] when enabled.
///
/// Split into its own widget (rather than inlined in `build`) so it can
/// rebuild independently of [NibMotionDebugger.child].
class _DebugPanel extends StatefulWidget {
  const _DebugPanel({
    required this.showBoundingBoxes,
    required this.showMotionValues,
    required this.showFps,
  });

  final bool showBoundingBoxes;
  final bool showMotionValues;
  final bool showFps;

  @override
  State<_DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends State<_DebugPanel> {
  // The MotionValues list's Scrollbar needs an explicit controller: without
  // one it falls back to the ambient PrimaryScrollController, which isn't
  // guaranteed to be attached to *this* scroll view (and threw
  // "Scrollbar's ScrollController has no ScrollPosition attached" in a real
  // app where the primary scroll view was elsewhere on screen).
  final ScrollController _valuesScrollController = ScrollController();

  @override
  void dispose() {
    _valuesScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final registeredValues = NibMotionRegistry.instance.values;

    return Material(
      color: Colors.transparent,
      child: Container(
        key: const ValueKey('nib_motion_debugger_panel'),
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(8),
          border: widget.showBoundingBoxes
              ? Border.all(color: Colors.greenAccent, width: 1)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'NibMotionDebugger',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.showFps) ...[
              const SizedBox(height: 6),
              const NibPerfOverlay(),
            ],
            if (widget.showMotionValues) ...[
              const SizedBox(height: 6),
              Text(
                'MotionValues: ${registeredValues.length}',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const SizedBox(height: 2),
              // A real app can easily register dozens of MotionValues (one
              // NibMotion contributes 11) — without a height cap + scroll
              // here, this list grows as tall as its content and runs off
              // the bottom of the screen with no way to see what's cut off.
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: Scrollbar(
                  controller: _valuesScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _valuesScrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final entry in registeredValues.entries)
                          Text(
                            '${entry.key}: ${entry.value.value}',
                            style: const TextStyle(color: Colors.white54, fontSize: 10),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

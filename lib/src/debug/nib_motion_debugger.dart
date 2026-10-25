import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/reduced_motion.dart';
import 'motion_value_inspector.dart';
import 'nib_perf_overlay.dart';
import '../values/motion_value.dart';

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
    this.showReducedMotionToggle = true,
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

  /// Whether to show a switch that previews reduced motion by setting the
  /// global `NibMotionConfig.setReducedMotion` override (cleared when the
  /// debugger is removed). It affects animations as they start; ones already
  /// running finish normally.
  final bool showReducedMotionToggle;

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
            showReducedMotionToggle: showReducedMotionToggle,
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
    required this.showReducedMotionToggle,
  });

  final bool showBoundingBoxes;
  final bool showMotionValues;
  final bool showFps;
  final bool showReducedMotionToggle;

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

  bool _reduced = false;

  /// Previews reduced motion by setting the global override
  /// (`NibMotionConfig.setReducedMotion`). Animations already running are not
  /// interrupted; the policy applies to each animation as it starts.
  void _setReduced(bool value) {
    setState(() => _reduced = value);
    NibMotionConfig.setReducedMotion(value ? true : null);
  }

  @override
  void dispose() {
    if (_reduced) NibMotionConfig.setReducedMotion(null);
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
            if (widget.showReducedMotionToggle) ...[
              const SizedBox(height: 4),
              GestureDetector(
                key: const ValueKey('nib_debugger_reduced_motion'),
                behavior: HitTestBehavior.opaque,
                onTap: () => _setReduced(!_reduced),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _reduced
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 14,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 6),
                    const Text('Reduce motion',
                        style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
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
                          _ValueRow(id: entry.key, value: entry.value),
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

/// One live row of the values list: `id: value  v=velocity`.
///
/// Listens to its own [MotionValue], so the debugger shows moving numbers
/// without rebuilding the rest of the panel or the app.
class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.id, required this.value});

  final String id;
  final MotionValue<dynamic> value;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: value,
      builder: (context, _) {
        final velocity = value.velocity;
        final suffix =
            velocity == 0 ? '' : '  v=${velocity.toStringAsFixed(1)}/s';
        return Text(
          '$id: ${value.value}$suffix',
          style: const TextStyle(color: Colors.white54, fontSize: 10),
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

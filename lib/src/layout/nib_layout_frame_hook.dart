import 'package:flutter/scheduler.dart';

/// A render object that measures its own layout movement.
///
/// `RenderNibMotion(layout:)` implements it so the frame hook can re-measure it
/// when its own `paint` was skipped (a `RepaintBoundary` re-composited it at a
/// new offset without repainting it).
abstract class NibLayoutMeasurable {
  /// The [NibLayoutFrameHook.frame] in which this object last measured.
  int get lastMeasuredFrame;

  /// Measures now and starts a FLIP if the layout position or size changed.
  void remeasureLayout();
}

/// Safety net for layout movement that never reaches `paint`.
///
/// `NibMotion(layout:)` detects movement in `paint`, which is pre-paint and
/// flash-free. A `RepaintBoundary` (every `ListView` item gets one) can move a
/// child without repainting it; then `paint` is skipped, and nothing can mark
/// it dirty during the paint phase. This hook re-measures, once per frame and
/// after it, every registered box that did not measure itself, so the move is
/// animated — but it starts one frame late: the new position shows for a
/// single frame before the FLIP takes over.
class NibLayoutFrameHook {
  NibLayoutFrameHook._();

  static final Set<NibLayoutMeasurable> _nodes = <NibLayoutMeasurable>{};
  static bool _installed = false;

  /// Completed frames since the hook was installed.
  static int frame = 0;

  /// Starts re-measuring [node] after frames in which it did not measure.
  static void register(NibLayoutMeasurable node) {
    _nodes.add(node);
    if (_installed) return;
    _installed = true;
    SchedulerBinding.instance.addPersistentFrameCallback(_onFrame);
    // The frame that installs the hook does not run it (persistent callbacks
    // are snapshotted at the start of the phase), so count that frame here;
    // otherwise boxes measured in it would look "measured" in the next one.
    SchedulerBinding.instance.addPostFrameCallback((_) => frame++);
  }

  /// Stops re-measuring [node].
  static void unregister(NibLayoutMeasurable node) => _nodes.remove(node);

  /// Number of registered boxes (for tests).
  static int get registeredCount => _nodes.length;

  static void _onFrame(Duration _) {
    if (_nodes.isNotEmpty) {
      for (final node in List<NibLayoutMeasurable>.of(_nodes)) {
        if (node.lastMeasuredFrame != frame) node.remeasureLayout();
      }
    }
    frame++;
  }
}

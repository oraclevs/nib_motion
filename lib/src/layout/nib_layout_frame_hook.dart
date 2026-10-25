import 'package:flutter/scheduler.dart';
import 'package:flutter/rendering.dart';

import 'nib_layout_scope.dart';

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
/// `NibLayoutScope` remeasures descendants after layout so cached repaint
/// boundaries have their FLIP before paint. If a layout change does not
/// relayout the scope, this hook catches it after the frame; that fallback
/// begins one frame late.
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

  /// Measures box descendants after their scope finishes layout, before any
  /// cached repaint boundary can be re-composited at its new position.
  /// Sliver descendants wait for their geometry to settle and use the hook.
  static void remeasureInScope(RenderObject scope) {
    for (final node in List<NibLayoutMeasurable>.of(_nodes)) {
      if (node is! RenderObject) continue;
      final renderNode = node as RenderObject;
      if (!renderNode.attached) continue;
      var ancestor = renderNode.parent;
      var insideSliver = false;
      while (ancestor != null && ancestor != scope) {
        if (ancestor is RenderNibLayoutScope) break;
        if (ancestor is RenderSliver) insideSliver = true;
        ancestor = ancestor.parent;
      }
      if (ancestor == scope && !insideSliver) node.remeasureLayout();
    }
  }

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

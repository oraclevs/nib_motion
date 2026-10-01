import 'package:flutter/widgets.dart';

import '../core/render_nib_motion.dart';

/// Records the global position and size of widgets identified by
/// [GlobalKey]s, and computes how far each one has moved since it was last
/// recorded.
///
/// Used by `NibLayoutGroup` to implement the FLIP (First, Last, Invert, Play)
/// technique: record positions before a layout change ("First"), then again
/// after ("Last"), and use the difference to drive an "Invert, Play"
/// animation back to the new position.
class FlipRecorder {
  final Map<GlobalKey, Rect> _rects = <GlobalKey, Rect>{};

  /// Records the current global position and size of the [RenderBox]
  /// attached to [key], replacing any rect previously recorded for [key].
  ///
  /// Does nothing if [key] isn't currently attached to a mounted
  /// [RenderBox].
  ///
  /// With [ancestor], positions are recorded in that render object's local
  /// coordinate space instead of global space. FLIP must measure in the space
  /// its offset is applied in: under a scaled/rotated ancestor global deltas
  /// are the wrong size, and when the whole container moves (scroll, resize)
  /// every child would look like it moved.
  void record(GlobalKey key, {RenderObject? ancestor}) {
    final box = _boxFor(key);
    if (box == null) return;
    final offset = _paintedOrigin(box, ancestor);
    _rects[key] =
        Rect.fromLTWH(offset.dx, offset.dy, box.size.width, box.size.height);
  }

  /// The rect most recently recorded for [key] via [record], or `null` if
  /// none has been recorded (or it was [forget]ten).
  Rect? rectFor(GlobalKey key) => _rects[key];

  /// Returns how far the top-left corner of [key]'s [RenderBox] has moved
  /// since the last [record] call for [key]: `recordedPosition -
  /// currentPosition`, where the recorded position is where the box was
  /// *painted* (including any in-flight `NibMotion` transform) and the current
  /// position is its new *layout* position. Applying the result as a
  /// translation therefore makes the box appear exactly where it was last
  /// seen, even if a previous FLIP was still animating.
  ///
  /// Returns `null` if nothing is recorded for [key], or if [key] isn't
  /// currently attached to a mounted [RenderBox].
  ///
  /// Pass the same [ancestor] given to [record].
  Offset? computeDelta(GlobalKey key, {RenderObject? ancestor}) {
    final old = _rects[key];
    if (old == null) return null;
    final box = _boxFor(key);
    if (box == null) return null;
    final current = box.localToGlobal(Offset.zero, ancestor: ancestor);
    return Offset(old.left - current.dx, old.top - current.dy);
  }

  /// Stops tracking [key], discarding its recorded rect (if any).
  void forget(GlobalKey key) => _rects.remove(key);

  /// Where [box] is painted: for a `RenderNibMotion` this includes its own
  /// transform, which `localToGlobal` on the box itself leaves out (a render
  /// object's transform only applies to its children).
  static Offset _paintedOrigin(RenderBox box, RenderObject? ancestor) {
    if (box is RenderNibMotion) {
      final child = box.child;
      if (child != null) {
        return child.localToGlobal(Offset.zero, ancestor: ancestor);
      }
    }
    return box.localToGlobal(Offset.zero, ancestor: ancestor);
  }

  static RenderBox? _boxFor(GlobalKey key) {
    final renderObject = key.currentContext?.findRenderObject();
    return renderObject is RenderBox && renderObject.attached
        ? renderObject
        : null;
  }
}

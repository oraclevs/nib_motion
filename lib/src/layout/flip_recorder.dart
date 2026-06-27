import 'package:flutter/widgets.dart';

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
  void record(GlobalKey key) {
    final box = _boxFor(key);
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    _rects[key] = Rect.fromLTWH(offset.dx, offset.dy, box.size.width, box.size.height);
  }

  /// The rect most recently recorded for [key] via [record], or `null` if
  /// none has been recorded (or it was [forget]ten).
  Rect? rectFor(GlobalKey key) => _rects[key];

  /// Returns how far the top-left corner of [key]'s [RenderBox] has moved
  /// since the last [record] call for [key]: `recordedPosition -
  /// currentPosition`.
  ///
  /// Returns `null` if nothing is recorded for [key], or if [key] isn't
  /// currently attached to a mounted [RenderBox].
  Offset? computeDelta(GlobalKey key) {
    final old = _rects[key];
    if (old == null) return null;
    final box = _boxFor(key);
    if (box == null) return null;
    final current = box.localToGlobal(Offset.zero);
    return Offset(old.left - current.dx, old.top - current.dy);
  }

  /// Stops tracking [key], discarding its recorded rect (if any).
  void forget(GlobalKey key) => _rects.remove(key);

  static RenderBox? _boxFor(GlobalKey key) {
    final renderObject = key.currentContext?.findRenderObject();
    return renderObject is RenderBox && renderObject.attached ? renderObject : null;
  }
}

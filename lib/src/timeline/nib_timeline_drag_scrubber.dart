import 'package:flutter/widgets.dart';

import 'nib_timeline.dart';

/// Lets the user drag anywhere on [child] to scrub [timeline].
///
/// A drag along [axis] moves `timeline.progress` by `delta / extent`, through
/// the timeline's public [NibTimeline.seek], starting from wherever the
/// progress currently is (so repeated drags accumulate). Dragging stops any
/// running `play()`.
///
/// Horizontal scrubbing follows the ambient [TextDirection] unless
/// [respectTextDirection] is `false`: in RTL, dragging toward the leading
/// edge moves forward. [reverse] flips the direction on top of that.
///
/// Uses a horizontal-/vertical-drag recogniser (not pan) so scrollables on the
/// other axis keep working.
class NibTimelineDragScrubber extends StatefulWidget {
  /// Creates a drag scrubber for [timeline] around [child].
  const NibTimelineDragScrubber({
    super.key,
    required this.timeline,
    required this.child,
    this.axis = Axis.horizontal,
    this.extent,
    this.reverse = false,
    this.respectTextDirection = true,
    this.onScrubStart,
    this.onScrubEnd,
  });

  /// The timeline being scrubbed.
  final NibTimeline timeline;

  /// The content that accepts the drag.
  final Widget child;

  /// The axis dragged along.
  final Axis axis;

  /// Pixels of drag that cover progress `0 → 1`. Defaults to this widget's
  /// size along [axis].
  final double? extent;

  /// Flips the drag direction.
  final bool reverse;

  /// Whether horizontal scrubbing is mirrored in right-to-left layouts.
  final bool respectTextDirection;

  /// Called when a scrub gesture begins.
  final VoidCallback? onScrubStart;

  /// Called when a scrub gesture ends or is cancelled.
  final VoidCallback? onScrubEnd;

  @override
  State<NibTimelineDragScrubber> createState() =>
      _NibTimelineDragScrubberState();
}

class _NibTimelineDragScrubberState extends State<NibTimelineDragScrubber> {
  double _startProgress = 0.0;
  double _accumulated = 0.0;
  double _extent = 1.0;

  void _start(DragStartDetails details) {
    final size = context.size ?? Size.zero;
    final along = widget.axis == Axis.horizontal ? size.width : size.height;
    _extent = widget.extent ?? along;
    if (_extent <= 0) _extent = 1.0;
    _startProgress = widget.timeline.progress.value;
    _accumulated = 0.0;
    widget.timeline.stop();
    widget.onScrubStart?.call();
  }

  void _update(DragUpdateDetails details) {
    final delta =
        widget.axis == Axis.horizontal ? details.delta.dx : details.delta.dy;
    _accumulated += delta;
    var sign = widget.reverse ? -1.0 : 1.0;
    if (widget.axis == Axis.horizontal &&
        widget.respectTextDirection &&
        Directionality.maybeOf(context) == TextDirection.rtl) {
      sign = -sign;
    }
    widget.timeline.seek(_startProgress + sign * _accumulated / _extent);
  }

  void _end() => widget.onScrubEnd?.call();

  @override
  Widget build(BuildContext context) {
    final horizontal = widget.axis == Axis.horizontal;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: horizontal ? _start : null,
      onHorizontalDragUpdate: horizontal ? _update : null,
      onHorizontalDragEnd: horizontal ? (_) => _end() : null,
      onHorizontalDragCancel: horizontal ? _end : null,
      onVerticalDragStart: horizontal ? null : _start,
      onVerticalDragUpdate: horizontal ? null : _update,
      onVerticalDragEnd: horizontal ? null : (_) => _end(),
      onVerticalDragCancel: horizontal ? null : _end,
      child: widget.child,
    );
  }
}

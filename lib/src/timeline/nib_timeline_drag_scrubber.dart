import 'dart:math' as math;

import 'package:flutter/physics.dart' show FrictionSimulation;
import 'package:flutter/widgets.dart';

import '../core/reduced_motion.dart';
import '../physics/inertia_solver.dart';
import '../physics/spring_description.dart';
import '../physics/spring_solver.dart';
import '../values/motion_value.dart';
import 'nib_timeline.dart';

/// What a [NibTimelineDragScrubber] does with the progress when the finger
/// lifts.
enum NibScrubRelease {
  /// Leave the progress exactly where it is (the default).
  stay,

  /// Spring to whichever end (`0` or `1`) the scrub was heading for — the
  /// nearer end to where the progress *would be* ~120 ms later at the release
  /// velocity, so a quick flick wins over the exact position.
  snapToNearest,

  /// Keep going with the release velocity and decelerate to rest, bounded to
  /// `0..1` (a small elastic overshoot at an end settles back onto it).
  momentum,

  /// Spring back to the progress the scrub started from.
  springBack,
}

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
    this.release = NibScrubRelease.stay,
    this.releaseSpring = NibSpringDescription.snappy,
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

  /// Called when a scrub gesture ends or is cancelled (at release, not when a
  /// [release] animation finishes).
  final VoidCallback? onScrubEnd;

  /// What happens to the progress when the finger lifts. A new drag cancels
  /// any release animation still running. With reduced motion the release
  /// jumps to its resting progress instead of animating.
  final NibScrubRelease release;

  /// The spring used by [NibScrubRelease.snapToNearest] and
  /// [NibScrubRelease.springBack].
  final NibSpringDescription releaseSpring;

  @override
  State<NibTimelineDragScrubber> createState() =>
      _NibTimelineDragScrubberState();
}

class _NibTimelineDragScrubberState extends State<NibTimelineDragScrubber>
    with TickerProviderStateMixin {
  double _startProgress = 0.0;
  double _accumulated = 0.0;
  double _extent = 1.0;
  double _sign = 1.0;

  // Release animations run on a scratch value whose changes seek the timeline.
  final MotionValue<double> _release = MotionValue<double>(0.0);
  SpringSolver? _spring;
  InertiaSolver? _inertia;

  @override
  void initState() {
    super.initState();
    _release.addListener(_onReleaseValue);
  }

  void _onReleaseValue() => widget.timeline.seek(_release.value);

  void _stopRelease() {
    _spring?.stop();
    _inertia?.stop();
  }

  @override
  void dispose() {
    _release.removeListener(_onReleaseValue);
    _spring?.dispose();
    _inertia?.dispose();
    _release.dispose();
    super.dispose();
  }

  void _start(DragStartDetails details) {
    final size = context.size ?? Size.zero;
    final along = widget.axis == Axis.horizontal ? size.width : size.height;
    _extent = widget.extent ?? along;
    if (_extent <= 0) _extent = 1.0;
    _stopRelease();
    _startProgress = widget.timeline.progress.value;
    _accumulated = 0.0;
    widget.timeline.stop();
    widget.onScrubStart?.call();
  }

  void _update(DragUpdateDetails details) {
    final delta =
        widget.axis == Axis.horizontal ? details.delta.dx : details.delta.dy;
    _accumulated += delta;
    _sign = _dragSign();
    widget.timeline.seek(_startProgress + _sign * _accumulated / _extent);
  }

  double _dragSign() {
    var sign = widget.reverse ? -1.0 : 1.0;
    if (widget.axis == Axis.horizontal &&
        widget.respectTextDirection &&
        Directionality.maybeOf(context) == TextDirection.rtl) {
      sign = -sign;
    }
    return sign;
  }

  void _end([DragEndDetails? details]) {
    widget.onScrubEnd?.call();
    final pxPerSecond = details?.primaryVelocity ?? 0.0;
    final velocity = _dragSign() * pxPerSecond / _extent; // progress / s
    _runRelease(velocity.isFinite ? velocity : 0.0);
  }

  void _runRelease(double velocity) {
    final timeline = widget.timeline;
    final from = timeline.progress.value;
    final reduced = NibMotionConfig.shouldReduceMotion(context);

    void springTo(double target) {
      if (reduced) {
        timeline.seek(target);
        return;
      }
      _release.value = from;
      final solver = _spring ??= SpringSolver(
          vsync: this, value: _release, spring: widget.releaseSpring);
      solver.spring = widget.releaseSpring;
      solver.animateTo(target: target, initialVelocity: velocity);
    }

    switch (widget.release) {
      case NibScrubRelease.stay:
        return;
      case NibScrubRelease.snapToNearest:
        final projected = from + velocity * 0.12;
        springTo(projected >= 0.5 ? 1.0 : 0.0);
      case NibScrubRelease.springBack:
        springTo(_startProgress);
      case NibScrubRelease.momentum:
        if (reduced) {
          final rest = FrictionSimulation(0.135, from, velocity).finalX;
          timeline.seek(math.min(1.0, math.max(0.0, rest)));
          return;
        }
        _release.value = from;
        final solver = _inertia ??= InertiaSolver(vsync: this, value: _release);
        solver.animateTo(velocity: velocity, min: 0.0, max: 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = widget.axis == Axis.horizontal;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: horizontal ? _start : null,
      onHorizontalDragUpdate: horizontal ? _update : null,
      onHorizontalDragEnd: horizontal ? _end : null,
      onHorizontalDragCancel: horizontal ? () => _end() : null,
      onVerticalDragStart: horizontal ? null : _start,
      onVerticalDragUpdate: horizontal ? null : _update,
      onVerticalDragEnd: horizontal ? null : _end,
      onVerticalDragCancel: horizontal ? null : () => _end(),
      child: widget.child,
    );
  }
}

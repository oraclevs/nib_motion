import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// How a draggable `NibMotion` settles once the drag gesture ends.
enum NibDragReleaseMode {
  /// Spring back to the position the widget was at before the drag started.
  springBack,

  /// Coast to a natural stop using the release velocity.
  inertia,

  /// Stay exactly where the drag left it.
  stay,
}

/// Configuration for `NibMotion.drag`.
///
/// If `NibMotion.drag` is `null`, dragging is disabled entirely.
@immutable
class NibDragConfig {
  /// Creates a drag configuration.
  const NibDragConfig({
    this.axis,
    this.constraints,
    this.elastic = false,
    this.elasticFactor = 0.2,
    this.onDragStart,
    this.onDragEnd,
    this.releaseMode = NibDragReleaseMode.springBack,
    this.snapPoints,
    this.snapProjection = Duration.zero,
  });

  /// Locks dragging to a single axis. `null` allows free dragging.
  final Axis? axis;

  /// The bounding box the drag offset is confined to, as offsets *from the
  /// resting position* (e.g. `Rect.fromLTRB(-120, 0, 120, 0)` allows 120px
  /// either way), not absolute coordinates. Relative to the
  /// position the widget was at before the drag started. `null` means
  /// unconstrained.
  final Rect? constraints;

  /// Whether dragging past [constraints] applies rubber-band resistance
  /// instead of clamping outright.
  final bool elastic;

  /// How much of the drag past [constraints] is applied when [elastic] is
  /// `true`. Expected range `0.1`-`0.5`; smaller values are stiffer.
  final double elasticFactor;

  /// Called when a drag gesture begins.
  final VoidCallback? onDragStart;

  /// Called when a drag gesture ends, with the release velocity.
  final void Function(Velocity velocity)? onDragEnd;

  /// How the widget settles once the drag gesture ends. Ignored if
  /// [snapPoints] is set and non-empty.
  final NibDragReleaseMode releaseMode;

  /// Points are offsets from the resting position (not absolute coordinates).
  ///
  /// If set and non-empty, the widget springs to the nearest of these points
  /// on release instead of following [releaseMode].
  final List<Offset>? snapPoints;

  /// How far ahead, along the release velocity, to look when choosing the
  /// nearest of [snapPoints]. With the default [Duration.zero] the snap point
  /// nearest the release *position* wins; a value such as
  /// `Duration(milliseconds: 150)` lets a quick flick reach the next point.
  final Duration snapProjection;
}

/// Applies rubber-band resistance to [value] once it passes [min] or [max].
double applyElastic(double value, double min, double max, double factor) {
  if (value < min) return min + (value - min) * factor;
  if (value > max) return max + (value - max) * factor;
  return value;
}

/// Translates raw pan gesture callbacks into a drag offset per
/// [NibDragConfig]: axis locking and elastic/clamped constraints, plus
/// velocity tracking for [handlePanEnd].
class DragHandler {
  /// Creates a handler driven by [config], reporting position updates via
  /// [onUpdate] and the release state via [onRelease].
  DragHandler(
      {required this.config, required this.onUpdate, required this.onRelease});

  /// The drag configuration to apply.
  final NibDragConfig config;

  /// Called with the new drag offset (relative to the gesture's start) on
  /// every pan update.
  final ValueChanged<Offset> onUpdate;

  /// Called once when the pan gesture ends, with the final drag offset and
  /// the release velocity.
  final void Function(Offset offset, Velocity velocity) onRelease;

  VelocityTracker? _velocityTracker;
  Offset _offset = Offset.zero;

  /// The current drag offset relative to the gesture's start.
  Offset get offset => _offset;

  /// Call from `GestureDetector.onPanStart`.
  void handlePanStart(DragStartDetails details) {
    _offset = Offset.zero;
    _velocityTracker =
        VelocityTracker.withKind(details.kind ?? PointerDeviceKind.touch);
    config.onDragStart?.call();
  }

  /// Call from `GestureDetector.onPanUpdate`.
  void handlePanUpdate(DragUpdateDetails details) {
    _velocityTracker?.addPosition(
        details.sourceTimeStamp ?? Duration.zero, details.globalPosition);

    var dx = details.delta.dx;
    var dy = details.delta.dy;
    if (config.axis == Axis.vertical) dx = 0.0;
    if (config.axis == Axis.horizontal) dy = 0.0;

    var newX = _offset.dx + dx;
    var newY = _offset.dy + dy;

    final constraints = config.constraints;
    if (constraints != null) {
      if (config.elastic) {
        newX = applyElastic(
            newX, constraints.left, constraints.right, config.elasticFactor);
        newY = applyElastic(
            newY, constraints.top, constraints.bottom, config.elasticFactor);
      } else {
        newX = newX.clamp(constraints.left, constraints.right);
        newY = newY.clamp(constraints.top, constraints.bottom);
      }
    }

    _offset = Offset(newX, newY);
    onUpdate(_offset);
  }

  /// Call from `GestureDetector.onPanEnd`.
  void handlePanEnd(DragEndDetails details) {
    final velocity = _velocityTracker?.getVelocity() ?? Velocity.zero;
    onRelease(_offset, velocity);
    _velocityTracker = null;
  }
}

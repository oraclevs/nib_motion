import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../physics/spring_description.dart';
import '../physics/spring_solver.dart';
import '../values/motion_value.dart';

/// Bridges the [MotionValue]s owned by [NibDraggable] to
/// [_RenderNibDraggable].
class _NibDraggableBox extends SingleChildRenderObjectWidget {
  const _NibDraggableBox({required this.x, required this.y, super.child});

  final MotionValue<double> x;
  final MotionValue<double> y;

  @override
  _RenderNibDraggable createRenderObject(BuildContext context) {
    return _RenderNibDraggable(x: x, y: y);
  }

  @override
  void updateRenderObject(
      BuildContext context, _RenderNibDraggable renderObject) {
    renderObject
      ..x = x
      ..y = y;
  }
}

/// Paints [child] translated by [x]/[y], reading both directly during
/// [paint] so dragging never triggers a widget rebuild.
class _RenderNibDraggable extends RenderProxyBox {
  _RenderNibDraggable(
      {required MotionValue<double> x, required MotionValue<double> y})
      : _x = x,
        _y = y {
    _x.addListener(_onChanged);
    _y.addListener(_onChanged);
  }

  MotionValue<double> _x;
  MotionValue<double> _y;

  /// The current horizontal translation, in logical pixels.
  MotionValue<double> get x => _x;
  set x(MotionValue<double> value) {
    if (_x == value) return;
    _x.removeListener(_onChanged);
    _x = value;
    _x.addListener(_onChanged);
    markNeedsPaint();
  }

  /// The current vertical translation, in logical pixels.
  MotionValue<double> get y => _y;
  set y(MotionValue<double> value) {
    if (_y == value) return;
    _y.removeListener(_onChanged);
    _y = value;
    _y.addListener(_onChanged);
    markNeedsPaint();
  }

  void _onChanged() => markNeedsPaint();

  @override
  void paint(PaintingContext context, Offset offset) {
    final translation = Offset(_x.value, _y.value);
    if (translation == Offset.zero) {
      super.paint(context, offset);
      return;
    }
    context.pushTransform(
      needsCompositing,
      offset,
      Matrix4.translationValues(translation.dx, translation.dy, 0.0),
      (context, offset) => super.paint(context, offset),
    );
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    transform.multiply(Matrix4.translationValues(_x.value, _y.value, 0.0));
    super.applyPaintTransform(child, transform);
  }

  @override
  void dispose() {
    _x.removeListener(_onChanged);
    _y.removeListener(_onChanged);
    super.dispose();
  }
}

/// A higher-level drag widget with boundaries, axis locking, and snap-back.
///
/// Unlike `NibMotion.drag` (which integrates dragging into the full
/// animation system), `NibDraggable` is a focused, standalone widget for the
/// common case of "let the user drag this around, optionally constrained to
/// [bounds] or a single [axis], and spring it back to [snapTarget] (or its
/// origin) on release."
///
/// Internally it holds a [MotionValue<double>] for the `x` and `y`
/// translation, written directly from `GestureDetector.onPanUpdate` and read
/// directly by a [RenderProxyBox] during `paint` — dragging never triggers a
/// widget rebuild.
class NibDraggable extends StatefulWidget {
  /// Creates a draggable wrapper around [child].
  const NibDraggable({
    super.key,
    required this.child,
    this.axis,
    this.bounds,
    this.snapBack = false,
    this.snapTarget,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.spring = NibSpringDescription.gentle,
  });

  /// The widget to make draggable.
  final Widget child;

  /// Locks dragging to a single axis. `null` allows free dragging.
  final Axis? axis;

  /// The bounding box the drag offset is confined to, relative to the
  /// widget's resting position. `null` means unconstrained.
  final Rect? bounds;

  /// Whether to spring back to the origin (`Offset.zero`, or [snapTarget] if
  /// set) when the drag gesture ends.
  final bool snapBack;

  /// If set, the offset [snapBack] animates to on release instead of
  /// `Offset.zero`.
  final Offset? snapTarget;

  /// Called when a drag gesture begins.
  final VoidCallback? onDragStart;

  /// Called with the current drag offset on every pan update.
  final ValueChanged<Offset>? onDragUpdate;

  /// Called when a drag gesture ends, with the final offset and the release
  /// velocity.
  final void Function(Offset finalOffset, Offset velocity)? onDragEnd;

  /// The spring physics used to animate back to the origin or [snapTarget]
  /// when [snapBack] is `true`.
  final NibSpringDescription spring;

  @override
  State<NibDraggable> createState() => _NibDraggableState();
}

class _NibDraggableState extends State<NibDraggable>
    with TickerProviderStateMixin {
  final MotionValue<double> _x = MotionValue<double>(0.0);
  final MotionValue<double> _y = MotionValue<double>(0.0);

  SpringSolver? _springX;
  SpringSolver? _springY;

  VelocityTracker? _velocityTracker;

  @override
  void dispose() {
    _springX?.dispose();
    _springY?.dispose();
    super.dispose();
  }

  void _handlePanStart(DragStartDetails details) {
    _springX?.stop();
    _springY?.stop();
    _velocityTracker =
        VelocityTracker.withKind(details.kind ?? PointerDeviceKind.touch);
    widget.onDragStart?.call();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    _velocityTracker?.addPosition(
        details.sourceTimeStamp ?? Duration.zero, details.globalPosition);

    var dx = details.delta.dx;
    var dy = details.delta.dy;
    if (widget.axis == Axis.vertical) dx = 0.0;
    if (widget.axis == Axis.horizontal) dy = 0.0;

    var newX = _x.value + dx;
    var newY = _y.value + dy;

    final bounds = widget.bounds;
    if (bounds != null) {
      newX = newX.clamp(bounds.left, bounds.right);
      newY = newY.clamp(bounds.top, bounds.bottom);
    }

    _x.value = newX;
    _y.value = newY;
    widget.onDragUpdate?.call(Offset(newX, newY));
  }

  void _handlePanEnd(DragEndDetails details) {
    final velocity = _velocityTracker?.getVelocity() ?? Velocity.zero;
    _velocityTracker = null;

    final finalOffset = Offset(_x.value, _y.value);
    widget.onDragEnd?.call(finalOffset, velocity.pixelsPerSecond);

    if (widget.snapBack) {
      final target = widget.snapTarget ?? Offset.zero;

      final solverX = _springX ??=
          SpringSolver(vsync: this, value: _x, spring: widget.spring);
      solverX.spring = widget.spring;
      solverX.animateTo(
          target: target.dx, initialVelocity: velocity.pixelsPerSecond.dx);

      final solverY = _springY ??=
          SpringSolver(vsync: this, value: _y, spring: widget.spring);
      solverY.spring = widget.spring;
      solverY.animateTo(
          target: target.dy, initialVelocity: velocity.pixelsPerSecond.dy);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      child: _NibDraggableBox(x: _x, y: _y, child: widget.child),
    );
  }
}

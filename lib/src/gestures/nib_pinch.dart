import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../core/paint_transform_hit_test.dart';
import '../core/reduced_motion_mixin.dart';
import '../physics/spring_description.dart';
import '../physics/spring_solver.dart';
import '../values/motion_value.dart';

/// Bridges the [MotionValue] owned by [NibPinch] to [_RenderNibPinch].
class _NibPinchBox extends SingleChildRenderObjectWidget {
  const _NibPinchBox({required this.scale, super.child});

  final MotionValue<double> scale;

  @override
  _RenderNibPinch createRenderObject(BuildContext context) {
    return _RenderNibPinch(scale: scale);
  }

  @override
  void updateRenderObject(BuildContext context, _RenderNibPinch renderObject) {
    renderObject.scale = scale;
  }
}

/// Paints [child] scaled uniformly around its center by [scale], reading it
/// directly during [paint] so pinching never triggers a widget rebuild.
class _RenderNibPinch extends RenderProxyBox with PaintTransformHitTest {
  _RenderNibPinch({required MotionValue<double> scale}) : _scale = scale {
    _scale.addListener(_onChanged);
  }

  MotionValue<double> _scale;

  /// The current uniform scale factor. Identity is `1.0`.
  MotionValue<double> get scale => _scale;
  set scale(MotionValue<double> value) {
    if (_scale == value) return;
    _scale.removeListener(_onChanged);
    _scale = value;
    _scale.addListener(_onChanged);
    markNeedsPaint();
  }

  void _onChanged() => markNeedsPaint();

  @override
  Matrix4 get paintMatrix {
    final scaleValue = _scale.value;
    if (scaleValue == 1.0) return Matrix4.identity();
    final center = size.center(Offset.zero);
    return Matrix4.translationValues(center.dx, center.dy, 0.0)
      ..multiply(Matrix4.diagonal3Values(scaleValue, scaleValue, 1.0))
      ..multiply(Matrix4.translationValues(-center.dx, -center.dy, 0.0));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final matrix = paintMatrix;
    if (matrix.isIdentity()) {
      super.paint(context, offset);
      return;
    }
    context.pushTransform(needsCompositing, offset, matrix,
        (context, offset) => super.paint(context, offset));
  }

  @override
  void dispose() {
    _scale.removeListener(_onChanged);
    super.dispose();
  }
}

/// Pinch-to-zoom gesture with animated spring snap-back.
///
/// Holds a single [MotionValue<double>] for the current scale, written
/// directly from `GestureDetector.onScaleUpdate` and read directly by a
/// [RenderProxyBox] during `paint` — pinching never triggers a widget
/// rebuild. The scale is always clamped to [minScale]/[maxScale].
class NibPinch extends StatefulWidget {
  /// Creates a pinch-to-zoom wrapper around [child].
  const NibPinch({
    super.key,
    required this.child,
    this.minScale = 0.5,
    this.maxScale = 4.0,
    this.initialScale = 1.0,
    this.snapBackOnRelease = false,
    this.onScaleChanged,
    this.spring = NibSpringDescription.gentle,
  });

  /// The widget to make pinchable.
  final Widget child;

  /// The smallest scale factor the gesture can reach.
  final double minScale;

  /// The largest scale factor the gesture can reach.
  final double maxScale;

  /// The scale [child] starts at, and the target [snapBackOnRelease] springs
  /// back to.
  final double initialScale;

  /// Whether to spring back to [initialScale] when the gesture ends.
  final bool snapBackOnRelease;

  /// Called with the current scale on every scale update.
  final ValueChanged<double>? onScaleChanged;

  /// The spring physics used to animate back to [initialScale] when
  /// [snapBackOnRelease] is `true`.
  final NibSpringDescription spring;

  @override
  State<NibPinch> createState() => _NibPinchState();
}

class _NibPinchState extends State<NibPinch>
    with TickerProviderStateMixin, NibReducedMotionMixin {
  late final MotionValue<double> _scale =
      MotionValue<double>(widget.initialScale);

  SpringSolver? _springSolver;
  double _scaleStart = 1.0;

  @override
  void didUpdateWidget(NibPinch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialScale != widget.initialScale &&
        _springSolver == null) {
      _scale.value = widget.initialScale;
    }
  }

  @override
  void dispose() {
    _springSolver?.dispose();
    super.dispose();
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _springSolver?.stop();
    _scaleStart = _scale.value;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final newScale =
        (_scaleStart * details.scale).clamp(widget.minScale, widget.maxScale);
    _scale.value = newScale;
    widget.onScaleChanged?.call(newScale);
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    if (!widget.snapBackOnRelease) return;

    if (reduceMotion) {
      _springSolver?.stop();
      _scale.value = widget.initialScale;
      return;
    }

    final solver = _springSolver ??=
        SpringSolver(vsync: this, value: _scale, spring: widget.spring);
    solver.spring = widget.spring;
    solver.animateTo(target: widget.initialScale);
  }

  @override
  Widget build(BuildContext context) {
    return _NibPinchBox(
      scale: _scale,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: _handleScaleStart,
        onScaleUpdate: _handleScaleUpdate,
        onScaleEnd: _handleScaleEnd,
        child: widget.child,
      ),
    );
  }
}

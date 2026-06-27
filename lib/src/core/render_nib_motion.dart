import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../values/motion_value.dart';
import '../values/motion_value_types.dart';

/// Paints a child with reactive transform, opacity, color, and clip
/// properties driven by [MotionValue]s.
///
/// Every property is read directly from its [MotionValue] during [paint].
/// When a [MotionValue] notifies, this render object calls
/// [markNeedsPaint] (and [markNeedsCompositingBitsUpdate] for [opacity])
/// — it never triggers a widget rebuild.
class RenderNibMotion extends RenderProxyBox {
  /// Creates a render object that paints [child] using the given
  /// [MotionValue]s.
  RenderNibMotion({
    required MotionValue<double> opacity,
    required MotionValue<double> translateX,
    required MotionValue<double> translateY,
    required MotionValue<double> scaleX,
    required MotionValue<double> scaleY,
    required MotionValue<double> rotate,
    required MotionValue<double> skewX,
    required MotionValue<double> skewY,
    required MotionValue<Color?> color,
    required MotionValue<BorderRadius?> borderRadius,
    required BoxShadowMotionValue boxShadow,
    RenderBox? child,
  })  : _opacity = opacity,
        _translateX = translateX,
        _translateY = translateY,
        _scaleX = scaleX,
        _scaleY = scaleY,
        _rotate = rotate,
        _skewX = skewX,
        _skewY = skewY,
        _color = color,
        _borderRadius = borderRadius,
        _boxShadow = boxShadow,
        super(child) {
    _opacity.addListener(_onOpacityChanged);
    _translateX.addListener(_onPaintValueChanged);
    _translateY.addListener(_onPaintValueChanged);
    _scaleX.addListener(_onPaintValueChanged);
    _scaleY.addListener(_onPaintValueChanged);
    _rotate.addListener(_onPaintValueChanged);
    _skewX.addListener(_onPaintValueChanged);
    _skewY.addListener(_onPaintValueChanged);
    _color.addListener(_onPaintValueChanged);
    _borderRadius.addListener(_onPaintValueChanged);
    _boxShadow.addListener(_onPaintValueChanged);
  }

  MotionValue<double> _opacity;
  MotionValue<double> _translateX;
  MotionValue<double> _translateY;
  MotionValue<double> _scaleX;
  MotionValue<double> _scaleY;
  MotionValue<double> _rotate;
  MotionValue<double> _skewX;
  MotionValue<double> _skewY;
  MotionValue<Color?> _color;
  MotionValue<BorderRadius?> _borderRadius;
  BoxShadowMotionValue _boxShadow;

  /// Opacity from `0.0` (fully transparent) to `1.0` (fully opaque).
  MotionValue<double> get opacity => _opacity;
  set opacity(MotionValue<double> value) {
    if (_opacity == value) return;
    _opacity.removeListener(_onOpacityChanged);
    _opacity = value;
    _opacity.addListener(_onOpacityChanged);
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  /// Horizontal translation, in logical pixels.
  MotionValue<double> get translateX => _translateX;
  set translateX(MotionValue<double> value) {
    if (_translateX == value) return;
    _translateX.removeListener(_onPaintValueChanged);
    _translateX = value;
    _translateX.addListener(_onPaintValueChanged);
    markNeedsPaint();
  }

  /// Vertical translation, in logical pixels.
  MotionValue<double> get translateY => _translateY;
  set translateY(MotionValue<double> value) {
    if (_translateY == value) return;
    _translateY.removeListener(_onPaintValueChanged);
    _translateY = value;
    _translateY.addListener(_onPaintValueChanged);
    markNeedsPaint();
  }

  /// Horizontal scale. Identity is `1.0`.
  MotionValue<double> get scaleX => _scaleX;
  set scaleX(MotionValue<double> value) {
    if (_scaleX == value) return;
    _scaleX.removeListener(_onPaintValueChanged);
    _scaleX = value;
    _scaleX.addListener(_onPaintValueChanged);
    markNeedsPaint();
  }

  /// Vertical scale. Identity is `1.0`.
  MotionValue<double> get scaleY => _scaleY;
  set scaleY(MotionValue<double> value) {
    if (_scaleY == value) return;
    _scaleY.removeListener(_onPaintValueChanged);
    _scaleY = value;
    _scaleY.addListener(_onPaintValueChanged);
    markNeedsPaint();
  }

  /// Rotation around the Z axis, in turns (`1.0` == 360°).
  MotionValue<double> get rotate => _rotate;
  set rotate(MotionValue<double> value) {
    if (_rotate == value) return;
    _rotate.removeListener(_onPaintValueChanged);
    _rotate = value;
    _rotate.addListener(_onPaintValueChanged);
    markNeedsPaint();
  }

  /// Horizontal shear, in radians.
  MotionValue<double> get skewX => _skewX;
  set skewX(MotionValue<double> value) {
    if (_skewX == value) return;
    _skewX.removeListener(_onPaintValueChanged);
    _skewX = value;
    _skewX.addListener(_onPaintValueChanged);
    markNeedsPaint();
  }

  /// Vertical shear, in radians.
  MotionValue<double> get skewY => _skewY;
  set skewY(MotionValue<double> value) {
    if (_skewY == value) return;
    _skewY.removeListener(_onPaintValueChanged);
    _skewY = value;
    _skewY.addListener(_onPaintValueChanged);
    markNeedsPaint();
  }

  /// Background color painted behind [child]. `null` paints nothing.
  MotionValue<Color?> get color => _color;
  set color(MotionValue<Color?> value) {
    if (_color == value) return;
    _color.removeListener(_onPaintValueChanged);
    _color = value;
    _color.addListener(_onPaintValueChanged);
    markNeedsPaint();
  }

  /// Clip radius applied to [child] and [color]. `null` applies no clip.
  MotionValue<BorderRadius?> get borderRadius => _borderRadius;
  set borderRadius(MotionValue<BorderRadius?> value) {
    if (_borderRadius == value) return;
    _borderRadius.removeListener(_onPaintValueChanged);
    _borderRadius = value;
    _borderRadius.addListener(_onPaintValueChanged);
    markNeedsPaint();
  }

  /// Shadows painted behind [color] and [child]. `null` or an empty list
  /// paints nothing.
  BoxShadowMotionValue get boxShadow => _boxShadow;
  set boxShadow(BoxShadowMotionValue value) {
    if (_boxShadow == value) return;
    _boxShadow.removeListener(_onPaintValueChanged);
    _boxShadow = value;
    _boxShadow.addListener(_onPaintValueChanged);
    markNeedsPaint();
  }

  void _onPaintValueChanged() => markNeedsPaint();

  void _onOpacityChanged() {
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  /// The transform matrix currently applied to [child], built from
  /// [translateX], [translateY], [rotate], [scaleX], [scaleY], [skewX], and
  /// [skewY] around the center of this render object.
  Matrix4 get transform {
    final center = size.center(Offset.zero);
    return Matrix4.translationValues(_translateX.value, _translateY.value, 0.0)
      ..multiply(Matrix4.translationValues(center.dx, center.dy, 0.0))
      ..multiply(Matrix4.rotationZ(_rotate.value * 2 * math.pi))
      ..multiply(Matrix4.diagonal3Values(_scaleX.value, _scaleY.value, 1.0))
      ..multiply(_skewMatrix(_skewX.value, _skewY.value))
      ..multiply(Matrix4.translationValues(-center.dx, -center.dy, 0.0));
  }

  Matrix4 _skewMatrix(double skewX, double skewY) {
    return Matrix4.identity()
      ..setEntry(0, 1, math.tan(skewX))
      ..setEntry(1, 0, math.tan(skewY));
  }

  @override
  bool get alwaysNeedsCompositing => _opacity.value < 1.0;

  @override
  void paint(PaintingContext context, Offset offset) {
    final opacityValue = _opacity.value;
    if (opacityValue <= 0.0) return;

    if (opacityValue < 1.0) {
      context.pushOpacity(offset, (opacityValue * 255).round(), _paintContents);
    } else {
      _paintContents(context, offset);
    }
  }

  void _paintContents(PaintingContext context, Offset offset) {
    final matrix = transform;
    if (matrix.isIdentity()) {
      _paintBoxAndChild(context, offset);
    } else {
      context.pushTransform(
          needsCompositing, offset, matrix, _paintBoxAndChild);
    }
  }

  void _paintBoxAndChild(PaintingContext context, Offset offset) {
    final rect = offset & size;
    final color = _color.value;
    final radius = _borderRadius.value;
    final shadows = _boxShadow.value;

    if (shadows != null) {
      for (final shadow in shadows) {
        final shadowRect =
            rect.shift(shadow.offset).inflate(shadow.spreadRadius);
        final shadowRRect = radius != null
            ? radius.toRRect(shadowRect)
            : RRect.fromRectAndRadius(shadowRect, Radius.zero);
        context.canvas.drawRRect(shadowRRect, shadow.toPaint());
      }
    }

    if (color != null && color.a != 0) {
      final paint = Paint()..color = color;
      if (radius != null) {
        context.canvas.drawRRect(radius.toRRect(rect), paint);
      } else {
        context.canvas.drawRect(rect, paint);
      }
    }

    if (radius != null) {
      // `pushClipRRect` shifts both `bounds` and `clipRRect` by `offset`
      // itself, so they must be passed in local coordinates (relative to
      // this render object's own top-left) — not the already-offset `rect`
      // used above for direct canvas drawing. Passing `rect` here would
      // double-apply `offset`, moving the clip away from where `_paintChild`
      // actually paints and clipping the child out entirely whenever
      // `offset` is non-zero.
      final localRect = Offset.zero & size;
      context.pushClipRRect(needsCompositing, offset, localRect,
          radius.toRRect(localRect), _paintChild);
    } else {
      _paintChild(context, offset);
    }
  }

  void _paintChild(PaintingContext context, Offset offset) {
    if (child != null) super.paint(context, offset);
  }

  @override
  void dispose() {
    _opacity.removeListener(_onOpacityChanged);
    _translateX.removeListener(_onPaintValueChanged);
    _translateY.removeListener(_onPaintValueChanged);
    _scaleX.removeListener(_onPaintValueChanged);
    _scaleY.removeListener(_onPaintValueChanged);
    _rotate.removeListener(_onPaintValueChanged);
    _skewX.removeListener(_onPaintValueChanged);
    _skewY.removeListener(_onPaintValueChanged);
    _color.removeListener(_onPaintValueChanged);
    _borderRadius.removeListener(_onPaintValueChanged);
    _boxShadow.removeListener(_onPaintValueChanged);
    super.dispose();
  }
}

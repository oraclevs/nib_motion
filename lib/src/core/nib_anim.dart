import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// An immutable snapshot of every visual property `NibMotion` can animate.
///
/// Each property is nullable: `null` means "this animation does not touch
/// this property" rather than "set this property to zero/identity". During
/// [lerp], a `null` value on one side falls back to the corresponding
/// [identity] value so animations only affect the properties the caller
/// actually specifies.
@immutable
class NibAnim {
  /// Creates an animation snapshot. Any omitted property is left untouched
  /// by this animation.
  const NibAnim({
    this.x,
    this.y,
    this.scale,
    this.scaleX,
    this.scaleY,
    this.rotate,
    this.skewX,
    this.skewY,
    this.opacity,
    this.color,
    this.borderRadius,
    this.boxShadow,
  });

  /// Horizontal offset from the widget's natural position, in pixels.
  final double? x;

  /// Vertical offset from the widget's natural position, in pixels.
  final double? y;

  /// Uniform scale applied to both axes. Identity is `1.0`.
  final double? scale;

  /// Horizontal scale. Identity is `1.0`.
  final double? scaleX;

  /// Vertical scale. Identity is `1.0`.
  final double? scaleY;

  /// Rotation around the Z axis, in turns (`1.0` == 360°).
  final double? rotate;

  /// Horizontal shear, in radians.
  final double? skewX;

  /// Vertical shear, in radians.
  final double? skewY;

  /// Opacity from `0.0` (fully transparent) to `1.0` (fully opaque,
  /// identity).
  final double? opacity;

  /// Background color painted behind the child. `null` means transparent.
  final Color? color;

  /// Clip radius applied to the widget and its [color]/[boxShadow].
  final BorderRadius? borderRadius;

  /// Shadows painted behind the widget.
  final List<BoxShadow>? boxShadow;

  /// The identity animation: every transform/opacity property at the value
  /// that produces no visual change, with no color, border radius, or
  /// shadow.
  static const NibAnim identity = NibAnim(
    x: 0.0,
    y: 0.0,
    scale: 1.0,
    scaleX: 1.0,
    scaleY: 1.0,
    rotate: 0.0,
    skewX: 0.0,
    skewY: 0.0,
    opacity: 1.0,
  );

  /// Interpolates between this animation and [other] at position [t]
  /// (`0.0` = this, `1.0` = [other]).
  ///
  /// For each scalar property: if both sides are `null` the result is
  /// `null`; if only one side is set, the other side falls back to its
  /// [identity] value before interpolating. [color], [borderRadius], and
  /// [boxShadow] are interpolated with `Color.lerp`, `BorderRadius.lerp`,
  /// and `BoxShadow.lerpList`, which already handle `null` correctly.
  NibAnim lerp(NibAnim other, double t) {
    return NibAnim(
      x: _lerpProp(x, other.x, identity.x!, t),
      y: _lerpProp(y, other.y, identity.y!, t),
      scale: _lerpProp(scale, other.scale, identity.scale!, t),
      scaleX: _lerpProp(scaleX, other.scaleX, identity.scaleX!, t),
      scaleY: _lerpProp(scaleY, other.scaleY, identity.scaleY!, t),
      rotate: _lerpProp(rotate, other.rotate, identity.rotate!, t),
      skewX: _lerpProp(skewX, other.skewX, identity.skewX!, t),
      skewY: _lerpProp(skewY, other.skewY, identity.skewY!, t),
      opacity: _lerpProp(opacity, other.opacity, identity.opacity!, t),
      color: Color.lerp(color, other.color, t),
      borderRadius: BorderRadius.lerp(borderRadius, other.borderRadius, t),
      boxShadow: BoxShadow.lerpList(boxShadow, other.boxShadow, t),
    );
  }

  /// Returns a copy of this animation with the given properties replaced.
  ///
  /// Properties left as `null` keep their current value.
  NibAnim copyWith({
    double? x,
    double? y,
    double? scale,
    double? scaleX,
    double? scaleY,
    double? rotate,
    double? skewX,
    double? skewY,
    double? opacity,
    Color? color,
    BorderRadius? borderRadius,
    List<BoxShadow>? boxShadow,
  }) {
    return NibAnim(
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      rotate: rotate ?? this.rotate,
      skewX: skewX ?? this.skewX,
      skewY: skewY ?? this.skewY,
      opacity: opacity ?? this.opacity,
      color: color ?? this.color,
      borderRadius: borderRadius ?? this.borderRadius,
      boxShadow: boxShadow ?? this.boxShadow,
    );
  }

  /// Returns a copy of this animation with every non-null property of
  /// [other] overriding the corresponding property of this animation.
  ///
  /// Used by the Variants system to cascade a child's variant state over
  /// its parent's.
  NibAnim merge(NibAnim other) {
    return NibAnim(
      x: other.x ?? x,
      y: other.y ?? y,
      scale: other.scale ?? scale,
      scaleX: other.scaleX ?? scaleX,
      scaleY: other.scaleY ?? scaleY,
      rotate: other.rotate ?? rotate,
      skewX: other.skewX ?? skewX,
      skewY: other.skewY ?? skewY,
      opacity: other.opacity ?? opacity,
      color: other.color ?? color,
      borderRadius: other.borderRadius ?? borderRadius,
      boxShadow: other.boxShadow ?? boxShadow,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NibAnim &&
        other.x == x &&
        other.y == y &&
        other.scale == scale &&
        other.scaleX == scaleX &&
        other.scaleY == scaleY &&
        other.rotate == rotate &&
        other.skewX == skewX &&
        other.skewY == skewY &&
        other.opacity == opacity &&
        other.color == color &&
        other.borderRadius == borderRadius &&
        listEquals(other.boxShadow, boxShadow);
  }

  @override
  int get hashCode => Object.hash(
        x,
        y,
        scale,
        scaleX,
        scaleY,
        rotate,
        skewX,
        skewY,
        opacity,
        color,
        borderRadius,
        boxShadow == null ? null : Object.hashAll(boxShadow!),
      );
}

double? _lerpProp(double? begin, double? end, double identityValue, double t) {
  if (begin == null && end == null) return null;
  final from = begin ?? identityValue;
  final to = end ?? identityValue;
  return from + (to - from) * t;
}

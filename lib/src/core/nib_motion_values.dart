import 'package:flutter/widgets.dart';

import '../values/motion_value.dart';
import '../values/motion_value_types.dart';

/// Pre-built [MotionValue]s to drive a [NibMotion]'s animatable properties
/// directly, bypassing its internal spring/tween animation system.
///
/// Any property left `null` continues to be driven by [NibMotion] as usual
/// (via [NibMotion.initial], [NibMotion.animate], etc.). A non-null property
/// is used as-is: [NibMotion] reads from it but never animates or disposes
/// it, so the caller remains responsible for updating and disposing it.
///
/// This is the mechanism [NibScrollMotion] uses to tie a [ScrollMotionBridge]
/// directly to a widget's appearance:
///
/// ```dart
/// NibMotion(
///   motionValues: NibMotionValues(
///     opacity: bridge.scrollY.mapRange([0, 200], [1.0, 0.0]),
///   ),
///   child: MyWidget(),
/// )
/// ```
@immutable
class NibMotionValues {
  /// Creates a `NibMotionValues`. Every field defaults to `null`, meaning
  /// "let [NibMotion] manage this property as usual".
  const NibMotionValues({
    this.opacity,
    this.translateX,
    this.translateY,
    this.scaleX,
    this.scaleY,
    this.rotate,
    this.skewX,
    this.skewY,
    this.color,
    this.borderRadius,
    this.boxShadow,
  });

  /// Drives `RenderNibMotion.opacity` directly when non-null.
  final MotionValue<double>? opacity;

  /// Drives `RenderNibMotion.translateX` directly when non-null.
  final MotionValue<double>? translateX;

  /// Drives `RenderNibMotion.translateY` directly when non-null.
  final MotionValue<double>? translateY;

  /// Drives `RenderNibMotion.scaleX` directly when non-null.
  final MotionValue<double>? scaleX;

  /// Drives `RenderNibMotion.scaleY` directly when non-null.
  final MotionValue<double>? scaleY;

  /// Drives `RenderNibMotion.rotate` directly when non-null.
  final MotionValue<double>? rotate;

  /// Drives `RenderNibMotion.skewX` directly when non-null.
  final MotionValue<double>? skewX;

  /// Drives `RenderNibMotion.skewY` directly when non-null.
  final MotionValue<double>? skewY;

  /// Drives `RenderNibMotion.color` directly when non-null.
  final MotionValue<Color?>? color;

  /// Drives `RenderNibMotion.borderRadius` directly when non-null.
  final MotionValue<BorderRadius?>? borderRadius;

  /// Drives `RenderNibMotion.boxShadow` directly when non-null.
  final BoxShadowMotionValue? boxShadow;
}

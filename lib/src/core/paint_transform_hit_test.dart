import 'package:flutter/rendering.dart';

/// Keeps coordinate-space queries in sync with a paint-time transform.
///
/// A render object that paints its child through `pushTransform` (as the
/// animated boxes in this package do, to avoid re-layout) must also report
/// that transform through `applyPaintTransform` and map hit-test positions
/// through it. Otherwise `localToGlobal`, FLIP measurement and taps all see
/// the *layout* position rather than where the box is painted, and a moved
/// widget cannot be tapped or grabbed where it appears.
mixin PaintTransformHitTest on RenderBox {
  /// The transform [paint] applies to the child, in this box's local space.
  Matrix4 get paintMatrix;

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    transform.multiply(paintMatrix);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // The default rejects positions outside the *layout* box, which would
    // make a translated/scaled box untouchable where it is painted.
    final matrix = paintMatrix;
    if (matrix.isIdentity()) return super.hitTest(result, position: position);
    return result.addWithPaintTransform(
      transform: matrix,
      position: position,
      hitTest: (BoxHitTestResult result, Offset transformed) {
        if (!size.contains(transformed)) return false;
        if (hitTestChildren(result, position: transformed) ||
            hitTestSelf(transformed)) {
          result.add(BoxHitTestEntry(this, transformed));
          return true;
        }
        return false;
      },
    );
  }
}

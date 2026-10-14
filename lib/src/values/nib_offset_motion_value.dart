import 'package:flutter/painting.dart';

import 'derived_motion_value.dart';
import 'motion_value.dart';

/// A [MotionValue<Offset>] that also exposes its axes as scalar
/// [MotionValue]s ([x] and [y]).
///
/// Give one to `NibMotionValues.offset` and the `NibMotion` uses [x]/[y]
/// directly as its translate channels — paint-only, with no extra derived
/// nodes. It is also the natural target for a `MultiSpringSolver<Offset>` or a
/// drag handler that produces an [Offset].
///
/// [x] and [y] are derived from this value: write to the offset, not to them.
/// Disposing this value disposes [x] and [y].
class NibOffsetMotionValue extends MotionValue<Offset> {
  /// Creates an offset value starting at [initial].
  NibOffsetMotionValue([super.initial = Offset.zero]) {
    x = DerivedMotionValue<Offset, double>(this, (o) => o.dx);
    y = DerivedMotionValue<Offset, double>(this, (o) => o.dy);
  }

  /// The horizontal component, updated whenever this value changes.
  late final DerivedMotionValue<Offset, double> x;

  /// The vertical component, updated whenever this value changes.
  late final DerivedMotionValue<Offset, double> y;

  @override
  void dispose() {
    x.dispose();
    y.dispose();
    super.dispose();
  }
}

import 'package:flutter/widgets.dart';

import '../values/motion_value.dart';

/// Mirrors a [ScrollController]'s scroll offset into [MotionValue]s so it
/// can drive animations directly, with no [AnimationController] involved.
///
/// [scrollY] and [scrollX] both track [ScrollController.offset] — use
/// whichever matches the axis of the scroll view [controller] is attached
/// to. From either, derive any animatable value with
/// [MotionValueMapRange.mapRange]:
///
/// ```dart
/// final opacity = bridge.scrollY.mapRange([0, 200], [1.0, 0.0]);
/// ```
///
/// Call [dispose] when this bridge is no longer needed to remove its
/// listener from [controller] and dispose [scrollY] and [scrollX].
class ScrollMotionBridge {
  /// Creates a `ScrollMotionBridge` that mirrors [controller]'s current and
  /// future scroll offset into [scrollY] and [scrollX].
  ScrollMotionBridge({required this.controller}) {
    final initial = controller.hasClients ? controller.offset : 0.0;
    scrollY = MotionValue(initial);
    scrollX = MotionValue(initial);
    controller.addListener(_onScroll);
  }

  /// The scroll controller whose offset is mirrored into [scrollY] and
  /// [scrollX].
  final ScrollController controller;

  /// Tracks [ScrollController.offset]. Use this for vertically-scrolling
  /// scroll views.
  late final MotionValue<double> scrollY;

  /// Tracks [ScrollController.offset]. Use this for horizontally-scrolling
  /// scroll views.
  late final MotionValue<double> scrollX;

  void _onScroll() {
    final offset = controller.offset;
    scrollY.value = offset;
    scrollX.value = offset;
  }

  /// Removes this bridge's listener from [controller] and disposes
  /// [scrollY] and [scrollX].
  void dispose() {
    controller.removeListener(_onScroll);
    scrollY.dispose();
    scrollX.dispose();
  }
}

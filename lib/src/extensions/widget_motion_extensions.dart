import 'package:flutter/widgets.dart';

import '../core/nib_anim.dart';
import '../core/nib_motion_widget.dart';
import '../core/nib_transition.dart';
import '../presets/nib_anim_presets.dart';
import '../scroll/nib_scroll_reveal.dart';
import '../shaders/nib_shimmer.dart';

/// Shorthand methods for wrapping a [Widget] in common `nib_motion`
/// primitives.
extension NibMotionWidgetExtension on Widget {
  /// Wraps this widget in a [NibMotion].
  Widget animate({
    Object? initial,
    Object? animate,
    NibAnim? exit,
    NibTransition? transition,
    NibAnim? whileTap,
    NibAnim? whileHover,
    Key? key,
  }) {
    return NibMotion(
      key: key,
      initial: initial,
      animate: animate,
      exit: exit,
      transition: transition,
      whileTap: whileTap,
      whileHover: whileHover,
      child: this,
    );
  }

  /// Wraps this widget in a [NibShimmer].
  Widget shimmer({bool enabled = true}) => NibShimmer(enabled: enabled, child: this);

  /// Wraps this widget in a [NibScrollReveal].
  Widget revealOnScroll({NibAnim? initial, bool once = true}) =>
      NibScrollReveal(initial: initial ?? NibAnimPresets.fadeUp, once: once, child: this);
}

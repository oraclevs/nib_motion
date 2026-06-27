import 'package:flutter/widgets.dart';

import '../core/nib_anim.dart';
import 'nib_nav_transition.dart';

/// Resolves the enter/exit [NibAnim] pair played by `NibScreenStack` for each
/// [NibNavTransitionType].
abstract class NibNavTransitions {
  /// Returns the `(enterFrom, exitTo)` [NibAnim] pair for [type], given the
  /// index-change [direction] (`1` = forward/higher index, `-1` = backward)
  /// and the [screenSize] of the transitioning screens.
  ///
  /// `enterFrom` is the state the incoming screen animates from (toward
  /// [NibAnim.identity]); `exitTo` is the state the outgoing screen animates
  /// to (from [NibAnim.identity]).
  static (NibAnim enterFrom, NibAnim exitTo) resolve(
    NibNavTransitionType type,
    int direction,
    Size screenSize,
  ) {
    switch (type) {
      case NibNavTransitionType.slideHorizontal:
        return (
          NibAnim(x: direction * screenSize.width, opacity: 1.0),
          NibAnim(x: -direction * screenSize.width * 0.25, opacity: 0.0),
        );
      case NibNavTransitionType.slideVertical:
        return (
          NibAnim(y: direction * screenSize.height),
          NibAnim(y: -direction * screenSize.height * 0.25, opacity: 0.0),
        );
      case NibNavTransitionType.fade:
        return (const NibAnim(opacity: 0), const NibAnim(opacity: 0));
      case NibNavTransitionType.scale:
        return (
          const NibAnim(opacity: 0, scale: 0.9),
          const NibAnim(opacity: 0, scale: 1.06),
        );
      case NibNavTransitionType.sharedAxis:
        // Shared axis: slide + fade simultaneously. Intentionally a fixed
        // 30px regardless of screen size — enough to imply direction without
        // a full-screen slide, matching Material Design's shared axis spec.
        return (
          NibAnim(x: direction * 30, opacity: 0),
          NibAnim(x: -direction * 30, opacity: 0),
        );
      case NibNavTransitionType.none:
        return (NibAnim.identity, NibAnim.identity);
    }
  }
}

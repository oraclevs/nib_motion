import 'package:flutter/widgets.dart';

import '../core/nib_anim.dart';
import '../core/nib_motion_controller.dart';
import '../core/nib_motion_widget.dart';
import '../core/nib_transition.dart';
import '../presence/nib_presence.dart';
import '../variants/nib_variants.dart';

/// Which end of [NibMotionList.children] animates first.
enum NibStaggerDirection {
  /// The first child (index `0`) animates first.
  forward,

  /// The last child animates first.
  reverse,
}

/// Wraps [children] in [NibMotion], staggering each child's animation start
/// by [staggerDelay] multiplied by its position (per [staggerDirection]).
///
/// `initial`, `animate`, `exit`, `variants`, `transition`, and `controller`
/// are forwarded to every child's [NibMotion] unchanged, except that each
/// child's [NibTransition.delay] is offset by its stagger delay.
///
/// If [presenceEnabled] is `true`, [children] are wrapped in [NibPresence] so
/// a child removed from [children] plays its [exit] animation before being
/// removed from the tree; every widget in [children] must then carry a
/// non-null, unique [Key]. Otherwise, the wrapped children are laid out in a
/// [Column].
class NibMotionList extends StatelessWidget {
  /// Creates a `NibMotionList`.
  const NibMotionList({
    super.key,
    required this.children,
    this.initial,
    this.animate,
    this.exit,
    this.variants,
    this.staggerDelay = const Duration(milliseconds: 50),
    this.staggerDirection = NibStaggerDirection.forward,
    this.transition,
    this.controller,
    this.presenceEnabled = false,
  })  : assert(
          initial == null || initial is String || initial is NibAnim,
          'NibMotionList.initial must be a String variant name or a NibAnim.',
        ),
        assert(
          animate == null || animate is String || animate is NibAnim,
          'NibMotionList.animate must be a String variant name or a NibAnim.',
        );

  /// The widgets to animate. If [presenceEnabled] is `true`, each must carry
  /// a non-null, unique [Key] (see [NibPresence]).
  final List<Widget> children;

  /// Forwarded to every child's `NibMotion.initial`.
  ///
  /// Either a [NibAnim] or a [String] naming an entry in [variants].
  final Object? initial;

  /// Forwarded to every child's `NibMotion.animate`.
  ///
  /// Either a [NibAnim] or a [String] naming an entry in [variants].
  final Object? animate;

  /// Forwarded to every child's `NibMotion.exit`, played when
  /// [presenceEnabled] is `true` and that child is removed from [children].
  final NibAnim? exit;

  /// Forwarded to every child's `NibMotion.variants`, for resolving
  /// [initial] and [animate] when they are variant-name [String]s.
  final NibVariants? variants;

  /// Extra delay applied per child, multiplied by its position in
  /// [staggerDirection] order, on top of [transition]'s own
  /// [NibTransition.delay].
  final Duration staggerDelay;

  /// Which end of [children] animates first.
  final NibStaggerDirection staggerDirection;

  /// The transition used for each child's [animate].
  ///
  /// If `null`, falls back to [NibMotion]'s own default. The per-child
  /// stagger offset is added to [NibTransition.delay].
  final NibTransition? transition;

  /// Forwarded to every child's `NibMotion.controller`, so a single
  /// controller drives every child.
  final NibMotionController? controller;

  /// Whether a child removed from [children] plays its [exit] animation via
  /// [NibPresence] before being removed from the tree.
  final bool presenceEnabled;

  @override
  Widget build(BuildContext context) {
    final baseTransition = transition ?? const NibTransition();
    final count = children.length;

    final wrapped = <Widget>[
      for (var index = 0; index < count; index++)
        _wrapChild(index, count, baseTransition),
    ];

    if (presenceEnabled) {
      return NibPresence(children: wrapped);
    }

    return Column(mainAxisSize: MainAxisSize.min, children: wrapped);
  }

  Widget _wrapChild(int index, int count, NibTransition baseTransition) {
    final child = children[index];
    final staggerIndex = staggerDirection == NibStaggerDirection.forward
        ? index
        : count - 1 - index;

    return NibMotion(
      key: child.key,
      initial: initial,
      animate: animate,
      exit: exit,
      variants: variants,
      controller: controller,
      transition: NibTransition(
        duration: baseTransition.duration,
        curve: baseTransition.curve,
        delay: baseTransition.delay + staggerDelay * staggerIndex,
        spring: baseTransition.spring,
        delayChildren: baseTransition.delayChildren,
        staggerChildren: baseTransition.staggerChildren,
      ),
      child: child,
    );
  }
}

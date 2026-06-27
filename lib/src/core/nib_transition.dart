import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import '../physics/spring_description.dart';

/// Whether a [NibTransition] is driven by curve-based tweening or by spring
/// physics.
enum NibTransitionType {
  /// Animated over a fixed [NibTransition.duration] using
  /// [NibTransition.curve].
  tween,

  /// Animated by [NibTransition.spring] via [SpringSolver]. The
  /// [NibTransition.duration] and [NibTransition.curve] are ignored.
  spring,
}

/// Describes how a [NibMotion] animation should run: either a curve-based
/// tween with a fixed [duration], or real spring physics via [spring].
@immutable
class NibTransition {
  /// Creates a transition.
  ///
  /// If [spring] is provided, the transition runs as
  /// [NibTransitionType.spring] and [duration]/[curve] are ignored.
  /// Otherwise it runs as [NibTransitionType.tween] using [duration] and
  /// [curve].
  const NibTransition({
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
    this.delay = Duration.zero,
    this.spring,
    this.staggerChildren = Duration.zero,
    this.delayChildren = Duration.zero,
  });

  /// A gentle spring transition (see [NibSpringDescription.gentle]).
  static const NibTransition springGentle = NibTransition(
    spring: NibSpringDescription.gentle,
  );

  /// A snappy spring transition (see [NibSpringDescription.snappy]).
  static const NibTransition springSnappy = NibTransition(
    spring: NibSpringDescription.snappy,
  );

  /// A wobbly spring transition (see [NibSpringDescription.wobbly]).
  static const NibTransition springWobbly = NibTransition(
    spring: NibSpringDescription.wobbly,
  );

  /// How long a [NibTransitionType.tween] animation takes. Ignored for
  /// [NibTransitionType.spring].
  final Duration duration;

  /// The easing curve for a [NibTransitionType.tween] animation. Ignored for
  /// [NibTransitionType.spring].
  final Curve curve;

  /// How long to wait before starting the animation.
  final Duration delay;

  /// The spring physics to use. If non-null, [type] is
  /// [NibTransitionType.spring] and [duration]/[curve] are ignored.
  final NibSpringDescription? spring;

  /// Extra delay before the first descendant `NibMotion` that resolves its
  /// `animate` from this widget's propagated variant starts animating.
  final Duration delayChildren;

  /// Extra delay applied per descendant index (in build order) on top of
  /// [delayChildren], for staggering descendants that resolve their `animate`
  /// from this widget's propagated variant.
  final Duration staggerChildren;

  /// Whether this transition is driven by [spring] physics or by
  /// [duration]/[curve] tweening.
  NibTransitionType get type =>
      spring != null ? NibTransitionType.spring : NibTransitionType.tween;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NibTransition &&
        other.duration == duration &&
        other.curve == curve &&
        other.delay == delay &&
        other.spring == spring &&
        other.delayChildren == delayChildren &&
        other.staggerChildren == staggerChildren;
  }

  @override
  int get hashCode => Object.hash(
      duration, curve, delay, spring, delayChildren, staggerChildren);
}

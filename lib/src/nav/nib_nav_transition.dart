import 'package:flutter/foundation.dart';

import '../core/nib_transition.dart';
import '../physics/spring_description.dart';

/// The style of screen transition played by `NibScreenStack` when the active
/// tab changes.
enum NibNavTransitionType {
  /// Cross-fade between screens.
  fade,

  /// Slide left/right based on the index change direction.
  slideHorizontal,

  /// Slide up/down based on the index change direction.
  slideVertical,

  /// Scale + fade (zoom).
  scale,

  /// Material-style shared axis (slide + fade).
  sharedAxis,

  /// Instant switch with no animation.
  none,
}

/// Configures the screen transition played by `NibScreenStack` when the
/// active tab changes.
@immutable
class NibNavScreenTransition {
  /// Creates a screen transition configuration.
  ///
  /// If [tween] is non-null, it overrides [spring] and the transition runs
  /// as a curve-based tween instead of spring physics.
  const NibNavScreenTransition({
    this.type = NibNavTransitionType.fade,
    this.spring = NibSpringDescription.gentle,
    this.tween,
    this.retriggerPageAnimations = false,
    this.retriggerDelay = Duration.zero,
  });

  /// No screen transition; tab switches are instant.
  static const NibNavScreenTransition none = NibNavScreenTransition(
    type: NibNavTransitionType.none,
  );

  /// Slide screens horizontally based on index change direction.
  static const NibNavScreenTransition slide = NibNavScreenTransition(
    type: NibNavTransitionType.slideHorizontal,
  );

  /// Cross-fade between screens.
  static const NibNavScreenTransition fade = NibNavScreenTransition(
    type: NibNavTransitionType.fade,
  );

  /// The style of transition to play.
  final NibNavTransitionType type;

  /// The spring physics used to animate the transition, when [tween] is
  /// null.
  final NibSpringDescription spring;

  /// If non-null, overrides [spring] with a curve-based tween.
  final NibTransition? tween;

  /// If `true`, once the incoming screen's enter transition finishes, every
  /// [NibMotion] within it that has an `animate`/`keyframes` entrance
  /// animation replays that animation from scratch.
  ///
  /// Defaults to `false` — existing entrance animations are not replayed on
  /// tab switches unless a consumer opts in.
  final bool retriggerPageAnimations;

  /// If [retriggerPageAnimations] is `true`, how long to wait — after the
  /// incoming screen's enter transition finishes — before replaying its
  /// entrance animations.
  ///
  /// Defaults to [Duration.zero] (replay immediately once the transition
  /// finishes).
  final Duration retriggerDelay;

  /// Returns a copy of this configuration with the given fields replaced.
  NibNavScreenTransition copyWith({
    NibNavTransitionType? type,
    NibSpringDescription? spring,
    NibTransition? tween,
    bool? retriggerPageAnimations,
    Duration? retriggerDelay,
  }) {
    return NibNavScreenTransition(
      type: type ?? this.type,
      spring: spring ?? this.spring,
      tween: tween ?? this.tween,
      retriggerPageAnimations:
          retriggerPageAnimations ?? this.retriggerPageAnimations,
      retriggerDelay: retriggerDelay ?? this.retriggerDelay,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NibNavScreenTransition &&
        other.type == type &&
        other.spring == spring &&
        other.tween == tween &&
        other.retriggerPageAnimations == retriggerPageAnimations &&
        other.retriggerDelay == retriggerDelay;
  }

  @override
  int get hashCode =>
      Object.hash(type, spring, tween, retriggerPageAnimations, retriggerDelay);
}

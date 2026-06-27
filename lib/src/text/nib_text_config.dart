import 'package:flutter/foundation.dart';

import '../core/nib_anim.dart';
import '../core/nib_transition.dart';

/// The granularity at which [NibText] splits its text into animated units.
enum NibTextUnit {
  /// Each grapheme cluster (user-perceived character, including multi-code-unit
  /// emoji) is its own animated unit.
  character,

  /// Each whitespace-delimited word is its own animated unit. Runs of
  /// whitespace between words are preserved as plain (non-animated) text.
  word,

  /// Each line (split on `\n`) is its own animated unit.
  line,
}

/// Where the per-unit stagger delay accumulates from, when [NibText] computes
/// each unit's entrance delay.
enum NibTextStaggerFrom {
  /// Delay increases from the first unit to the last: `index * staggerDelay`.
  start,

  /// Delay increases from the last unit to the first:
  /// `(totalUnits - 1 - index) * staggerDelay`.
  end,

  /// Delay increases outward from the middle unit toward both ends.
  center,

  /// Delay is a seeded-random value in `[0, totalUnits * staggerDelay)`, so
  /// units animate in over the same overall window but in a shuffled order.
  random,
}

/// Configures how [NibText] splits and animates its text.
///
/// Each unit (character, word, or line — see [unit]) is wrapped in its own
/// `NibMotion` using [initial] as its starting state, [animate] as its target
/// state, and [exit] as its `NibPresence` exit state, staggered according to
/// [staggerDelay] and [staggerFrom].
@immutable
class NibTextConfig {
  /// Creates a text animation configuration.
  const NibTextConfig({
    this.unit = NibTextUnit.character,
    this.initial,
    this.animate,
    this.exit,
    this.staggerDelay = const Duration(milliseconds: 30),
    this.staggerFrom = NibTextStaggerFrom.start,
    this.transition,
  });

  /// Whether to animate per-character, per-word, or per-line.
  final NibTextUnit unit;

  /// The starting state of each unit before its entrance. Defaults to
  /// [NibAnim.identity] when `null`.
  final NibAnim? initial;

  /// The target state of each unit at rest. When `null`, units render at
  /// [initial] with no entrance animation.
  final NibAnim? animate;

  /// The state each unit transitions to when the widget exits via an
  /// ancestor `NibPresence`.
  final NibAnim? exit;

  /// The delay between each successive unit's animation start.
  final Duration staggerDelay;

  /// Where stagger delay accumulates from — start, end, center, or random.
  final NibTextStaggerFrom staggerFrom;

  /// The transition used for each unit's entrance animation. Defaults to
  /// `NibTransition.springGentle` with a 400ms tween fallback when no spring
  /// is set.
  final NibTransition? transition;

  /// Returns a copy of this config with the given fields replaced.
  NibTextConfig copyWith({
    NibTextUnit? unit,
    NibAnim? initial,
    NibAnim? animate,
    NibAnim? exit,
    Duration? staggerDelay,
    NibTextStaggerFrom? staggerFrom,
    NibTransition? transition,
  }) {
    return NibTextConfig(
      unit: unit ?? this.unit,
      initial: initial ?? this.initial,
      animate: animate ?? this.animate,
      exit: exit ?? this.exit,
      staggerDelay: staggerDelay ?? this.staggerDelay,
      staggerFrom: staggerFrom ?? this.staggerFrom,
      transition: transition ?? this.transition,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NibTextConfig &&
        other.unit == unit &&
        other.initial == initial &&
        other.animate == animate &&
        other.exit == exit &&
        other.staggerDelay == staggerDelay &&
        other.staggerFrom == staggerFrom &&
        other.transition == transition;
  }

  @override
  int get hashCode =>
      Object.hash(unit, initial, animate, exit, staggerDelay, staggerFrom, transition);
}

import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart' as flutter_physics;

/// Describes the physical properties of a spring used to drive a
/// [MotionValue] toward a target via [SpringSolver].
///
/// This wraps `package:flutter/physics.dart`'s `SpringDescription` and adds a
/// set of named presets so callers can write `NibSpringDescription.gentle`
/// instead of constructing raw mass/stiffness/damping values.
@immutable
class NibSpringDescription {
  /// Creates a spring description.
  ///
  /// - [mass] affects inertia. Higher values are slower to start and stop.
  /// - [stiffness] is the spring tightness. Higher values are snappier.
  /// - [damping] is the resistance. Higher values reduce oscillation.
  ///
  /// [mass] and [stiffness] must be positive and finite, [damping] must be
  /// non-negative and finite (`0` is an undamped spring). Violations fail an
  /// assert in debug builds; in release builds [toFlutter] substitutes safe
  /// values so a bad description can never poison a `MotionValue` with NaN.
  const NibSpringDescription({
    this.mass = 1.0,
    this.stiffness = 100.0,
    this.damping = 10.0,
  })  : assert(mass > 0 && mass < double.infinity,
            'NibSpringDescription.mass must be positive and finite.'),
        assert(stiffness > 0 && stiffness < double.infinity,
            'NibSpringDescription.stiffness must be positive and finite.'),
        assert(damping >= 0 && damping < double.infinity,
            'NibSpringDescription.damping must be non-negative and finite.');

  /// Creates a description **without** validation.
  ///
  /// For tests and for code that has already validated its input; invalid
  /// values are replaced by safe defaults in [toFlutter].
  const NibSpringDescription.unchecked({
    this.mass = 1.0,
    this.stiffness = 100.0,
    this.damping = 10.0,
  });

  /// Creates a spring from how it should *feel* rather than raw physics.
  ///
  /// [duration] is the perceptual duration (roughly how long until the motion
  /// reads as settled) and [bounce] is in `-1.0..1.0`: `0` is critically
  /// damped (no overshoot), positive values overshoot and oscillate, negative
  /// values are overdamped and sluggish. Mass is fixed at `1`.
  ///
  /// ```dart
  /// NibSpringDescription.fromDuration(
  ///     duration: Duration(milliseconds: 450), bounce: 0.25)
  /// ```
  factory NibSpringDescription.fromDuration({
    Duration duration = const Duration(milliseconds: 500),
    double bounce = 0.0,
  }) {
    assert(duration > Duration.zero, 'duration must be positive');
    assert(bounce > -1.0 && bounce < 1.0, 'bounce must be in (-1, 1)');
    final spring = flutter_physics.SpringDescription.withDurationAndBounce(
      duration: duration,
      bounce: bounce,
    );
    return NibSpringDescription(
      mass: spring.mass,
      stiffness: spring.stiffness,
      damping: spring.damping,
    );
  }

  /// A soft, slow-settling spring with minimal overshoot.
  static const NibSpringDescription gentle = NibSpringDescription(
    mass: 1.0,
    stiffness: 120.0,
    damping: 14.0,
  );

  /// A tight, fast spring with very little overshoot.
  static const NibSpringDescription snappy = NibSpringDescription(
    mass: 1.0,
    stiffness: 300.0,
    damping: 20.0,
  );

  /// A loose spring that oscillates noticeably before settling.
  static const NibSpringDescription wobbly = NibSpringDescription(
    mass: 1.0,
    stiffness: 180.0,
    damping: 12.0,
  );

  /// A very tight, fast-settling spring with near-zero overshoot.
  static const NibSpringDescription stiff = NibSpringDescription(
    mass: 1.0,
    stiffness: 400.0,
    damping: 28.0,
  );

  /// The mass attached to the spring. Affects inertia.
  final double mass;

  /// The spring constant. Higher values produce a snappier motion.
  final double stiffness;

  /// The damping coefficient. Higher values reduce oscillation.
  final double damping;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NibSpringDescription &&
          other.mass == mass &&
          other.stiffness == stiffness &&
          other.damping == damping;

  @override
  int get hashCode => Object.hash(mass, stiffness, damping);

  /// Converts this description to a `package:flutter/physics.dart`
  /// `SpringDescription` for use with `SpringSimulation`.
  flutter_physics.SpringDescription toFlutter() {
    // Release-mode safety net (debug builds assert in the constructor).
    return flutter_physics.SpringDescription(
      mass: mass > 0 && mass < double.infinity ? mass : 1.0,
      stiffness:
          stiffness > 0 && stiffness < double.infinity ? stiffness : 100.0,
      damping: damping >= 0 && damping < double.infinity ? damping : 10.0,
    );
  }
}

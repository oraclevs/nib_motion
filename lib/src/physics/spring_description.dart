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
  const NibSpringDescription({
    this.mass = 1.0,
    this.stiffness = 100.0,
    this.damping = 10.0,
  });

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

  /// Converts this description to a `package:flutter/physics.dart`
  /// `SpringDescription` for use with `SpringSimulation`.
  flutter_physics.SpringDescription toFlutter() {
    return flutter_physics.SpringDescription(
      mass: mass,
      stiffness: stiffness,
      damping: damping,
    );
  }
}

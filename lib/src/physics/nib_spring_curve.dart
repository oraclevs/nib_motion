import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart' as flutter_physics;

import 'spring_description.dart';

/// A [Curve] that follows a spring's unit step response, so spring feel can be
/// used anywhere a curve is accepted — notably inside a time-parametrised
/// keyframe segment (`NibKeyframe.spring`).
///
/// The spring runs from `0` to `1` with zero initial velocity; its settling
/// time is stretched to exactly the curve's `0..1` domain, so the curve ends
/// on `1` (the final sliver of the tail is dropped) and overshoots above `1`
/// when the spring is underdamped.
class NibSpringCurve extends Curve {
  /// Creates a curve from [spring].
  NibSpringCurve(this.spring)
      : _simulation = flutter_physics.SpringSimulation(
          spring.toFlutter(),
          0.0,
          1.0,
          0.0,
        ),
        _settleSeconds = _settleTime(spring);

  /// The spring this curve samples.
  final NibSpringDescription spring;

  final flutter_physics.SpringSimulation _simulation;
  final double _settleSeconds;

  static final Map<NibSpringDescription, double> _settleCache =
      <NibSpringDescription, double>{};

  static double _settleTime(NibSpringDescription spring) {
    return _settleCache.putIfAbsent(spring, () {
      final simulation = flutter_physics.SpringSimulation(
        spring.toFlutter(),
        0.0,
        1.0,
        0.0,
      );
      // Step in 1/240 s; cap at 10 s for pathological (near-undamped) springs.
      var t = 0.0;
      while (t < 10.0 && !simulation.isDone(t)) {
        t += 1 / 240;
      }
      return t <= 0 ? 1 / 240 : t;
    });
  }

  @override
  double transformInternal(double t) => _simulation.x(t * _settleSeconds);
}

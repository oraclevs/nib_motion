import 'package:flutter/physics.dart' as fp;
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

/// Seconds until a 0→1 spring is done, and its peak position.
({double settle, double peak}) _profile(NibSpringDescription d) {
  final sim = fp.SpringSimulation(d.toFlutter(), 0, 1, 0);
  var peak = 0.0;
  for (var t = 0.0; t < 20; t += 0.001) {
    final x = sim.x(t);
    if (x > peak) peak = x;
    if (sim.isDone(t)) return (settle: t, peak: peak);
  }
  return (settle: 20, peak: peak);
}

void main() {
  group('NibSpringDescription.fromDuration', () {
    test('bounce 0 is critically damped: no overshoot', () {
      final d = NibSpringDescription.fromDuration(
          duration: const Duration(milliseconds: 400));
      expect(d.mass, 1);
      expect(_profile(d).peak, lessThanOrEqualTo(1.0001));
    });

    test('positive bounce overshoots, more bounce overshoots more', () {
      final a = _profile(NibSpringDescription.fromDuration(bounce: 0.2));
      final b = _profile(NibSpringDescription.fromDuration(bounce: 0.5));
      expect(a.peak, greaterThan(1.001));
      expect(b.peak, greaterThan(a.peak));
    });

    test('negative bounce is overdamped: no overshoot', () {
      final d = NibSpringDescription.fromDuration(bounce: -0.5);
      expect(_profile(d).peak, lessThanOrEqualTo(1.0001));
    });

    test('a shorter duration is stiffer', () {
      final fast = NibSpringDescription.fromDuration(
          duration: const Duration(milliseconds: 200));
      final slow = NibSpringDescription.fromDuration(
          duration: const Duration(milliseconds: 800));
      expect(fast.stiffness, greaterThan(slow.stiffness));
      expect(_profile(fast).settle, lessThan(_profile(slow).settle));
    });

    test('value equality', () {
      expect(NibSpringDescription.fromDuration(bounce: 0.2),
          NibSpringDescription.fromDuration(bounce: 0.2));
      expect(NibSpringDescription.gentle, isNot(NibSpringDescription.snappy));
    });

    test('rejects out-of-range bounce', () {
      expect(() => NibSpringDescription.fromDuration(bounce: 1.0),
          throwsAssertionError);
      expect(() => NibSpringDescription.fromDuration(duration: Duration.zero),
          throwsAssertionError);
    });
  });

  group('NibTransition.springWith', () {
    test('builds a spring transition with delay', () {
      final t = NibTransition.springWith(
          duration: const Duration(milliseconds: 300),
          bounce: 0.2,
          delay: const Duration(milliseconds: 40));
      expect(t.type, NibTransitionType.spring);
      expect(t.delay, const Duration(milliseconds: 40));
      expect(
          t.spring,
          NibSpringDescription.fromDuration(
              duration: const Duration(milliseconds: 300), bounce: 0.2));
    });
  });

  group('NibSpring tokens', () {
    test('within each family, fast settles before default before slow', () {
      expect(_profile(NibSpring.spatialFast).settle,
          lessThan(_profile(NibSpring.spatialDefault).settle));
      expect(_profile(NibSpring.spatialDefault).settle,
          lessThan(_profile(NibSpring.spatialSlow).settle));
      expect(_profile(NibSpring.effectsFast).settle,
          lessThan(_profile(NibSpring.effectsDefault).settle));
      expect(_profile(NibSpring.effectsDefault).settle,
          lessThan(_profile(NibSpring.effectsSlow).settle));
    });

    test('effects never overshoot; spatial may', () {
      for (final d in [
        NibSpring.effectsFast,
        NibSpring.effectsDefault,
        NibSpring.effectsSlow,
        NibSpring.interactive,
        NibSpring.smooth,
      ]) {
        expect(_profile(d).peak, lessThanOrEqualTo(1.0001));
      }
      for (final d in [
        NibSpring.spatialFast,
        NibSpring.spatialDefault,
        NibSpring.spatialSlow,
        NibSpring.snappy,
        NibSpring.bouncy,
      ]) {
        expect(_profile(d).peak, greaterThan(1.0001));
      }
    });

    test('bouncy overshoots more than snappy', () {
      expect(_profile(NibSpring.bouncy).peak,
          greaterThan(_profile(NibSpring.snappy).peak));
    });

    test('transition extension wraps the spring', () {
      expect(NibSpring.smooth.transition.spring, NibSpring.smooth);
    });
  });
}

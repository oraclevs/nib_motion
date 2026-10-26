import 'package:flutter/physics.dart' as flutter_physics;
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  group('NibSpringDescription', () {
    test('default constructor uses mass:1, stiffness:100, damping:10', () {
      const spring = NibSpringDescription();

      expect(spring.mass, 1.0);
      expect(spring.stiffness, 100.0);
      expect(spring.damping, 10.0);
    });

    test('named presets have the documented physics values', () {
      const gentle = NibSpringDescription.gentle;
      expect(gentle.mass, 1.0);
      expect(gentle.stiffness, 120.0);
      expect(gentle.damping, 14.0);

      const snappy = NibSpringDescription.snappy;
      expect(snappy.mass, 1.0);
      expect(snappy.stiffness, 300.0);
      expect(snappy.damping, 20.0);

      const wobbly = NibSpringDescription.wobbly;
      expect(wobbly.mass, 1.0);
      expect(wobbly.stiffness, 180.0);
      expect(wobbly.damping, 12.0);

      const stiff = NibSpringDescription.stiff;
      expect(stiff.mass, 1.0);
      expect(stiff.stiffness, 400.0);
      expect(stiff.damping, 28.0);
    });

    test('duration and bounce map to stable physical parameters', () {
      const duration = Duration(milliseconds: 500);
      final critical = NibSpringDescription.fromDuration(duration: duration);
      final bouncy =
          NibSpringDescription.fromDuration(duration: duration, bounce: 0.25);
      final overdamped =
          NibSpringDescription.fromDuration(duration: duration, bounce: -0.5);
      expect(critical.mass, 1.0);
      expect(critical.stiffness,
          closeTo(16 * 3.141592653589793 * 3.141592653589793, 1e-10));
      expect(critical.damping, closeTo(8 * 3.141592653589793, 1e-10));
      expect(bouncy.damping, closeTo(6 * 3.141592653589793, 1e-10));
      expect(overdamped.damping, closeTo(16 * 3.141592653589793, 1e-10));
    });

    test('toFlutter() converts to a matching flutter SpringDescription', () {
      const spring = NibSpringDescription.wobbly;

      final flutterSpring = spring.toFlutter();

      expect(flutterSpring, isA<flutter_physics.SpringDescription>());
      expect(flutterSpring.mass, spring.mass);
      expect(flutterSpring.stiffness, spring.stiffness);
      expect(flutterSpring.damping, spring.damping);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  group('MotionValue', () {
    test('value getter returns the initial value', () {
      final motion = MotionValue<double>(10.0);

      expect(motion.value, 10.0);
    });

    test('setting a new value notifies listeners', () {
      final motion = MotionValue<double>(0.0);
      var notifyCount = 0;
      motion.addListener(() => notifyCount++);

      motion.value = 5.0;

      expect(motion.value, 5.0);
      expect(notifyCount, 1);
    });

    test('setting the same value does not notify listeners again', () {
      final motion = MotionValue<double>(5.0);
      var notifyCount = 0;
      motion.addListener(() => notifyCount++);

      motion.value = 5.0;

      expect(notifyCount, 0);
    });
  });

  group('MotionValue.transform', () {
    test('derived value updates when source changes', () {
      final source = MotionValue<double>(2.0);
      final derived = source.transform((v) => v * 10);

      expect(derived.value, 20.0);

      source.value = 3.0;

      expect(derived.value, 30.0);
    });

    test('chained transform updates all the way through', () {
      final source = MotionValue<double>(1.0);
      final doubled = source.transform((v) => v * 2);
      final plusOne = doubled.transform((v) => v + 1);

      expect(plusOne.value, 3.0);

      source.value = 5.0;

      expect(plusOne.value, 11.0);
    });

    test('disposing a DerivedMotionValue removes its listener from the source', () {
      final source = MotionValue<double>(0.0);
      final derived = source.transform((v) => v * 2);

      expect(source.hasListeners, isTrue);

      derived.dispose();

      expect(source.hasListeners, isFalse);
    });

    test('disposing a source MotionValue does not throw on derived value', () {
      final source = MotionValue<double>(0.0);
      final derived = source.transform((v) => v * 2);

      expect(() => source.dispose(), returnsNormally);
      expect(() => derived.dispose(), returnsNormally);
    });
  });

  group('MotionValue.mapRange', () {
    test('mapRange([0,100],[0.0,1.0]) at input=50 gives output=0.5', () {
      final source = MotionValue<double>(50.0);
      final mapped = source.mapRange([0, 100], [0.0, 1.0]);

      expect(mapped.value, 0.5);
    });

    test('mapRange with 3 stops [0,100,200]->[0.0,1.0,0.0] at input=150 gives 0.5', () {
      final source = MotionValue<double>(150.0);
      final mapped = source.mapRange([0, 100, 200], [0.0, 1.0, 0.0]);

      expect(mapped.value, 0.5);
    });

    test('clamps to the output range ends when outside the input range', () {
      final source = MotionValue<double>(-50.0);
      final mapped = source.mapRange([0, 100], [0.0, 1.0]);

      expect(mapped.value, 0.0);

      source.value = 500.0;

      expect(mapped.value, 1.0);
    });

    test('mapRange result can itself be transformed (chained)', () {
      final source = MotionValue<double>(50.0);
      final squared = source.mapRange([0, 100], [0.0, 1.0]).transform((v) => v * v);

      expect(squared.value, 0.25);
    });
  });

  group('motionValue factory', () {
    test('creates a MotionValue with the given initial value', () {
      final mv = motionValue<double>(42.0);

      expect(mv, isA<MotionValue<double>>());
      expect(mv.value, 42.0);
    });
  });
}

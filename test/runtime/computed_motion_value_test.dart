import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  group('ComputedMotionValue', () {
    test('combines several sources', () {
      final a = MotionValue<double>(1);
      final b = MotionValue<double>(2);
      final sum = MotionValue.computed([a, b], () => a.value + b.value);
      expect(sum.value, 3);
      a.value = 10;
      expect(sum.value, 12);
      b.value = 5;
      expect(sum.value, 15);
    });

    test('is lazy: compute runs on read, not on dependency change', () {
      final a = MotionValue<double>(1);
      var runs = 0;
      final v = MotionValue.computed([a], () {
        runs++;
        return a.value * 2;
      });
      expect(runs, 1);
      a.value = 2;
      a.value = 3;
      a.value = 4;
      expect(runs, 1, reason: 'stale, nobody read it yet');
      expect(v.value, 8);
      expect(runs, 2);
      expect(v.value, 8);
      expect(runs, 2, reason: 'cached until a dependency changes again');
    });

    test('notifies listeners when a dependency changes', () {
      final a = MotionValue<double>(1);
      final v = MotionValue.computed([a], () => a.value);
      var notified = 0;
      v.addListener(() => notified++);
      a.value = 2;
      expect(notified, 1);
    });

    test('diamond graph is consistent once propagation has finished', () {
      final a = MotionValue<double>(1);
      final b = a.transform<double>((x) => x + 1);
      final c = a.transform<double>((x) => x * 10);
      final d = MotionValue.computed([b, c], () => b.value + c.value);
      var notifications = 0;
      d.addListener(() => notifications++);
      a.value = 2;
      expect(notifications, greaterThan(0));
      expect(d.value, 23, reason: 'b=3, c=20 read after propagation');
    });

    test('chains with other computed values', () {
      final a = MotionValue<double>(1);
      final b = MotionValue.computed([a], () => a.value + 1);
      final c = MotionValue.computed([b], () => b.value * 3);
      a.value = 4;
      expect(c.value, 15);
    });

    test('dispose detaches from every dependency', () {
      final a = MotionValue<double>(1);
      final b = MotionValue<double>(1);
      final v = MotionValue.computed([a, b], () => a.value + b.value);
      expect(a.hasListeners, isTrue);
      expect(b.hasListeners, isTrue);
      v.dispose();
      expect(a.hasListeners, isFalse);
      expect(b.hasListeners, isFalse);
    });

    test('is read-only', () {
      final a = MotionValue<double>(1);
      final v = MotionValue.computed([a], () => a.value);
      expect(() => v.value = 3, throwsStateError);
    });
  });

  group('MotionValue lifecycle', () {
    test('DerivedMotionValue.dispose removes its source listener', () {
      final source = MotionValue<double>(0);
      final derived = source.mapRange([0, 1], [0, 100]);
      expect(source.hasListeners, isTrue);
      derived.dispose();
      expect(source.hasListeners, isFalse);
    });

    test('long transform chain disposes cleanly bottom-up', () {
      final source = MotionValue<double>(0);
      var node = source.transform<double>((x) => x);
      final chain = [node];
      for (var i = 0; i < 50; i++) {
        node = node.transform<double>((x) => x + 1);
        chain.add(node);
      }
      source.value = 1;
      expect(node.value, 51);
      for (final n in chain.reversed) {
        n.dispose();
      }
      expect(source.hasListeners, isFalse);
    });
  });
}

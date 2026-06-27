import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  group('NibTimelineEntry', () {
    test('stores controller, target, at, and transition', () {
      final controller = NibMotionController();
      addTearDown(controller.dispose);

      const target = NibAnim(opacity: 1.0);
      const at = Duration(milliseconds: 200);
      const transition = NibTransition(duration: Duration(milliseconds: 50));

      final entry = NibTimelineEntry(controller: controller, target: target, at: at, transition: transition);

      expect(entry.controller, same(controller));
      expect(entry.target, target);
      expect(entry.at, at);
      expect(entry.transition, transition);
    });

    test('transition defaults to null', () {
      final controller = NibMotionController();
      addTearDown(controller.dispose);

      final entry = NibTimelineEntry(controller: controller, target: const NibAnim(opacity: 1.0), at: Duration.zero);

      expect(entry.transition, isNull);
    });

    test('equal entries with the same fields compare equal', () {
      final controller = NibMotionController();
      addTearDown(controller.dispose);

      const target = NibAnim(opacity: 1.0);
      const at = Duration(milliseconds: 100);

      final a = NibTimelineEntry(controller: controller, target: target, at: at);
      final b = NibTimelineEntry(controller: controller, target: target, at: at);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('entries with different fields are not equal', () {
      final controller = NibMotionController();
      addTearDown(controller.dispose);

      final a = NibTimelineEntry(
        controller: controller,
        target: const NibAnim(opacity: 1.0),
        at: const Duration(milliseconds: 100),
      );
      final b = NibTimelineEntry(
        controller: controller,
        target: const NibAnim(opacity: 0.0),
        at: const Duration(milliseconds: 100),
      );

      expect(a, isNot(equals(b)));
    });
  });
}

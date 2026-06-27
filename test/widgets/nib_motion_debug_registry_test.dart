import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  tearDown(() {
    // Avoid cross-test leakage, since `NibMotionRegistry.instance` is a
    // process-wide singleton.
    for (final id in NibMotionRegistry.instance.values.keys.toList()) {
      NibMotionRegistry.instance.unregister(id);
    }
  });

  group('NibMotion debug registration', () {
    testWidgets('registers its MotionValues with NibMotionRegistry on mount', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: NibMotion(
            key: const ValueKey('probe'),
            initial: const NibAnim(opacity: 0.5),
            child: const SizedBox(width: 10, height: 10),
          ),
        ),
      );

      final ids = NibMotionRegistry.instance.values.keys;
      expect(ids.any((id) => id.contains('opacity')), isTrue);
      expect(ids.any((id) => id.contains('translateX')), isTrue);
      expect(ids.any((id) => id.contains('boxShadow')), isTrue);
    });

    testWidgets('reflects live updates through the registered MotionValue', (tester) async {
      final controller = NibMotionController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: NibMotion(
            key: const ValueKey('probe'),
            controller: controller,
            initial: const NibAnim(opacity: 0.0),
            transition: const NibTransition(duration: Duration(milliseconds: 10)),
            child: const SizedBox(width: 10, height: 10),
          ),
        ),
      );

      final opacityEntry = NibMotionRegistry.instance.values.entries.firstWhere((e) => e.key.contains('opacity'));
      expect(opacityEntry.value.value, 0.0);

      controller.set(const NibAnim(opacity: 1.0));
      await tester.pump();

      expect(opacityEntry.value.value, 1.0);
    });

    testWidgets('unregisters its MotionValues on dispose', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: NibMotion(
            key: const ValueKey('probe'),
            initial: const NibAnim(opacity: 0.5),
            child: const SizedBox(width: 10, height: 10),
          ),
        ),
      );

      expect(NibMotionRegistry.instance.values, isNotEmpty);

      await tester.pumpWidget(const SizedBox());

      expect(NibMotionRegistry.instance.values, isEmpty);
    });
  });
}

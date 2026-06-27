import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/src/debug/motion_value_inspector.dart';
import 'package:nib_motion/src/values/motion_value.dart';

void main() {
  // `flutter test` always runs with kDebugMode == true, so the registry's
  // debug-mode-only behavior is directly testable here.
  setUp(() {
    expect(kDebugMode, isTrue);
  });

  tearDown(() {
    // Avoid cross-test leakage of registered values, since `instance` is a
    // process-wide singleton.
    for (final id in NibMotionRegistry.instance.values.keys.toList()) {
      NibMotionRegistry.instance.unregister(id);
    }
  });

  group('NibMotionRegistry', () {
    test('register adds a value retrievable via values', () {
      final value = MotionValue<double>(1.0);

      NibMotionRegistry.instance.register('opacity', value);

      expect(NibMotionRegistry.instance.values, containsPair('opacity', value));
    });

    test('registering under an existing id replaces the previous entry', () {
      final first = MotionValue<double>(1.0);
      final second = MotionValue<double>(2.0);

      NibMotionRegistry.instance.register('x', first);
      NibMotionRegistry.instance.register('x', second);

      expect(NibMotionRegistry.instance.values['x'], second);
      expect(NibMotionRegistry.instance.values.length, 1);
    });

    test('unregister removes the entry', () {
      final value = MotionValue<double>(1.0);
      NibMotionRegistry.instance.register('y', value);

      NibMotionRegistry.instance.unregister('y');

      expect(NibMotionRegistry.instance.values.containsKey('y'), isFalse);
    });

    test('unregistering an unknown id is a no-op and does not throw', () {
      expect(
        () => NibMotionRegistry.instance.unregister('does-not-exist'),
        returnsNormally,
      );
    });

    test('values is unmodifiable', () {
      NibMotionRegistry.instance.register('z', MotionValue<double>(0.0));

      final values = NibMotionRegistry.instance.values;

      expect(
        () => values['new'] = MotionValue<double>(0.0),
        throwsUnsupportedError,
      );
    });

    test('values reflects multiple registered entries', () {
      NibMotionRegistry.instance.register('a', MotionValue<double>(0.0));
      NibMotionRegistry.instance.register('b', MotionValue<double>(1.0));

      expect(NibMotionRegistry.instance.values.keys, containsAll(['a', 'b']));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  group('NibDurationExtension', () {
    test('ms converts an int to a millisecond Duration', () {
      expect(200.ms, const Duration(milliseconds: 200));
    });

    test('seconds converts an int to a second Duration', () {
      expect(3.seconds, const Duration(seconds: 3));
    });
  });
}

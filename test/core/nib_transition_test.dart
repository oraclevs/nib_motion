import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  group('NibTransition', () {
    test('default constructor is a tween with sensible defaults', () {
      const transition = NibTransition();

      expect(transition.type, NibTransitionType.tween);
      expect(transition.spring, isNull);
      expect(transition.duration, const Duration(milliseconds: 300));
      expect(transition.curve, Curves.easeInOut);
      expect(transition.delay, Duration.zero);
    });

    test('providing a spring sets type to spring', () {
      const transition = NibTransition(spring: NibSpringDescription.gentle);

      expect(transition.type, NibTransitionType.spring);
      expect(transition.spring, NibSpringDescription.gentle);
    });

    test('springGentle/springSnappy/springWobbly presets use matching springs', () {
      expect(
        NibTransition.springGentle.spring,
        NibSpringDescription.gentle,
      );
      expect(NibTransition.springGentle.type, NibTransitionType.spring);

      expect(
        NibTransition.springSnappy.spring,
        NibSpringDescription.snappy,
      );
      expect(
        NibTransition.springWobbly.spring,
        NibSpringDescription.wobbly,
      );
    });
  });
}

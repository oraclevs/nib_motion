import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  group('computeAnimFromKeyframes', () {
    const keyframes = [
      NibKeyframe(at: 0.0, value: NibAnim(opacity: 0)),
      NibKeyframe(at: 0.5, value: NibAnim(opacity: 1)),
      NibKeyframe(at: 1.0, value: NibAnim(opacity: 0)),
    ];

    test('interpolates within the first segment', () {
      final anim = computeAnimFromKeyframes(keyframes, 0.25, Curves.linear);
      expect(anim.opacity, closeTo(0.5, 0.001));
    });

    test('interpolates within the second segment', () {
      final anim = computeAnimFromKeyframes(keyframes, 0.75, Curves.linear);
      expect(anim.opacity, closeTo(0.5, 0.001));
    });

    test('applies the per-segment curve of the upcoming keyframe', () {
      const curvedKeyframes = [
        NibKeyframe(at: 0.0, value: NibAnim(opacity: 0)),
        NibKeyframe(at: 0.5, value: NibAnim(opacity: 1), curve: Curves.easeIn),
        NibKeyframe(at: 1.0, value: NibAnim(opacity: 0)),
      ];

      final linear = computeAnimFromKeyframes(keyframes, 0.25, Curves.linear);
      final eased =
          computeAnimFromKeyframes(curvedKeyframes, 0.25, Curves.linear);

      expect(eased.opacity, isNot(closeTo(linear.opacity!, 0.001)));
    });

    test('a single keyframe returns its value for any t without crashing', () {
      const single = [NibKeyframe(at: 0.5, value: NibAnim(opacity: 0.7))];

      expect(computeAnimFromKeyframes(single, 0.0, Curves.linear).opacity,
          closeTo(0.7, 0.001));
      expect(computeAnimFromKeyframes(single, 0.5, Curves.linear).opacity,
          closeTo(0.7, 0.001));
      expect(computeAnimFromKeyframes(single, 1.0, Curves.linear).opacity,
          closeTo(0.7, 0.001));
    });

    test('unsorted keyframes are sorted before computing', () {
      const unsorted = [
        NibKeyframe(at: 1.0, value: NibAnim(opacity: 0)),
        NibKeyframe(at: 0.0, value: NibAnim(opacity: 0)),
        NibKeyframe(at: 0.5, value: NibAnim(opacity: 1)),
      ];

      final fromUnsorted =
          computeAnimFromKeyframes(unsorted, 0.25, Curves.linear);
      final fromSorted =
          computeAnimFromKeyframes(keyframes, 0.25, Curves.linear);

      expect(fromUnsorted.opacity, closeTo(fromSorted.opacity!, 0.001));
    });

    test('t before the first keyframe returns the first value', () {
      final anim = computeAnimFromKeyframes(keyframes, -0.1, Curves.linear);
      expect(anim.opacity, closeTo(0.0, 0.001));
    });

    test('t after the last keyframe returns the last value', () {
      final anim = computeAnimFromKeyframes(keyframes, 1.1, Curves.linear);
      expect(anim.opacity, closeTo(0.0, 0.001));
    });
  });
}

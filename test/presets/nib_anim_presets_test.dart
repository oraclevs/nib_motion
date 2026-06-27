import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  group('NibAnimPresets keyframe lists', () {
    void expectSortedAndBounded(List<NibKeyframe> keyframes) {
      expect(keyframes, isNotEmpty);
      expect(keyframes.first.at, 0.0);
      expect(keyframes.last.at, 1.0);
      for (var i = 1; i < keyframes.length; i++) {
        expect(
          keyframes[i].at,
          greaterThan(keyframes[i - 1].at),
          reason: 'keyframe `at` values must be strictly ascending',
        );
      }
      for (final keyframe in keyframes) {
        expect(keyframe.at, inInclusiveRange(0.0, 1.0));
      }
    }

    test('shake is sorted and bounded 0.0 to 1.0', () {
      expectSortedAndBounded(NibAnimPresets.shake);
    });

    test('bounceIn is sorted and bounded 0.0 to 1.0', () {
      expectSortedAndBounded(NibAnimPresets.bounceIn);
    });

    test('pulse is sorted and bounded 0.0 to 1.0', () {
      expectSortedAndBounded(NibAnimPresets.pulse);
    });

    test('rubberBand is sorted and bounded 0.0 to 1.0', () {
      expectSortedAndBounded(NibAnimPresets.rubberBand);
    });

    test('wiggle is sorted and bounded 0.0 to 1.0', () {
      expectSortedAndBounded(NibAnimPresets.wiggle);
    });

    test('shake starts and ends at x: 0', () {
      expect(NibAnimPresets.shake.first.value.x, 0);
      expect(NibAnimPresets.shake.last.value.x, 0);
    });

    test('bounceIn starts above and offscreen-transparent, ends settled', () {
      final first = NibAnimPresets.bounceIn.first.value;
      expect(first.y, -60);
      expect(first.opacity, 0);
      final last = NibAnimPresets.bounceIn.last.value;
      expect(last.y, 0);
    });

    test('pulse scales up at the midpoint and returns to 1.0', () {
      expect(NibAnimPresets.pulse.first.value.scale, 1.0);
      expect(NibAnimPresets.pulse[1].value.scale, 1.08);
      expect(NibAnimPresets.pulse.last.value.scale, 1.0);
    });

    test('rubberBand starts and ends at uniform scale', () {
      final first = NibAnimPresets.rubberBand.first.value;
      expect(first.scaleX, 1.0);
      expect(first.scaleY, 1.0);
      final last = NibAnimPresets.rubberBand.last.value;
      expect(last.scaleX, 1.0);
      expect(last.scaleY, 1.0);
    });

    test('wiggle starts and ends with no rotation', () {
      expect(NibAnimPresets.wiggle.first.value.rotate, 0);
      expect(NibAnimPresets.wiggle.last.value.rotate, 0);
    });
  });

  group('NibAnimPresets NibAnim constants', () {
    test('fadeUp fades in from below', () {
      expect(NibAnimPresets.fadeUp.opacity, 0);
      expect(NibAnimPresets.fadeUp.y, 24);
    });

    test('fadeDown fades in from above', () {
      expect(NibAnimPresets.fadeDown.opacity, 0);
      expect(NibAnimPresets.fadeDown.y, -24);
    });

    test('fadeLeft fades in from the left', () {
      expect(NibAnimPresets.fadeLeft.opacity, 0);
      expect(NibAnimPresets.fadeLeft.x, -24);
    });

    test('fadeRight fades in from the right', () {
      expect(NibAnimPresets.fadeRight.opacity, 0);
      expect(NibAnimPresets.fadeRight.x, 24);
    });

    test('zoomIn starts smaller than identity', () {
      expect(NibAnimPresets.zoomIn.opacity, 0);
      expect(NibAnimPresets.zoomIn.scale, 0.85);
    });

    test('zoomOut starts larger than identity', () {
      expect(NibAnimPresets.zoomOut.opacity, 0);
      expect(NibAnimPresets.zoomOut.scale, 1.15);
    });
  });
}

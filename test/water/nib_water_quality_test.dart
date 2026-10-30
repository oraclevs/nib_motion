import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  test('device quality reports bounded rounded dimensions and reason', () {
    final native = const NibWaterQuality().resolve(const Size(390, 844), 3);
    expect(native.width, 1170);
    expect(native.height, 2532);
    expect(native.effectiveScale, 3);
    for (final size in [
      const Size(390.3, 844.7),
      const Size(10000, 1),
      const Size(1, 10000)
    ]) {
      final r = const NibWaterQuality(
              maxBytes: 4096, maxPixels: 1500, maxTextureSize: 100)
          .resolve(size, 3);
      expect(r.width * r.height, lessThanOrEqualTo(1024));
      expect(r.width, inInclusiveRange(1, 100));
      expect(r.height, inInclusiveRange(1, 100));
      expect(r.effectiveScale, lessThan(r.requestedScale));
      expect(r.reason, contains('reduced'));
    }
  });
  test('material domains reject nonfinite optics independently of speed', () {
    expect(NibWaterMaterial.clear.blurSigma, 0);
    expect(NibWaterMaterial.deep.blurSigma, 0);
    expect(
        NibWaterMaterial.deep.depth, greaterThan(NibWaterMaterial.clear.depth));
    for (final material in [
      NibWaterMaterial(blurSigma: double.nan),
      NibWaterMaterial(depth: double.infinity),
      const NibWaterMaterial(absorption: -1),
      const NibWaterMaterial(refraction: 49),
      const NibWaterMaterial(highlight: 3),
    ]) {
      expect(material.validate, throwsArgumentError);
    }
    expect(() => const NibWaterQuality().resolve(const Size(1e300, 1e300), 1),
        throwsArgumentError);
  });
  test('nonfinite quality and invalid budgets fail in release validation', () {
    for (final q in [
      NibWaterQuality(scale: double.nan),
      const NibWaterQuality(scale: 0),
      const NibWaterQuality(maxPixels: 0),
      const NibWaterQuality(maxBytes: 3),
      const NibWaterQuality(maxTextureSize: 0)
    ]) {
      expect(q.validate, throwsArgumentError);
    }
    expect(() => const NibWaterQuality().resolve(Size.zero, 1),
        throwsArgumentError);
    expect(
        () => const NibWaterQuality()
            .resolve(const Size(10, 10), double.infinity),
        throwsArgumentError);
  });
}

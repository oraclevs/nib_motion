import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  group('NibAnim.identity', () {
    test('has transform/opacity properties at their identity values', () {
      const identity = NibAnim.identity;

      expect(identity.x, 0.0);
      expect(identity.y, 0.0);
      expect(identity.scale, 1.0);
      expect(identity.scaleX, 1.0);
      expect(identity.scaleY, 1.0);
      expect(identity.rotate, 0.0);
      expect(identity.skewX, 0.0);
      expect(identity.skewY, 0.0);
      expect(identity.opacity, 1.0);
      expect(identity.color, isNull);
      expect(identity.borderRadius, isNull);
      expect(identity.boxShadow, isNull);
    });
  });

  group('NibAnim.lerp', () {
    test('at t=0.0 returns the start value', () {
      const start = NibAnim(opacity: 0.2, x: 10, scale: 2.0);
      const end = NibAnim(opacity: 0.8, x: 50, scale: 1.0);

      expect(start.lerp(end, 0.0), start);
    });

    test('at t=1.0 returns the end value', () {
      const start = NibAnim(opacity: 0.2, x: 10, scale: 2.0);
      const end = NibAnim(opacity: 0.8, x: 50, scale: 1.0);

      expect(start.lerp(end, 1.0), end);
    });

    test('at t=0.5 interpolates opacity 0.0 -> 1.0 to 0.5', () {
      const start = NibAnim(opacity: 0.0);
      const end = NibAnim(opacity: 1.0);

      expect(start.lerp(end, 0.5).opacity, 0.5);
    });

    test('uses identity opacity (1.0) when one side is null', () {
      const start = NibAnim();
      const end = NibAnim(opacity: 0.5);

      expect(start.lerp(end, 0.5).opacity, 0.75);
    });

    test('interpolates color via Color.lerp', () {
      const start = NibAnim(color: Colors.black);
      const end = NibAnim(color: Colors.white);

      final result = start.lerp(end, 0.5);

      expect(result.color, Color.lerp(Colors.black, Colors.white, 0.5));
    });

    test('leaves a property null when both sides are null', () {
      const start = NibAnim(opacity: 0.0);
      const end = NibAnim(opacity: 1.0);

      final result = start.lerp(end, 0.5);

      expect(result.color, isNull);
      expect(result.borderRadius, isNull);
      expect(result.boxShadow, isNull);
    });
  });

  group('NibAnim.copyWith', () {
    test('overrides only specified properties', () {
      const base = NibAnim(x: 10, y: 20, opacity: 0.5);

      final result = base.copyWith(opacity: 1.0);

      expect(result.x, 10);
      expect(result.y, 20);
      expect(result.opacity, 1.0);
    });
  });

  group('NibAnim.merge', () {
    test('replaces only non-null properties from other', () {
      const base = NibAnim(x: 10, y: 20, opacity: 0.5);
      const overrides = NibAnim(opacity: 1.0);

      final result = base.merge(overrides);

      expect(result.x, 10);
      expect(result.y, 20);
      expect(result.opacity, 1.0);
    });
  });
}

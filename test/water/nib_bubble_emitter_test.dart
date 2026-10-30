import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  test('shared emitter is bounded, deterministic, stoppable and resettable',
      () {
    final a =
        NibWaterController(drops: const [], emitter: NibBubbleEmitter(seed: 4));
    final b =
        NibWaterController(drops: const [], emitter: NibBubbleEmitter(seed: 4));
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    var notifications = 0;
    a.addListener(() => notifications++);
    for (var i = 0; i < 1200; i++) {
      a.advance(1 / 60, bounds: const Size(390, 844));
      b.advance(1 / 60, bounds: const Size(390, 844));
      expect(a.drops.length, lessThanOrEqualTo(6));
      expect(a.drops.map((d) => (d.id, d.center, d.radius)),
          b.drops.map((d) => (d.id, d.center, d.radius)));
      expect(a.drops.every((d) => d.center.dx.isFinite && d.center.dy.isFinite),
          isTrue);
    }
    expect(notifications, 1200);
    a.setEmitting(false);
    for (var i = 0; i < 500; i++) {
      a.advance(1 / 60, bounds: const Size(390, 844));
    }
    expect(a.drops, isEmpty);
    expect(a.isActive, isFalse);
    a.setEmitting(true);
    a.reset();
    b.reset();
    a.advance(.016, bounds: const Size(390, 844));
    b.advance(.016, bounds: const Size(390, 844));
    expect(a.drops.first.center, b.drops.first.center);
    a.setReducedMotion(true);
    final frozen = a.drops.first.center;
    a.advance(.066, bounds: const Size(390, 844));
    expect(a.drops.first.center, frozen);
  });
  test('dynamic scene validates before mutation and batches notification', () {
    final water = NibWaterController(drops: const []);
    addTearDown(water.dispose);
    var calls = 0;
    water.addListener(() => calls++);
    water.setDrops(const [NibWaterDrop(id: 3, center: Offset(20, 30))]);
    expect(calls, 1);
    water.putDrop(const NibWaterDrop(id: 3, center: Offset(30, 40)));
    expect(water.drops.single.center, const Offset(30, 40));
    expect(
        () => water.putDrop(NibWaterDrop(id: 4, center: Offset(double.nan, 0))),
        throwsArgumentError);
    expect(water.drops.length, 1);
    water.removeDrop(3);
    expect(water.drops, isEmpty);
    expect(calls, 3);
    expect(() => NibBubbleEmitter(maxBubbles: 11), throwsArgumentError);
    expect(
        () => NibBubbleEmitter(interval: double.infinity), throwsArgumentError);
  });
}

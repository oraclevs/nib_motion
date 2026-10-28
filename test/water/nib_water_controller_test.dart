import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/src/water/nib_water_controller.dart';

const separate = [
  NibWaterDrop(id: 1, center: Offset(100, 160), radius: 50),
  NibWaterDrop(id: 2, center: Offset(300, 160), radius: 50),
];

NibWaterController controller({
  List<NibWaterDrop> drops = separate,
  NibWaterConfig config = const NibWaterConfig(),
}) {
  final value = NibWaterController(drops: drops, config: config);
  addTearDown(value.dispose);
  return value;
}

void run(NibWaterController value, double seconds, {double dt = 1 / 120}) {
  for (var t = 0.0; t < seconds - 1e-9; t += dt) {
    value.advance(math.min(dt, seconds - t));
  }
}

void expectFinite(NibWaterController value) {
  for (final drop in value.drops) {
    expect(drop.center.dx.isFinite, isTrue);
    expect(drop.center.dy.isFinite, isTrue);
    expect(drop.velocity.dx.isFinite, isTrue);
    expect(drop.velocity.dy.isFinite, isTrue);
    expect(drop.velocity.distance, lessThanOrEqualTo(4000.000001));
  }
}

void main() {
  test('runtime validation rejects invalid config and preserves accepted state',
      () {
    final value = controller();
    for (final invalid in [
      const NibWaterConfig(waveSpeed: double.nan),
      const NibWaterConfig(damping: 0),
      const NibWaterConfig(impulseStrength: 25),
      const NibWaterConfig(wavelength: 0),
      const NibWaterConfig(recovery: double.infinity),
      const NibWaterConfig(refraction: -1),
      const NibWaterConfig(highlight: 2.1),
    ]) {
      expect(() => value.configure(invalid), throwsArgumentError);
      expect(() => NibWaterController(drops: separate, config: invalid),
          throwsArgumentError);
      expect(value.config.recovery, 14);
      expect(value.drops.map((drop) => drop.center),
          separate.map((drop) => drop.center));
    }
    expect(() => value.advance(double.nan), throwsArgumentError);
    expect(() => value.advance(double.infinity), throwsArgumentError);
    expect(() => value.advance(-1), throwsArgumentError);
    expect(
        () => value.disturb(const Offset(double.nan, 0)), throwsArgumentError);
    expect(() => value.disturb(Offset.zero, strength: double.infinity),
        throwsArgumentError);
    expect(() => value.beginDrag(1, const Offset(1e7, 0)), throwsArgumentError);
    expect(() => value.dragTo(99, const Offset(0, double.infinity)),
        throwsArgumentError);
    expect(
        () => value.fieldAt(const Offset(double.nan, 0)), throwsArgumentError);
  });

  test('drop identity, radius, velocity and count are validated at runtime',
      () {
    for (final invalid in <List<NibWaterDrop>>[
      [separate.first, separate.first],
      [const NibWaterDrop(id: 0, center: Offset(double.infinity, 0))],
      [const NibWaterDrop(id: 0, center: Offset.zero, radius: 0)],
      [const NibWaterDrop(id: 0, center: Offset.zero, radius: 257)],
      [
        const NibWaterDrop(
            id: 0, center: Offset.zero, velocity: Offset(4001, 0))
      ],
      List.generate(11, (i) => NibWaterDrop(id: i, center: Offset(i * 200, 0))),
    ]) {
      expect(() => NibWaterController(drops: invalid), throwsArgumentError);
    }
    final empty = controller(drops: []);
    expect(empty.drops, isEmpty);
    expect(empty.massProxy, 0);
    expect(empty.hitTest(Offset.zero), isNull);
    empty.merge();
    empty.split();
    expect(empty.phase, NibWaterPhase.separated);
  });

  test('snapshots are immutable and do not change after later mutations', () {
    final value = controller();
    final snapshot = value.drops;
    expect(() => snapshot.clear(), throwsUnsupportedError);
    value.disturb(const Offset(20, 20));
    final impulses = value.impulses;
    expect(() => impulses.clear(), throwsUnsupportedError);
    value.merge();
    run(value, 1);
    expect(snapshot.first.center, const Offset(100, 160));
    expect(impulses.single.age, 0);
    expect(value.impulses.single.age, closeTo(1, 1e-10));
  });

  test('field and hit test use receiver-local Gaussian half-height radius', () {
    final value = controller(drops: [separate.first]);
    expect(value.fieldAt(const Offset(100, 160)), 1);
    expect(value.fieldAt(const Offset(150, 160)), closeTo(.5, 1e-12));
    expect(value.hitTest(const Offset(150, 160)), 1);
    expect(value.hitTest(const Offset(151, 160)), isNull);
    expect(value.hitTest(const Offset(100, 160)), 1);
    expect(value.beginDrag(1, const Offset(0, 160)), isFalse);
  });

  test('merge is position/velocity continuous and conserves the mass proxy',
      () {
    final value = controller();
    final mass = value.massProxy;
    expect(mass, closeTo(2 * math.pi * 2500, 1e-9));
    var notifications = 0;
    value.addListener(() {
      notifications++;
      expect(value.drops.map((drop) => drop.bodyId).toSet(), {1});
    });
    value.merge();
    expect(notifications, 1);
    expect(value.phase, NibWaterPhase.merging);
    expect(value.drops.first.center, separate.first.center);
    expect(value.drops.last.center, separate.last.center);
    value.advance(1 / 120);
    expect(value.drops.first.center.dx, greaterThan(100));
    expect(value.drops.first.center.dx, lessThan(102));
    expect(value.drops.last.center.dx, greaterThan(298));
    expect(value.drops.first.velocity.dx, greaterThan(0));
    expect(value.massProxy, mass);
    run(value, 3);
    expect(value.phase, NibWaterPhase.merged);
    expect(value.drops.map((drop) => drop.center).toSet(),
        {const Offset(200, 160)});
    expect(value.isActive, isFalse);
    expect(value.massProxy, mass);
    expect(value.drops.map((drop) => drop.radius), [50, 50]);
    expect(value.fieldAt(const Offset(270, 160)), greaterThan(.5));
    expect(value.hitTest(const Offset(270, 160)), isNotNull);
  });

  test('unequal-radius merge retains area-weighted center and identity', () {
    final value = controller(drops: const [
      NibWaterDrop(id: 9, center: Offset(100, 100), radius: 40),
      NibWaterDrop(id: 3, center: Offset(500, 100), radius: 80),
    ]);
    value.merge();
    run(value, 3);
    for (final drop in value.drops) {
      expect(drop.center, const Offset(420, 100));
      expect(drop.bodyId, 3);
    }
  });

  test('automatic merging requires a visible neck and persists after release',
      () {
    final value = controller();
    expect(value.beginDrag(1, const Offset(100, 160)), isTrue);
    value.dragTo(1, const Offset(150, 160));
    run(value, 3);
    expect(value.phase, NibWaterPhase.separated);
    expect(value.fieldAt(const Offset(225, 160)), lessThan(.5));
    value.dragTo(1, const Offset(175, 160));
    run(value, .4);
    expect(value.drops.map((drop) => drop.bodyId).toSet(), {1});
    final a = value.drops.first.center;
    final b = value.drops.last.center;
    expect(value.fieldAt((a + b) / 2), greaterThan(.52));
    value.endDrag(1);
    run(value, 3);
    expect(value.phase, NibWaterPhase.merged);
    expect(value.activeInputs, 0);
    final settled = value.drops.first.center;
    run(value, 100);
    expect(value.drops.first.center, settled);
    expect(value.phase, NibWaterPhase.merged);
  });

  test('split opens a neck continuously, then stays separated until new intent',
      () {
    final value = controller();
    value.merge();
    run(value, 3);
    final center = value.drops.first.center;
    final mass = value.massProxy;
    value.split();
    expect(value.phase, NibWaterPhase.splitting);
    expect(value.drops.first.center, center);
    expect(value.fieldAt(center), 2);
    value.advance(1 / 120);
    expect(value.drops.first.center.dx, lessThan(center.dx));
    expect(value.drops.first.center.dx, greaterThan(center.dx - 2));
    expect(value.fieldAt(center), greaterThan(1.9));
    run(value, 3);
    expect(value.phase, NibWaterPhase.separated);
    expect(value.drops.map((drop) => drop.bodyId).toList(), [1, 2]);
    expect(value.fieldAt(center), lessThan(.5));
    expect(value.drops.first.center, const Offset(100, 160));
    expect(value.drops.last.center, const Offset(300, 160));
    expect(value.massProxy, mass);
    value.disturb(center);
    run(value, 4);
    expect(value.phase, NibWaterPhase.separated);
  });

  test('coincident initial members split into finite, separated regions', () {
    final value = controller(drops: const [
      NibWaterDrop(id: 4, center: Offset(100, 100), bodyId: 70, radius: 40),
      NibWaterDrop(id: 7, center: Offset(100, 100), bodyId: 70, radius: 40),
      NibWaterDrop(id: 8, center: Offset(100, 100), bodyId: 70, radius: 40),
    ]);
    expect(value.phase, NibWaterPhase.merged);
    expect(value.drops.map((drop) => drop.bodyId).toSet(), {4});
    value.split();
    run(value, 3);
    expectFinite(value);
    expect(value.phase, NibWaterPhase.separated);
    for (var i = 1; i < value.drops.length; i++) {
      expect((value.drops[i].center - value.drops[i - 1].center).distance,
          closeTo(136, 1e-8));
    }
  });

  test(
      'merge and split retarget without resetting current position or velocity',
      () {
    final value = controller();
    value.merge();
    run(value, .1);
    final beforeSplit = value.drops.first;
    value.split();
    expect(value.drops.first.center, beforeSplit.center);
    expect(value.drops.first.velocity, beforeSplit.velocity);
    value.advance(1 / 120);
    final beforeMerge = value.drops.first;
    value.merge();
    expect(value.drops.first.center, beforeMerge.center);
    expect(value.drops.first.velocity, beforeMerge.velocity);
    run(value, 3);
    expect(value.phase, NibWaterPhase.merged);
  });

  test('grab offset retained and each body can be owned by only one pointer',
      () {
    final value = controller();
    expect(value.beginDrag(1, const Offset(80, 150)), isTrue);
    expect(value.beginDrag(1, const Offset(300, 160)), isFalse);
    expect(value.beginDrag(2, const Offset(110, 160)), isFalse);
    expect(value.beginDrag(3, const Offset(300, 160)), isTrue);
    expect(value.activeInputs, 2);
    value.dragTo(1, const Offset(110, 180));
    expect(value.drops.first.center, const Offset(100, 160));
    run(value, 3);
    expect(value.drops.first.center, const Offset(130, 190));
    value.dragTo(1, const Offset(230, 150));
    run(value, 3);
    expect(value.drops.map((drop) => drop.bodyId).toSet().length, 2);
    value.endDrag(3);
    expect(value.activeInputs, 1);
    run(value, 3);
    expect(value.phase, NibWaterPhase.merged);
    expect(value.beginDrag(4, value.drops.first.center), isFalse);
    value.endDrag(1);
    expect(value.beginDrag(4, value.drops.first.center), isTrue);
  });

  test('cancel releases targets and velocity, stale pointer events do nothing',
      () {
    final value = controller();
    value.beginDrag(1, const Offset(100, 160));
    value.dragTo(1, const Offset(50, 50));
    run(value, .1);
    final before = value.drops.first.center;
    value.endDrag(1, cancelled: true);
    expect(value.activeInputs, 0);
    expect(value.drops.first.velocity, Offset.zero);
    value.dragTo(1, const Offset(900, 900));
    value.endDrag(1);
    run(value, 3);
    expect(value.drops.first.center, before);
    expect(value.isActive, isFalse);
    value.beginDrag(2, before);
    value.dragTo(2, const Offset(0, 0));
    value.cancelInputs();
    run(value, 3);
    expect(value.drops.first.center, before);
    expect(value.activeInputs, 0);
  });

  test('cancelling a merging body preserves coalescence and pointer cleanup',
      () {
    final value = controller()..merge();
    run(value, .05);
    expect(value.beginDrag(3, value.drops.first.center), isTrue);
    value.dragTo(3, value.drops.first.center + const Offset(50, 0));
    final before = value.drops;
    value.cancelInputs();
    expect(value.activeInputs, 0);
    expect(value.drops.first.center, before.first.center);
    expect(value.drops.first.velocity, Offset.zero);
    run(value, 3);
    expect(value.phase, NibWaterPhase.merged);
    expect(value.drops.first.center, value.drops.last.center);
  });

  test(
      'split preserves separation at coordinate limits and extreme initial spans',
      () {
    final value = controller(drops: const [
      NibWaterDrop(id: 0, center: Offset(-1000000, 0), radius: 256),
      NibWaterDrop(id: 1, center: Offset(-999999, 0), radius: 256),
      NibWaterDrop(id: 2, center: Offset(1000000, 0), radius: 256),
    ]);
    value.setReducedMotion(true);
    value.merge();
    value.split();
    expectFinite(value);
    expect(value.phase, NibWaterPhase.separated);
    for (var i = 0; i < value.drops.length; i++) {
      for (var j = i + 1; j < value.drops.length; j++) {
        expect((value.drops[i].center - value.drops[j].center).distance,
            greaterThanOrEqualTo(870.39999));
      }
    }
    value.merge();
    value.beginDrag(0, value.drops.first.center);
    value.dragTo(0, const Offset(1000000, 0));
    value.endDrag(0);
    value.split();
    for (var i = 1; i < value.drops.length; i++) {
      expect(value.drops[i].center.dx, lessThanOrEqualTo(1000000));
      expect((value.drops[i].center - value.drops[i - 1].center).distance,
          greaterThanOrEqualTo(870.39999));
    }
  });

  test('linear impulse time, bounded queue and deterministic amplitude expiry',
      () {
    final value = controller(drops: []);
    for (var i = 0; i < 20; i++) {
      value.disturb(Offset(i.toDouble(), 0));
    }
    expect(value.impulses.length, 12);
    expect(value.impulses.first.center.dx, 8);
    value.advance(1 / 60);
    expect(value.impulses.first.age, closeTo(1 / 60, 1e-12));
    run(value, 2);
    expect(value.impulses, isNotEmpty);
    run(value, 1);
    expect(value.impulses, isEmpty);
    expect(value.isActive, isFalse);
    final time = value.simulationTime;
    value.advance(1);
    expect(value.simulationTime, time);
    expect(value.lastStepMicros, 0);
    value.configure(const NibWaterConfig(damping: .25));
    value.disturb(Offset.zero, strength: 24);
    run(value, 7.9);
    expect(value.impulses, isNotEmpty);
    run(value, .2);
    expect(value.impulses, isEmpty);
  });

  test('large frame gaps clamp at 66ms and do not catch up on the next call',
      () {
    final huge = controller()..merge();
    final bounded = controller()..merge();
    huge.advance(5000);
    bounded.advance(.066);
    expect(huge.simulationTime, .066);
    expect(huge.drops.first.center, bounded.drops.first.center);
    expect(huge.drops.first.velocity, bounded.drops.first.velocity);
    huge.advance(1 / 120);
    bounded.advance(1 / 120);
    expect(huge.drops.first.center, bounded.drops.first.center);
    expect(huge.simulationTime, closeTo(.066 + 1 / 120, 1e-12));
  });

  test('critical recovery agrees for 60Hz and 120Hz accepted intervals', () {
    final sixty = controller()..merge();
    final oneTwenty = controller()..merge();
    run(sixty, .5, dt: 1 / 60);
    run(oneTwenty, .5);
    expect(sixty.drops.first.center.dx,
        closeTo(oneTwenty.drops.first.center.dx, 1e-9));
    expect(sixty.drops.first.velocity.dx,
        closeTo(oneTwenty.drops.first.velocity.dx, 1e-9));
  });

  test('configure changes response while retaining state, impulses and time',
      () {
    final value = controller()..merge();
    value.disturb(Offset.zero);
    run(value, .1);
    final before = value.drops;
    final time = value.simulationTime;
    final age = value.impulses.first.age;
    value.configure(
        value.config.copyWith(recovery: 30, damping: 5, refraction: 30));
    expect(value.drops.first.center, before.first.center);
    expect(value.drops.first.velocity, before.first.velocity);
    expect(value.simulationTime, time);
    expect(value.impulses.first.age, age);
    expect(value.config.refraction, 30);
    expect(value.config.wavelength, 46);
    expect(value.config.waveSpeed, 180);
  });

  test(
      'reduced motion resolves final state with no waves, replay or residual work',
      () {
    final value = controller()..merge();
    value.disturb(Offset.zero);
    run(value, .1);
    value.setReducedMotion(true);
    expect(value.phase, NibWaterPhase.merged);
    expect(value.drops.first.center, const Offset(200, 160));
    expect(value.drops.first.velocity, Offset.zero);
    expect(value.impulses, isEmpty);
    expect(value.isActive, isFalse);
    value.disturb(Offset.zero);
    value.split();
    expect(value.phase, NibWaterPhase.separated);
    expect(value.drops.first.center, const Offset(100, 160));
    value.beginDrag(1, const Offset(100, 160));
    value.dragTo(1, const Offset(120, 200));
    expect(value.drops.first.center, const Offset(120, 200));
    expect(value.isActive, isFalse);
    expect(value.impulses, isEmpty);
    value.setReducedMotion(false);
    expect(value.isActive, isFalse);
    expect(value.drops.first.center, const Offset(120, 200));
  });

  test('reset clears retained state but preserves config and reduced motion',
      () {
    final value = controller();
    value.configure(const NibWaterConfig(recovery: 22));
    value.disturb(Offset.zero);
    value.merge();
    run(value, .5);
    value.beginDrag(7, value.drops.first.center);
    value.reset();
    expect(value.drops.map((drop) => drop.center),
        separate.map((drop) => drop.center));
    expect(value.phase, NibWaterPhase.separated);
    expect(value.activeInputs, 0);
    expect(value.impulses, isEmpty);
    expect(value.simulationTime, 0);
    expect(value.config.recovery, 22);
    value.setReducedMotion(true);
    value.reset();
    expect(value.isReducedMotion, isTrue);
    expect(value.isActive, isFalse);
  });

  test(
      'bounded stress stays finite and conserves proxy under rapid retargeting',
      () {
    final value = controller(
      drops: List.generate(
          10,
          (i) => NibWaterDrop(
                id: i,
                center: Offset(100.0 + i * 200, 100),
                radius: 30 + i.toDouble(),
              )),
      config: const NibWaterConfig(recovery: 30),
    );
    final mass = value.massProxy;
    for (var i = 0; i < 500; i++) {
      if (i.isEven) {
        value.merge();
      } else {
        value.split();
      }
      value.disturb(Offset(i.toDouble(), 90), strength: 24);
      value.advance(i % 7 == 0 ? 10 : 1 / 120);
      expectFinite(value);
      expect(value.massProxy, mass);
      expect(value.impulses.length, lessThanOrEqualTo(12));
    }
    value.merge();
    run(value, 5);
    expect(value.phase, NibWaterPhase.merged);
    expect(value.isActive, isFalse);
  });

  test('idle advances never notify and dispose releases inputs and waves', () {
    final value = controller();
    var notifications = 0;
    value.addListener(() => notifications++);
    for (var i = 0; i < 100; i++) {
      value.advance(1 / 120);
    }
    expect(notifications, 0);
    expect(value.simulationTime, 0);
    value.disturb(Offset.zero);
    value.beginDrag(1, const Offset(100, 160));
    expect(notifications, 2);
    value.dispose();
    expect(value.isDisposed, isTrue);
    expect(value.activeInputs, 0);
    expect(value.impulses, isEmpty);
    expect(value.drops, isEmpty);
    expect(value.isActive, isFalse);
    expect(() => value.advance(1 / 120), throwsStateError);
    expect(() => value.reset(), throwsStateError);
    expect(() => value.disturb(Offset.zero), throwsStateError);
    expect(notifications, 2);
  });
}

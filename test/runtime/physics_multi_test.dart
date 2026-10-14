import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  group('MotionConverter', () {
    test('round-trips every built-in type', () {
      void roundTrip<T>(MotionConverter<T> c, T v) {
        final n = c.normalize(v);
        expect(n.length, c.channels);
        expect(c.denormalize(n), v);
      }

      roundTrip(MotionConverter.scalar, 3.5);
      roundTrip(MotionConverter.offset, const Offset(1, -2));
      roundTrip(MotionConverter.size, const Size(10, 20));
      roundTrip(MotionConverter.rect, const Rect.fromLTRB(1, 2, 3, 4));
      roundTrip(MotionConverter.alignment, const Alignment(0.5, -1));
      roundTrip(
          MotionConverter.edgeInsets, const EdgeInsets.fromLTRB(1, 2, 3, 4));
      roundTrip(MotionConverter.color, const Color(0xFF336699));
    });

    test('color clamps overshoot back into range', () {
      final c = MotionConverter.color.denormalize([1.4, -0.2, 0.5, 2.0]);
      expect(c.a, 1.0);
      expect(c.r, 0.0);
      expect(c.b, 1.0);
    });

    test('custom converter', () {
      const c = MotionConverter<(double, double)>.custom(
        channels: 2,
        normalize: _pairOut,
        denormalize: _pairIn,
      );
      expect(c.denormalize(c.normalize((1, 2))), (1.0, 2.0));
    });

    test('maybeFor knows built-ins and returns null otherwise', () {
      expect(MotionConverter.maybeFor<Offset>(), MotionConverter.offset);
      expect(MotionConverter.maybeFor<Color>(), MotionConverter.color);
      expect(MotionConverter.maybeFor<String>(), isNull);
    });
  });

  group('MultiSpringSolver', () {
    testWidgets('each axis has independent position and velocity',
        (tester) async {
      final v = MotionValue<Offset>(Offset.zero);
      final s = MultiSpringSolver<Offset>(
          vsync: const TestVSync(),
          value: v,
          converter: MotionConverter.offset,
          spring: NibSpringDescription.gentle);
      // x moves a long way, y barely at all.
      s.animateTo(const Offset(300, 3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(s.velocities[0].abs(), greaterThan(s.velocities[1].abs() * 10));
      expect(v.value.dx, greaterThan(v.value.dy * 10));
      s.dispose();
    });

    testWidgets('settles exactly on the target with zero velocity',
        (tester) async {
      final v = MotionValue<Size>(const Size(10, 10));
      final s = MultiSpringSolver<Size>(
          vsync: const TestVSync(),
          value: v,
          converter: MotionConverter.size,
          spring: NibSpring.spatialDefault);
      var ended = 0;
      s.onComplete = () => ended++;
      s.animateTo(const Size(200, 50));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      expect(v.value, const Size(200, 50));
      expect(s.velocities, [0.0, 0.0]);
      expect(ended, 1);
      expect(s.isAnimating, isFalse);
      s.dispose();
    });

    testWidgets('retarget keeps per-axis velocity (no restart from rest)',
        (tester) async {
      final v = MotionValue<Offset>(Offset.zero);
      final s = MultiSpringSolver<Offset>(
          vsync: const TestVSync(),
          value: v,
          converter: MotionConverter.offset,
          spring: NibSpringDescription.gentle);
      s.animateTo(const Offset(300, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final before = v.value.dx;
      final vx = s.velocities[0];
      expect(vx, greaterThan(0));

      // Reverse only x; y target unchanged (0) and y had no velocity.
      s.animateTo(Offset.zero);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 8));
      expect(v.value.dx, greaterThan(before),
          reason: 'forward x momentum carries on before turning');
      expect(v.value.dy, 0);
      s.dispose();
    });

    testWidgets('superseded and stopped futures resolve', (tester) async {
      final v = MotionValue<Offset>(Offset.zero);
      final s = MultiSpringSolver<Offset>(
          vsync: const TestVSync(),
          value: v,
          converter: MotionConverter.offset,
          spring: NibSpringDescription.gentle);
      var first = false, second = false;
      s.animateTo(const Offset(100, 0)).then((_) => first = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      s.animateTo(const Offset(0, 100)).then((_) => second = true);
      await tester.pump();
      expect(first, isTrue);
      expect(second, isFalse);
      s.stop();
      await tester.pump();
      expect(second, isTrue);
      s.dispose();
    });

    testWidgets('an outside assignment is a jump: velocity resets',
        (tester) async {
      final v = MotionValue<Offset>(Offset.zero);
      final s = MultiSpringSolver<Offset>(
          vsync: const TestVSync(),
          value: v,
          converter: MotionConverter.offset,
          spring: NibSpringDescription.stiff);
      s.animateTo(const Offset(300, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      s.stop();
      v.value = const Offset(50, 0); // jump
      s.animateTo(Offset.zero);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 8));
      expect(v.value.dx, lessThan(50));
      s.dispose();
    });

    testWidgets('immediate jumps and resolves', (tester) async {
      final v = MotionValue<Color>(const Color(0xFF000000));
      final s = MultiSpringSolver<Color>(
          vsync: const TestVSync(),
          value: v,
          converter: MotionConverter.color,
          spring: NibSpringDescription.gentle);
      var done = false;
      s
          .animateTo(const Color(0xFFFF0000), immediate: true)
          .then((_) => done = true);
      await tester.pump();
      expect(v.value, const Color(0xFFFF0000));
      expect(done, isTrue);
      expect(s.isAnimating, isFalse);
      s.dispose();
    });

    testWidgets('dispose mid-flight is safe and resolves the future',
        (tester) async {
      final v = MotionValue<Offset>(Offset.zero);
      final s = MultiSpringSolver<Offset>(
          vsync: const TestVSync(),
          value: v,
          converter: MotionConverter.offset,
          spring: NibSpringDescription.gentle);
      var done = false;
      s.animateTo(const Offset(100, 100)).then((_) => done = true);
      await tester.pump();
      s.dispose();
      await tester.pump();
      expect(done, isTrue);
      s.dispose(); // idempotent
    });

    testWidgets('notifies once per frame for a 4-channel value',
        (tester) async {
      final v = MotionValue<Rect>(Rect.zero);
      final s = MultiSpringSolver<Rect>(
          vsync: const TestVSync(),
          value: v,
          converter: MotionConverter.rect,
          spring: NibSpringDescription.gentle);
      var n = 0;
      v.addListener(() => n++);
      s.animateTo(const Rect.fromLTRB(10, 20, 300, 400));
      await tester.pump();
      n = 0;
      await tester.pump(const Duration(milliseconds: 16));
      expect(n, 1);
      s.dispose();
    });
  });

  group('NibValueBuilder', () {
    testWidgets('animates EdgeInsets and retargets on change', (tester) async {
      Widget host(EdgeInsets t) => Directionality(
            textDirection: TextDirection.ltr,
            child: NibValueBuilder<EdgeInsets>(
              target: t,
              builder: (context, v) => Padding(
                padding: v,
                child:
                    const SizedBox(key: ValueKey('c'), width: 10, height: 10),
              ),
            ),
          );
      await tester.pumpWidget(host(EdgeInsets.zero));
      expect(tester.getTopLeft(find.byKey(const ValueKey('c'))), Offset.zero);

      await tester.pumpWidget(host(const EdgeInsets.all(100)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final mid = tester.getTopLeft(find.byKey(const ValueKey('c')));
      expect(mid.dx, inExclusiveRange(1, 99));

      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(const ValueKey('c'))),
          const Offset(100, 100));
    });

    testWidgets('reduced motion jumps', (tester) async {
      NibMotionConfig.setReducedMotion(true);
      addTearDown(() => NibMotionConfig.setReducedMotion(null));
      Widget host(Size t) => Directionality(
            textDirection: TextDirection.ltr,
            child: NibValueBuilder<Size>(
              target: t,
              builder: (context, v) => Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox.fromSize(key: const ValueKey('s'), size: v)),
            ),
          );
      await tester.pumpWidget(host(const Size(10, 10)));
      await tester.pumpWidget(host(const Size(80, 40)));
      expect(
          tester.getSize(find.byKey(const ValueKey('s'))), const Size(80, 40));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('custom type needs a converter', (tester) async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: NibValueBuilder<String>(
            target: 'x', builder: (_, __) => const SizedBox()),
      ));
      expect(tester.takeException(), isArgumentError);
    });

    testWidgets('unmount mid-flight leaves no ticker', (tester) async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: NibValueBuilder<double>(
            target: 0.0, builder: (_, __) => const SizedBox()),
      ));
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: NibValueBuilder<double>(
            target: 100.0, builder: (_, __) => const SizedBox()),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox());
      expect(tester.binding.transientCallbackCount, 0);
    });
  });
}

List<double> _pairOut((double, double) v) => [v.$1, v.$2];
(double, double) _pairIn(List<double> c) => (c[0], c[1]);

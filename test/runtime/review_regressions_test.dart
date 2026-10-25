// Regression tests for bugs found by the correctness review fuzzing.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';
import 'package:nib_motion/src/layout/nib_layout_frame_hook.dart';
import 'package:nib_motion/src/layout/nib_layout_scope.dart';

Widget _host(Widget c) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: c),
    );

RenderNibMotion _render(WidgetTester tester) {
  RenderNibMotion? found;
  void visit(RenderObject o) {
    if (o is RenderNibMotion) found ??= o;
    o.visitChildren(visit);
  }

  tester.binding.rootElement!.renderObject!.visitChildren(visit);
  return found!;
}

const _kf = [
  NibKeyframe(at: 0, value: NibAnim(x: 0)),
  NibKeyframe(at: 1, value: NibAnim(x: 50)),
];

Future<NibMotionController> _mount(WidgetTester tester) async {
  final c = NibMotionController();
  addTearDown(c.dispose);
  await tester.pumpWidget(_host(NibMotionConfig(
    entranceWarmup: Duration.zero,
    child: NibMotion(
      controller: c,
      transition: const NibTransition(
          duration: Duration(milliseconds: 300), curve: Curves.linear),
      child: const SizedBox(width: 10, height: 10),
    ),
  )));
  return c;
}

void main() {
  group('keyframe playback is a proper driver', () {
    testWidgets('a second start(keyframes:) resolves the first future',
        (tester) async {
      final c = await _mount(tester);
      var first = false;
      c.start(keyframes: _kf).then((_) => first = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(first, isFalse);
      c.start(keyframes: _kf);
      await tester.pump();
      expect(first, isTrue, reason: 'superseded keyframe run must resolve');
      await tester.pumpAndSettle();
    });

    testWidgets('stop() halts a running keyframe animation', (tester) async {
      final c = await _mount(tester);
      var done = false;
      c.start(keyframes: _kf).then((_) => done = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      c.stop();
      final frozen = _render(tester).translateX.value;
      expect(frozen, inExclusiveRange(1.0, 49.0));
      await tester.pump();
      expect(done, isTrue, reason: 'stop resolves the pending future');
      await tester.pump(const Duration(milliseconds: 400));
      expect(_render(tester).translateX.value, frozen,
          reason: 'frozen means frozen');
    });

    testWidgets('animateTo after keyframes wins (newest target)',
        (tester) async {
      final c = await _mount(tester);
      c.start(keyframes: _kf);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      var done = false;
      c.start(target: const NibAnim(x: 5)).then((_) => done = true);
      await tester.pumpAndSettle();
      expect(done, isTrue);
      expect(_render(tester).translateX.value, closeTo(5, 0.01),
          reason: 'the keyframe run must not keep overriding the new target');
    });

    testWidgets('disposing mid-keyframes resolves the future', (tester) async {
      final c = await _mount(tester);
      var done = false;
      c.start(keyframes: _kf).then((_) => done = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(done, isTrue);
    });

    testWidgets('stop() also freezes a repeat loop', (tester) async {
      final c = NibMotionController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(NibMotionConfig(
        entranceWarmup: Duration.zero,
        child: NibMotion(
          controller: c,
          initial: const NibAnim(x: 0),
          animate: const NibAnim(x: 100),
          repeatAnimationInLoop: true,
          transition: const NibTransition(
              duration: Duration(milliseconds: 500), curve: Curves.linear),
          child: const SizedBox(width: 10, height: 10),
        ),
      )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      c.stop();
      final frozen = _render(tester).translateX.value;
      await tester.pump(const Duration(milliseconds: 130));
      expect(_render(tester).translateX.value, frozen);
    });
  });

  group('layout frame hook does not leak render objects', () {
    testWidgets('unmounting a layout box unregisters it', (tester) async {
      final before = NibLayoutFrameHook.registeredCount;
      await tester.pumpWidget(_host(Column(children: [
        for (var i = 0; i < 5; i++)
          NibMotion(
            key: ValueKey(i),
            layout: NibLayout.position,
            child: const SizedBox(width: 10, height: 10),
          ),
      ])));
      expect(NibLayoutFrameHook.registeredCount, before + 5);
      await tester.pumpWidget(const SizedBox());
      expect(NibLayoutFrameHook.registeredCount, before,
          reason: 'detached/disposed boxes must leave the static registry');
    });

    testWidgets('switching layout to none unregisters', (tester) async {
      final before = NibLayoutFrameHook.registeredCount;
      Widget build(NibLayout l) => _host(NibMotion(
            layout: l,
            child: const SizedBox(width: 10, height: 10),
          ));
      await tester.pumpWidget(build(NibLayout.both));
      expect(NibLayoutFrameHook.registeredCount, before + 1);
      await tester.pumpWidget(build(NibLayout.none));
      expect(NibLayoutFrameHook.registeredCount, before);
    });
  });

  group('layout scope snapshot registry does not grow without bound', () {
    testWidgets('stale ids of unmounted widgets are pruned', (tester) async {
      NibLayoutScopeData? data;
      Widget build(Iterable<int> ids) => _host(NibLayoutScope(
            child: Builder(builder: (context) {
              data = NibLayoutScope.maybeOf(context);
              return Column(children: [
                for (final id in ids)
                  NibMotion(
                    key: ValueKey(id),
                    layout: NibLayout.position,
                    layoutId: 'item-$id',
                    child: const SizedBox(width: 10, height: 2),
                  ),
              ]);
            }),
          ));
      await tester.pumpWidget(build(List.generate(100, (i) => i)));
      expect(data!.length, 100);
      await tester.pumpWidget(build(const []));
      // Let the snapshots expire, then churn a few new ids.
      await tester.pump(const Duration(seconds: 1));
      for (var i = 1000; i < 1004; i++) {
        await tester.pumpWidget(build([i]));
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(data!.length, lessThan(40),
          reason: 'expired snapshots of dead owners must be dropped '
              '(they also pin detached render objects in memory)');
    });
  });

  group('layout FLIP edge cases', () {
    for (final mode in NibLayoutSizeMode.values) {
      testWidgets('zero-size <-> sized transitions are finite ($mode)',
          (tester) async {
        Widget build(double w, double h) => _host(Column(children: [
              NibMotion(
                layout: NibLayout.both,
                layoutSizeMode: mode,
                child: SizedBox(width: w, height: h),
              ),
              const SizedBox(width: 5, height: 5),
            ]));
        for (final size in [
          const Size(0, 0),
          const Size(100, 40),
          const Size(0, 40),
          const Size(100, 0),
          const Size(30, 30),
        ]) {
          await tester.pumpWidget(build(size.width, size.height));
          await tester.pump(const Duration(milliseconds: 30));
          final r = _render(tester);
          for (final v in [r.scaleX.value, r.scaleY.value]) {
            expect(v.isFinite, isTrue);
          }
          expect(tester.takeException(), isNull);
        }
        await tester.pumpAndSettle();
      });
    }
  });

  group('RenderNibMotion rewires listeners when values are swapped', () {
    test('every property setter moves its listener to the new value', () {
      MotionValue<double> d() => MotionValue<double>(0);
      final opacity = MotionValue<double>(1);
      final tx = d(), ty = d(), sx = MotionValue<double>(1);
      final sy = MotionValue<double>(1), rot = d(), skx = d(), sky = d();
      final rx = d(), ry = d(), blur = d();
      final tint = MotionValue<Color?>(null);
      final color = MotionValue<Color?>(null);
      final radius = MotionValue<BorderRadius?>(null);
      final shadow = MotionValue<List<BoxShadow>?>(null);
      final render = RenderNibMotion(
        opacity: opacity,
        translateX: tx,
        translateY: ty,
        scaleX: sx,
        scaleY: sy,
        rotate: rot,
        skewX: skx,
        skewY: sky,
        rotateX: rx,
        rotateY: ry,
        blur: blur,
        tint: tint,
        color: color,
        borderRadius: radius,
        boxShadow: shadow,
      );
      final olds = <ChangeNotifier>[
        opacity,
        tx,
        ty,
        sx,
        sy,
        rot,
        skx,
        sky,
        rx,
        ry,
        blur,
        tint,
        color,
        radius,
        shadow,
      ];
      for (final o in olds) {
        expect((o as MotionValue).hasListeners, isTrue);
      }
      final newOpacity = MotionValue<double>(1);
      final news = <MotionValue>[
        newOpacity,
        d(),
        d(),
        MotionValue<double>(1),
        MotionValue<double>(1),
        d(),
        d(),
        d(),
        d(),
        d(),
        d(),
        MotionValue<Color?>(null),
        MotionValue<Color?>(null),
        MotionValue<BorderRadius?>(null),
        MotionValue<List<BoxShadow>?>(null),
      ];
      render
        ..opacity = news[0] as MotionValue<double>
        ..translateX = news[1] as MotionValue<double>
        ..translateY = news[2] as MotionValue<double>
        ..scaleX = news[3] as MotionValue<double>
        ..scaleY = news[4] as MotionValue<double>
        ..rotate = news[5] as MotionValue<double>
        ..skewX = news[6] as MotionValue<double>
        ..skewY = news[7] as MotionValue<double>
        ..rotateX = news[8] as MotionValue<double>
        ..rotateY = news[9] as MotionValue<double>
        ..blur = news[10] as MotionValue<double>
        ..tint = news[11] as MotionValue<Color?>
        ..color = news[12] as MotionValue<Color?>
        ..borderRadius = news[13] as MotionValue<BorderRadius?>
        ..boxShadow = news[14] as MotionValue<List<BoxShadow>?>;
      for (var i = 0; i < olds.length; i++) {
        expect((olds[i] as MotionValue).hasListeners, isFalse,
            reason: 'old value #$i still listened to');
        expect(news[i].hasListeners, isTrue,
            reason: 'new value #$i not listened to');
      }
      render.dispose();
      for (final n in news) {
        expect(n.hasListeners, isFalse, reason: 'dispose must detach');
      }
    });
  });

  group('external values outlive the widget safely', () {
    testWidgets('writing blur/rotate/tint after unmount does not throw',
        (tester) async {
      final blur = MotionValue<double>(0);
      final rx = MotionValue<double>(0);
      final ry = MotionValue<double>(0);
      final tint = MotionValue<Color?>(null);
      addTearDown(() {
        blur.dispose();
        rx.dispose();
        ry.dispose();
        tint.dispose();
      });
      await tester.pumpWidget(_host(NibMotion(
        motionValues:
            NibMotionValues(blur: blur, rotateX: rx, rotateY: ry, tint: tint),
        child: const SizedBox(width: 10, height: 10),
      )));
      await tester.pumpWidget(const SizedBox());
      for (final v in [blur, rx, ry]) {
        expect(v.hasListeners, isFalse,
            reason: 'the render object must detach from external values');
      }
      expect(tint.hasListeners, isFalse);
      blur.value = 4;
      rx.value = 0.1;
      ry.value = 0.1;
      tint.value = const Color(0x80FF0000);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}

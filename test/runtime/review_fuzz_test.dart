// Seeded fuzz/stress tests written during the correctness review. flutter_test
// itself fails on leaked tickers/timers and on any framework exception, so the
// assertions here are mostly "survives random abuse and every future settles".
import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _host(Widget child, {TextDirection dir = TextDirection.ltr}) =>
    Directionality(
      textDirection: dir,
      child: Align(alignment: Alignment.topLeft, child: child),
    );

NibAnim _randomAnim(Random r) => NibAnim(
      x: r.nextBool() ? r.nextDouble() * 200 - 100 : null,
      y: r.nextBool() ? r.nextDouble() * 200 - 100 : null,
      scale: r.nextBool() ? 0.5 + r.nextDouble() : null,
      rotate: r.nextBool() ? r.nextDouble() : null,
      rotateX: r.nextBool() ? r.nextDouble() * 0.3 : null,
      rotateY: r.nextBool() ? r.nextDouble() * 0.3 : null,
      blur: r.nextBool() ? r.nextDouble() * 8 : null,
      tint: r.nextBool() ? Color(0x00FF0000 | r.nextInt(0xFF) << 24) : null,
      opacity: r.nextBool() ? r.nextDouble() : null,
      color: r.nextBool() ? Color(0xFF000000 | r.nextInt(0xFFFFFF)) : null,
    );

NibTransition _randomTransition(Random r) {
  switch (r.nextInt(4)) {
    case 0:
      return NibTransition.springGentle;
    case 1:
      return NibTransition.springSnappy;
    case 2:
      return NibTransition(
        duration: Duration(milliseconds: 10 + r.nextInt(400)),
        delay: Duration(milliseconds: r.nextInt(3) * 40),
      );
    default:
      return NibTransition.springWith(
          duration: Duration(milliseconds: 100 + r.nextInt(500)),
          bounce: r.nextDouble() * 0.6);
  }
}

void main() {
  for (final seed in [1, 2, 3]) {
    testWidgets('controller fuzz seed $seed: every future settles',
        (tester) async {
      final r = Random(seed);
      final controllers = [for (var i = 0; i < 4; i++) NibMotionController()];
      await tester.pumpWidget(_host(NibMotionConfig(
        entranceWarmup: Duration.zero,
        child: Wrap(children: [
          for (final c in controllers)
            NibMotion(
              controller: c,
              whileTap: const NibAnim(scale: 0.9),
              reverseTransition: NibTransition.springSnappy,
              child: const SizedBox(width: 20, height: 20),
            ),
        ]),
      )));

      final futures = <Future<void>>[];
      var pending = 0;
      for (var step = 0; step < 150; step++) {
        final c = controllers[r.nextInt(controllers.length)];
        switch (r.nextInt(6)) {
          case 0:
          case 1:
          case 2:
            pending++;
            futures.add(c
                .start(target: _randomAnim(r), transition: _randomTransition(r))
                .whenComplete(() => pending--));
          case 3:
            c.stop();
          case 4:
            c.set(_randomAnim(r), keepVelocity: r.nextBool());
          case 5:
            pending++;
            futures.add(c.start(keyframes: [
              NibKeyframe(at: 0, value: _randomAnim(r)),
              NibKeyframe(
                  at: 0.5,
                  value: _randomAnim(r),
                  spring: NibSpringDescription.wobbly),
              NibKeyframe(at: 1, value: _randomAnim(r)),
            ], transition: _randomTransition(r)).whenComplete(() => pending--));
        }
        await tester.pump(Duration(milliseconds: r.nextInt(60)));
      }
      await tester.pumpAndSettle(const Duration(milliseconds: 50),
          EnginePhase.sendSemanticsUpdate, const Duration(seconds: 30));
      expect(pending, 0, reason: 'a future never completed');
      // Tear down mid-nothing: no exception, no leaked tickers.
      await tester.pumpWidget(const SizedBox());
      for (final c in controllers) {
        c.dispose();
      }
    });
  }

  testWidgets('dispose mid-animation resolves futures and leaks nothing',
      (tester) async {
    final c = NibMotionController();
    await tester.pumpWidget(_host(NibMotion(
      controller: c,
      layout: NibLayout.both,
      child: const SizedBox(width: 20, height: 20),
    )));
    var done = false;
    c
        .start(
            target: const NibAnim(x: 100, blur: 6, rotateY: 0.2),
            transition: NibTransition.springWobbly)
        .then((_) => done = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(done, isTrue);
    c.dispose();
  });

  for (final dir in TextDirection.values) {
    testWidgets('presence + layout fuzz ($dir)', (tester) async {
      final r = Random(7);
      var ids = <int>[0, 1, 2];
      var next = 3;
      var starts = 0, completes = 0, exits = 0, enters = 0;
      Widget build(List<int> ids, NibPresenceAxis axis) => _host(
            NibPresence.layout(
              key: ValueKey(axis),
              onAnimationStart: () => starts++,
              onAnimationComplete: () => completes++,
              onChildExit: (_) => exits++,
              onChildEnter: (_) => enters++,
              axis: axis,
              spacing: 4,
              runSpacing: 4,
              stagger: const Duration(milliseconds: 20),
              children: [
                for (final id in ids)
                  NibMotion(
                    key: ValueKey(id),
                    initial: const NibAnim(opacity: 0, y: 10),
                    animate: const NibAnim(opacity: 1, y: 0),
                    exit: const NibAnim(opacity: 0),
                    layout: NibLayout.both,
                    child: SizedBox(width: 20.0 + id % 3 * 10, height: 20),
                  ),
              ],
            ),
            dir: dir,
          );
      var axis = NibPresenceAxis.wrap;
      await tester.pumpWidget(build(ids, axis));
      for (var step = 0; step < 120; step++) {
        switch (r.nextInt(5)) {
          case 0:
            ids = [...ids, next++];
          case 1:
            if (ids.isNotEmpty) ids = [...ids]..removeAt(r.nextInt(ids.length));
          case 2:
            ids = [...ids]..shuffle(r);
          case 3:
            if (ids.length > 1) {
              ids = [...ids]..removeRange(0, r.nextInt(ids.length));
            }
          case 4:
            if (step % 25 == 0) {
              axis = NibPresenceAxis.values[r.nextInt(3)];
            }
        }
        await tester.pumpWidget(build(ids, axis));
        await tester.pump(Duration(milliseconds: r.nextInt(80)));
      }
      await tester.pumpAndSettle(const Duration(milliseconds: 50),
          EnginePhase.sendSemanticsUpdate, const Duration(seconds: 30));
      expect(find.byType(NibMotion), findsNWidgets(ids.length));
      expect(completes, starts,
          reason: 'every aggregate start is matched by one complete');
      expect(exits, greaterThan(0));
      expect(enters, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('layout FLIP while scrolling a list and inserting items',
      (tester) async {
    final r = Random(11);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    var ids = [for (var i = 0; i < 30; i++) i];
    var next = 30;
    Widget build() => _host(SizedBox(
          width: 200,
          height: 300,
          child: ListView(
            controller: scroll,
            children: [
              for (final id in ids)
                NibMotion(
                  key: ValueKey(id),
                  layout: NibLayout.both,
                  child: SizedBox(height: 30.0 + id % 4 * 10),
                ),
            ],
          ),
        ));
    await tester.pumpWidget(build());
    for (var step = 0; step < 80; step++) {
      switch (r.nextInt(4)) {
        case 0:
          ids = [...ids]..insert(r.nextInt(ids.length + 1), next++);
        case 1:
          if (ids.length > 5) ids = [...ids]..removeAt(r.nextInt(ids.length));
        case 2:
          if (scroll.hasClients) {
            scroll.jumpTo(r.nextDouble() * scroll.position.maxScrollExtent);
          }
        case 3:
          ids = [...ids]..shuffle(r);
      }
      await tester.pumpWidget(build());
      await tester.pump(Duration(milliseconds: r.nextInt(50)));
    }
    await tester.pumpAndSettle(const Duration(milliseconds: 50),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 30));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('rapid route push/pop with every route kind', (tester) async {
    final r = Random(5);
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Navigator(
        key: navKey,
        onGenerateRoute: (_) => PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) => const SizedBox.expand(),
        ),
      ),
    ));
    final results = <Future<Object?>>[];
    for (var step = 0; step < 60; step++) {
      final nav = navKey.currentState!;
      switch (r.nextInt(5)) {
        case 0:
          results.add(nav.push<Object?>(NibModalRoute<Object?>(
              builder: (_) => const SizedBox(width: 50, height: 50))));
        case 1:
          results.add(nav.push<Object?>(NibPageRoute<Object?>(
              backSwipe: r.nextBool(),
              builder: (_) => const SizedBox.expand())));
        case 2:
        case 3:
          if (nav.canPop()) nav.pop(step);
        case 4:
          if (nav.canPop()) {
            await nav.maybePop();
          }
      }
      await tester.pump(Duration(milliseconds: r.nextInt(120)));
    }
    while (navKey.currentState!.canPop()) {
      navKey.currentState!.pop();
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle(const Duration(milliseconds: 50),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 30));
    // Every pushed route's future must complete.
    var completed = 0;
    for (final f in results) {
      unawaited(f.then((_) => completed++));
    }
    await tester.pump();
    expect(completed, results.length);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('MultiSpringSolver / NibValueBuilder fuzz', (tester) async {
    final r = Random(9);
    final target = ValueNotifier<Offset>(Offset.zero);
    addTearDown(target.dispose);
    Widget build(bool show) => _host(show
        ? ValueListenableBuilder<Offset>(
            valueListenable: target,
            builder: (_, v, __) => NibValueBuilder<Offset>(
              target: v,
              converter: MotionConverter.offset,
              transition: r.nextBool() ? null : _randomTransition(r),
              builder: (_, o) => SizedBox(width: 10 + o.dx.abs() % 50),
            ),
          )
        : const SizedBox());
    await tester.pumpWidget(build(true));
    for (var i = 0; i < 100; i++) {
      target.value = Offset(r.nextDouble() * 300, r.nextDouble() * 300);
      await tester.pump(Duration(milliseconds: r.nextInt(50)));
      if (i % 30 == 29) {
        await tester.pumpWidget(build(false));
        await tester.pumpWidget(build(true));
      }
    }
    await tester.pumpWidget(build(false));
    await tester.pumpAndSettle();
  });
}

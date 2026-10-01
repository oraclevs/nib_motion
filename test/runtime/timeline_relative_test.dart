import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

const _ms100 = NibTransition(duration: Duration(milliseconds: 100));

NibTimelineEntry _abs(NibMotionController c, int atMs,
        {String? label, NibTransition? t = _ms100, NibAnim? from}) =>
    NibTimelineEntry(
        controller: c,
        target: const NibAnim(opacity: 1),
        at: Duration(milliseconds: atMs),
        transition: t,
        label: label,
        from: from);

Widget _box(NibMotionController c, Key key) => NibMotion(
      key: key,
      initial: const NibAnim(opacity: 0),
      controller: c,
      child: const SizedBox(width: 10, height: 10),
    );

double _opacity(WidgetTester tester, Key key) {
  RenderNibMotion? found;
  void visit(Element e) {
    if (found != null) return;
    if (e.renderObject is RenderNibMotion) {
      found = e.renderObject as RenderNibMotion;
      return;
    }
    e.visitChildren(visit);
  }

  visit(find.byKey(key).evaluate().single);
  return found!.opacity.value;
}

void main() {
  group('relative timing resolution', () {
    final c = NibMotionController();
    tearDownAll(c.dispose);

    test('after (previous), withStart, after(label), offsets', () {
      final t = NibTimeline([
        _abs(c, 0, label: 'a'),
        NibTimelineEntry.after(
            controller: c,
            target: const NibAnim(opacity: 1),
            transition: _ms100,
            offset: const Duration(milliseconds: 50),
            label: 'b'),
        NibTimelineEntry.withStart(
            controller: c,
            target: const NibAnim(opacity: 1),
            reference: 'a',
            offset: const Duration(milliseconds: 20),
            transition: _ms100,
            label: 'c'),
        NibTimelineEntry.after(
            controller: c,
            target: const NibAnim(opacity: 1),
            reference: 'b',
            transition: _ms100,
            label: 'd'),
      ]);
      final at = {for (final e in t.entries) e.label!: e.at.inMilliseconds};
      expect(at['a'], 0);
      expect(at['b'], 150, reason: 'a ends at 100, +50');
      expect(at['c'], 20);
      expect(at['d'], 250, reason: 'b starts 150, ends 250');
      expect(t.duration, const Duration(milliseconds: 350));
      t.dispose();
    });

    test('after with no reference and delay counts the previous delay', () {
      final t = NibTimeline([
        _abs(c, 100,
            t: const NibTransition(
                duration: Duration(milliseconds: 200),
                delay: Duration(milliseconds: 50))),
        NibTimelineEntry.after(
            controller: c,
            target: const NibAnim(opacity: 1),
            label: 'next',
            transition: _ms100),
      ]);
      expect(t.entries.last.at, const Duration(milliseconds: 350));
      t.dispose();
    });

    test('negative offset overlaps but never goes before zero', () {
      final t = NibTimeline([
        _abs(c, 0),
        NibTimelineEntry.after(
            controller: c,
            target: const NibAnim(opacity: 1),
            offset: const Duration(milliseconds: -30),
            transition: _ms100),
        NibTimelineEntry.after(
            controller: c,
            target: const NibAnim(opacity: 1),
            offset: const Duration(seconds: -5),
            transition: _ms100),
      ]);
      expect(t.entries.map((e) => e.at.inMilliseconds), [0, 0, 70]);
      t.dispose();
    });

    test('spring entries use the spring settle time', () {
      final e = NibTimelineEntry(
          controller: c,
          target: const NibAnim(opacity: 1),
          at: Duration.zero,
          transition: NibTransition.springGentle);
      final d = NibTimeline.entryDuration(e);
      expect(d, greaterThan(const Duration(milliseconds: 300)));
      expect(d, lessThan(const Duration(seconds: 5)));
      final stiff = NibTimeline.entryDuration(NibTimelineEntry(
          controller: c,
          target: const NibAnim(opacity: 1),
          at: Duration.zero,
          transition: NibTransition.springSnappy));
      expect(stiff, lessThan(d));
    });

    test('errors: unknown, later, duplicate label; after with no previous', () {
      expect(
          () => NibTimeline([
                NibTimelineEntry.after(
                    controller: c,
                    target: const NibAnim(opacity: 1),
                    reference: 'nope')
              ]),
          throwsArgumentError);
      expect(
          () => NibTimeline([
                NibTimelineEntry.withStart(
                    controller: c,
                    target: const NibAnim(opacity: 1),
                    reference: 'later'),
                _abs(c, 0, label: 'later'),
              ]),
          throwsArgumentError);
      expect(
          () => NibTimeline([_abs(c, 0, label: 'x'), _abs(c, 5, label: 'x')]),
          throwsArgumentError);
      expect(
          () => NibTimeline([
                NibTimelineEntry.after(
                    controller: c, target: const NibAnim(opacity: 1))
              ]),
          throwsArgumentError);
    });

    test('absolute-only timelines keep their entry objects (compat)', () {
      final a = _abs(c, 20);
      final b = _abs(c, 0);
      final t = NibTimeline([a, b]);
      expect(t.entries[0], same(b));
      expect(t.entries[1], same(a));
      t.dispose();
    });
  });

  group('play with relative entries', () {
    testWidgets('an .after entry fires when the previous one has finished',
        (tester) async {
      final ca = NibMotionController();
      final cb = NibMotionController();
      addTearDown(ca.dispose);
      addTearDown(cb.dispose);
      const ka = ValueKey('a');
      const kb = ValueKey('b');
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Column(children: [_box(ca, ka), _box(cb, kb)]),
      ));
      final t = NibTimeline([
        _abs(ca, 0),
        NibTimelineEntry.after(
            controller: cb,
            target: const NibAnim(opacity: 1),
            transition: _ms100),
      ]);
      t.play();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 40));
      expect(_opacity(tester, kb), 0, reason: 'b waits for a to finish');
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 50));
      expect(_opacity(tester, kb), greaterThan(0));
      await tester.pumpAndSettle();
      expect(_opacity(tester, kb), closeTo(1, 0.001));
      t.dispose();
    });

    testWidgets('play() future still never completes after stop()',
        (tester) async {
      final c = NibMotionController();
      addTearDown(c.dispose);
      await tester.pumpWidget(Directionality(
          textDirection: TextDirection.ltr,
          child: _box(c, const ValueKey('x'))));
      final t = NibTimeline([
        _abs(c, 500),
      ]);
      var done = false;
      t.play().then((_) => done = true);
      await tester.pump(const Duration(milliseconds: 100));
      t.stop();
      await tester.pump(const Duration(seconds: 2));
      expect(done, isFalse);
      t.dispose();
    });
  });

  group('scrubbing', () {
    testWidgets('seek interpolates entries that have `from`', (tester) async {
      final c = NibMotionController();
      addTearDown(c.dispose);
      const k = ValueKey('k');
      await tester.pumpWidget(
          Directionality(textDirection: TextDirection.ltr, child: _box(c, k)));
      final t = NibTimeline([
        _abs(c, 100,
            from: const NibAnim(opacity: 0),
            t: const NibTransition(
                duration: Duration(milliseconds: 200), curve: Curves.linear)),
      ]);
      expect(t.duration, const Duration(milliseconds: 300));

      t.seek(0);
      expect(_opacity(tester, k), 0);
      t.seek(0.5); // 150 ms: 50 ms into a 200 ms linear tween
      expect(_opacity(tester, k), closeTo(0.25, 0.01));
      expect(t.progress.value, 0.5);
      t.seek(1);
      expect(_opacity(tester, k), 1);
      t.seek(0.2); // scrub backwards: before start, back to `from`
      expect(_opacity(tester, k), 0);
      t.dispose();
    });

    testWidgets('entries without `from` derive it from the widget initial',
        (tester) async {
      final c = NibMotionController();
      addTearDown(c.dispose);
      const k = ValueKey('k');
      await tester.pumpWidget(
          Directionality(textDirection: TextDirection.ltr, child: _box(c, k)));
      final t = NibTimeline([_abs(c, 0)]);
      t.seek(0);
      expect(_opacity(tester, k), 0);
      t.seek(0.5);
      expect(_opacity(tester, k), closeTo(0.5, 0.01),
          reason: 'interpolates from the widget\'s initial opacity 0');
      t.seek(1);
      expect(_opacity(tester, k), 1);
      t.dispose();
    });

    testWidgets('seek clamps and cancels pending play timers', (tester) async {
      final c = NibMotionController();
      addTearDown(c.dispose);
      const k = ValueKey('k');
      await tester.pumpWidget(
          Directionality(textDirection: TextDirection.ltr, child: _box(c, k)));
      final t = NibTimeline([_abs(c, 500)]);
      t.play();
      t.seek(-3);
      expect(t.progress.value, 0);
      await tester.pump(const Duration(seconds: 2));
      expect(_opacity(tester, k), 0, reason: 'play timers were cancelled');
      t.seek(9);
      expect(t.progress.value, 1);
      t.dispose();
    });

    testWidgets('spring entries scrub along the spring curve', (tester) async {
      final c = NibMotionController();
      addTearDown(c.dispose);
      const k = ValueKey('k');
      await tester.pumpWidget(
          Directionality(textDirection: TextDirection.ltr, child: _box(c, k)));
      final t = NibTimeline([
        _abs(c, 0,
            from: const NibAnim(opacity: 0), t: NibTransition.springSnappy)
      ]);
      t.seek(0.3);
      final early = _opacity(tester, k);
      t.seek(0.9);
      final late = _opacity(tester, k);
      expect(early, greaterThan(0.3), reason: 'spring is well under way');
      expect(early, isNot(closeTo(late, 0.005)),
          reason: 'shaped by the spring curve, not a step');
      expect(late, closeTo(1, 0.02), reason: 'settled by 90% of duration');
      t.dispose();
    });

    testWidgets('NibTimelineScrubber drives seek and mirrors progress',
        (tester) async {
      final c = NibMotionController();
      addTearDown(c.dispose);
      const k = ValueKey('k');
      final t = NibTimeline([
        _abs(c, 0,
            from: const NibAnim(opacity: 0),
            t: const NibTransition(
                duration: Duration(milliseconds: 200), curve: Curves.linear)),
      ]);
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 400,
          child: Column(children: [
            _box(c, k),
            NibTimelineScrubber(timeline: t),
          ]),
        ),
      ));
      expect(find.text('0 / 200 ms'), findsOneWidget);
      await tester
          .tap(find.byKey(const ValueKey('nib_timeline_scrubber_track')));
      await tester.pump();
      expect(t.progress.value, closeTo(0.5, 0.05));
      expect(_opacity(tester, k), closeTo(0.5, 0.06));
      t.seek(1);
      await tester.pump();
      expect(find.text('200 / 200 ms'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      t.dispose();
    });
  });
}

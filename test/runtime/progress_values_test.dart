import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _list(NibViewportProgressController c, ScrollController s,
    {int before = 10}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(400, 600)),
      child: SizedBox(
        width: 400,
        height: 600,
        child: ListView(
          controller: s,
          children: [
            for (var i = 0; i < before; i++) const SizedBox(height: 100),
            NibViewportProgress(
              controller: c,
              child: const SizedBox(height: 100, width: 400),
            ),
            const SizedBox(height: 3000),
          ],
        ),
      ),
    ),
  );
}

void main() {
  group('NibViewportProgress', () {
    testWidgets('progress runs 0 → 0.5 → 1 as the child crosses the viewport',
        (tester) async {
      final c = NibViewportProgressController();
      final s = ScrollController();
      addTearDown(() {
        c.dispose();
        s.dispose();
      });
      await tester.pumpWidget(_list(c, s));
      await tester.pump();
      // Child at y=1000, viewport 0..600: below the fold.
      expect(c.progress.value, 0.0);
      expect(c.visibleFraction.value, 0.0);

      // Scroll so the child's centre is at the viewport centre: top at 250.
      s.jumpTo(750);
      await tester.pump();
      await tester.pump();
      expect(c.progress.value, closeTo(0.5, 0.01));
      expect(c.visibleFraction.value, 1.0);

      // Fully scrolled past.
      s.jumpTo(1200);
      await tester.pump();
      await tester.pump();
      expect(c.progress.value, 1.0);
      expect(c.visibleFraction.value, 0.0);
    });

    testWidgets('half-visible at the fold', (tester) async {
      final c = NibViewportProgressController();
      final s = ScrollController();
      addTearDown(() {
        c.dispose();
        s.dispose();
      });
      await tester.pumpWidget(_list(c, s));
      s.jumpTo(450); // child top at 550: 50 of 100 px visible
      await tester.pump();
      await tester.pump();
      expect(c.visibleFraction.value, closeTo(0.5, 0.01));
    });

    testWidgets('scrolling never rebuilds the child subtree', (tester) async {
      var builds = 0;
      final c = NibViewportProgressController();
      final s = ScrollController();
      addTearDown(() {
        c.dispose();
        s.dispose();
      });
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(400, 600)),
          child: SizedBox(
            width: 400,
            height: 600,
            child: ListView(controller: s, children: [
              const SizedBox(height: 700),
              NibViewportProgress(
                controller: c,
                child: Builder(builder: (_) {
                  builds++;
                  return const SizedBox(height: 100);
                }),
              ),
              const SizedBox(height: 3000),
            ]),
          ),
        ),
      ));
      final mounted = builds;
      for (var y = 0.0; y < 1000; y += 50) {
        s.jumpTo(y);
        await tester.pump();
      }
      expect(builds, mounted);
      expect(c.progress.value, greaterThan(0));
    });

    testWidgets('nested scrollables: outer scroll moves an inner-list child',
        (tester) async {
      final c = NibViewportProgressController();
      final outer = ScrollController();
      addTearDown(() {
        c.dispose();
        outer.dispose();
      });
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(400, 600)),
          child: SizedBox(
            width: 400,
            height: 600,
            child: ListView(controller: outer, children: [
              const SizedBox(height: 1000),
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    NibViewportProgress(
                      controller: c,
                      child: const SizedBox(width: 100, height: 100),
                    ),
                    const SizedBox(width: 2000),
                  ],
                ),
              ),
              const SizedBox(height: 3000),
            ]),
          ),
        ),
      ));
      await tester.pump();
      // Inner list is horizontal & the child sits at its left edge, fully
      // inside it: visibility is measured against the inner viewport, which
      // itself is off-screen, so it reports the inner-viewport relationship.
      final before = c.progress.value;
      outer.jumpTo(900);
      await tester.pump();
      await tester.pump();
      expect(c.visibleFraction.value, closeTo(1.0, 0.01));
      expect(c.progress.value, isNot(before),
          reason: 'moving the *outer* scroll view must trigger a re-measure');
    });

    testWidgets('detaches listeners on dispose', (tester) async {
      final c = NibViewportProgressController();
      final s = ScrollController();
      addTearDown(() {
        c.dispose();
        s.dispose();
      });
      await tester.pumpWidget(_list(c, s));
      await tester.pumpWidget(const SizedBox());
      expect(s.hasClients, isFalse);
    });
  });

  group('NibPageProgress', () {
    testWidgets('follows the fractional page', (tester) async {
      final pc = PageController();
      final p = NibPageProgress(pc);
      addTearDown(() {
        p.dispose();
        pc.dispose();
      });
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              height: 600,
              child: PageView(controller: pc, children: [
                for (var i = 0; i < 3; i++) const SizedBox(),
              ]),
            )),
      ));
      expect(p.page.value, 0.0);
      final c0 = p.closeness(0);
      final c1 = p.closeness(1);
      final off = p.offsetFrom(1);
      pc.jumpTo(200); // half a page
      await tester.pump();
      expect(p.page.value, closeTo(0.5, 1e-6));
      expect(c0.value, closeTo(0.5, 1e-6));
      expect(c1.value, closeTo(0.5, 1e-6));
      expect(off.value, closeTo(-0.5, 1e-6));
      pc.jumpTo(800);
      await tester.pump();
      expect(p.closeness(2).value, 1.0);
      expect(c0.value, 0.0);
      c0.dispose();
      c1.dispose();
      off.dispose();
    });

    testWidgets('initialPage is honoured before attach', (tester) async {
      final pc = PageController(initialPage: 2);
      final p = NibPageProgress(pc);
      expect(p.page.value, 2.0);
      p.dispose();
      pc.dispose();
    });

    testWidgets('dispose stops following (no use-after-dispose)',
        (tester) async {
      final pc = PageController();
      final p = NibPageProgress(pc);
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child:
            PageView(controller: pc, children: const [SizedBox(), SizedBox()]),
      ));
      p.dispose();
      pc.jumpTo(100); // would throw if the listener were still attached
      await tester.pump();
      expect(tester.takeException(), isNull);
      pc.dispose();
    });
  });
}

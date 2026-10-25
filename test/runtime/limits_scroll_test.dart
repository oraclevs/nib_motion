import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _host(NibViewportProgressController c, ScrollController s,
    {bool reverse = false,
    Axis axis = Axis.vertical,
    TextDirection dir = TextDirection.ltr}) {
  final vertical = axis == Axis.vertical;
  return Directionality(
    textDirection: dir,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(400, 600)),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: vertical ? 400 : 600,
          height: vertical ? 600 : 400,
          child: ListView(
            controller: s,
            // Build everything up front: a lazily built item does not exist
            // before it scrolls near, so there is nothing to measure yet.
            // ignore: deprecated_member_use
            cacheExtent: 100000,
            reverse: reverse,
            scrollDirection: axis,
            children: [
              for (var i = 0; i < 10; i++)
                SizedBox(
                    width: vertical ? 400 : 100, height: vertical ? 100 : 400),
              NibViewportProgress(
                controller: c,
                child: SizedBox(
                    width: vertical ? 400 : 100, height: vertical ? 100 : 400),
              ),
              SizedBox(
                  width: vertical ? 400 : 3000, height: vertical ? 3000 : 400),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('NibViewportProgress: no lag', () {
    testWidgets('progress is correct synchronously, before any frame',
        (tester) async {
      final c = NibViewportProgressController();
      final s = ScrollController();
      addTearDown(() {
        c.dispose();
        s.dispose();
      });
      await tester.pumpWidget(_host(c, s));
      await tester.pump();
      s.jumpTo(750); // no pump: the listener must already have published
      expect(c.progress.value, closeTo(0.5, 0.01));
      s.jumpTo(1200);
      expect(c.progress.value, 1.0);
      s.jumpTo(0);
      expect(c.progress.value, 0.0);
    });

    testWidgets('visibleFraction is also synchronous', (tester) async {
      final c = NibViewportProgressController();
      final s = ScrollController();
      addTearDown(() {
        c.dispose();
        s.dispose();
      });
      await tester.pumpWidget(_host(c, s));
      await tester.pump();
      s.jumpTo(450);
      expect(c.visibleFraction.value, closeTo(0.5, 0.01));
    });

    testWidgets('an outer scrollable moving an inner-list child is synchronous',
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
            child: ListView(
              controller: outer,
              // ignore: deprecated_member_use
              cacheExtent: 100000,
              children: [
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
                    ],
                  ),
                ),
                const SizedBox(height: 3000),
              ],
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(c.visibleFraction.value, 0.0);
      outer.jumpTo(750);
      // The child sits at x 0..100 of a 400-wide inner list: horizontal
      // progress is 0.5-ish only once the inner axis applies; what matters
      // here is that the outer scroll made it visible without a frame.
      expect(c.visibleFraction.value, greaterThan(0.0));
    });
  });

  group('NibViewportProgress: axis directions', () {
    testWidgets('reverse:true list progresses 0 → 0.5 → 1 with scroll',
        (tester) async {
      final c = NibViewportProgressController();
      final s = ScrollController();
      addTearDown(() {
        c.dispose();
        s.dispose();
      });
      await tester.pumpWidget(_host(c, s, reverse: true));
      await tester.pump();
      expect(c.progress.value, 0.0);
      s.jumpTo(750);
      await tester.pump();
      expect(c.progress.value, closeTo(0.5, 0.02));
      expect(c.visibleFraction.value, 1.0);
      s.jumpTo(1200);
      await tester.pump();
      expect(c.progress.value, 1.0);
      expect(c.visibleFraction.value, 0.0);
    });

    testWidgets('RTL horizontal list progresses 0 → 0.5 → 1 with scroll',
        (tester) async {
      final c = NibViewportProgressController();
      final s = ScrollController();
      addTearDown(() {
        c.dispose();
        s.dispose();
      });
      await tester.pumpWidget(
          _host(c, s, axis: Axis.horizontal, dir: TextDirection.rtl));
      await tester.pump();
      expect(c.progress.value, 0.0);
      s.jumpTo(750);
      await tester.pump();
      expect(c.progress.value, closeTo(0.5, 0.02));
      expect(c.visibleFraction.value, 1.0);
      s.jumpTo(1200);
      await tester.pump();
      expect(c.progress.value, 1.0);
    });

    testWidgets('reverse:true horizontal LTR also follows scroll direction',
        (tester) async {
      final c = NibViewportProgressController();
      final s = ScrollController();
      addTearDown(() {
        c.dispose();
        s.dispose();
      });
      await tester
          .pumpWidget(_host(c, s, axis: Axis.horizontal, reverse: true));
      await tester.pump();
      s.jumpTo(750);
      await tester.pump();
      expect(c.progress.value, closeTo(0.5, 0.02));
    });
  });
}

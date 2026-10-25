import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _wrap(Widget child, {TextDirection dir = TextDirection.ltr}) =>
    Directionality(
      textDirection: dir,
      child: Align(alignment: Alignment.topLeft, child: child),
    );

Widget _item(String id, {double h = 50, double w = 100}) => NibMotion(
      key: ValueKey('m-$id'),
      layout: NibLayout.position,
      child: SizedBox(key: ValueKey(id), width: w, height: h),
    );

Offset _painted(WidgetTester tester, String id) => tester
    .renderObject<RenderBox>(find.byKey(ValueKey(id)))
    .localToGlobal(Offset.zero);

List<RenderNibMotion> _allMotions(WidgetTester tester) {
  final found = <RenderNibMotion>[];
  void visit(RenderObject o) {
    if (o is RenderNibMotion) found.add(o);
    o.visitChildren(visit);
  }

  tester.binding.rootElement!.renderObject!.visitChildren(visit);
  return found;
}

void main() {
  group('reversed ListView', () {
    Widget list(List<String> ids, {ScrollController? controller}) =>
        _wrap(SizedBox(
          width: 100,
          height: 300,
          child: NibLayoutScope(
            child: ListView(
              reverse: true,
              controller: controller,
              children: [for (final id in ids) _item(id)],
            ),
          ),
        ));

    testWidgets(
        'inserting at the leading edge FLIPs the items above it '
        'in the right direction', (tester) async {
      await tester.pumpWidget(list(['a', 'b']));
      await tester.pumpAndSettle();
      // index 0 sits at the bottom of a reversed list.
      final a0 = _painted(tester, 'a').dy;
      final b0 = _painted(tester, 'b').dy;
      expect(a0, 250);
      expect(b0, 200);

      await tester.pumpWidget(list(['new', 'a', 'b']));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 50));
      // Layout moved `a` 250 -> 200 and `b` 200 -> 150. Mid-flight each must
      // be strictly between its old and new slot (wrong-signed FLIPs leave
      // the box outside that range).
      expect(_painted(tester, 'a').dy, inExclusiveRange(201.0, 249.0));
      expect(_painted(tester, 'b').dy, inExclusiveRange(151.0, 199.0));
      await tester.pumpAndSettle();
      expect(_painted(tester, 'a').dy, closeTo(200, 0.1));
      expect(_painted(tester, 'b').dy, closeTo(150, 0.1));
      expect(_painted(tester, 'new').dy, closeTo(250, 0.1));
    });

    testWidgets('scrolling a reversed list is not layout movement',
        (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
          list([for (var i = 0; i < 20; i++) 'i$i'], controller: controller));
      await tester.pumpAndSettle();
      controller.jumpTo(120);
      await tester.pump();
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      // i3 (a visible item) rests at 250 - 3 * 50 plus the scroll offset.
      expect(_painted(tester, 'i3').dy, closeTo(100 + 120, 0.01));
    });
  });

  group('reversed horizontal list', () {
    Widget list(List<String> ids) => _wrap(SizedBox(
          width: 300,
          height: 100,
          child: NibLayoutScope(
            child: ListView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              children: [for (final id in ids) _item(id, w: 50, h: 100)],
            ),
          ),
        ));

    testWidgets('inserting at the leading (right) edge FLIPs leftwards',
        (tester) async {
      await tester.pumpWidget(list(['a']));
      await tester.pumpAndSettle();
      expect(_painted(tester, 'a').dx, 250);
      await tester.pumpWidget(list(['new', 'a']));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 50));
      expect(_painted(tester, 'a').dx, inExclusiveRange(201.0, 249.0));
      await tester.pumpAndSettle();
      expect(_painted(tester, 'a').dx, closeTo(200, 0.1));
    });
  });

  group('RTL grid (reversed cross axis)', () {
    Widget grid(List<String> ids) => _wrap(
          SizedBox(
            width: 200,
            height: 300,
            child: NibLayoutScope(
              child: GridView.count(
                crossAxisCount: 2,
                children: [for (final id in ids) _item(id, w: 100, h: 100)],
              ),
            ),
          ),
          dir: TextDirection.rtl,
        );

    testWidgets('a reorder FLIPs along the visible direction', (tester) async {
      await tester.pumpWidget(grid(['a', 'b']));
      await tester.pumpAndSettle();
      // RTL: first item at the right.
      expect(_painted(tester, 'a').dx, 100);
      expect(_painted(tester, 'b').dx, 0);
      await tester.pumpWidget(grid(['b', 'a']));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 50));
      expect(_painted(tester, 'a').dx, inExclusiveRange(1.0, 99.0),
          reason: 'a travels from the right slot to the left one');
      await tester.pumpAndSettle();
      expect(_painted(tester, 'a').dx, closeTo(0, 0.1));
      expect(_painted(tester, 'b').dx, closeTo(100, 0.1));
    });
  });

  group('center-keyed CustomScrollView (reverse-growth sliver)', () {
    final center = GlobalKey();

    Widget scroll(List<String> before, List<String> after,
            ScrollController controller) =>
        _wrap(SizedBox(
          width: 100,
          height: 300,
          child: NibLayoutScope(
            child: CustomScrollView(
              controller: controller,
              center: center,
              slivers: [
                SliverList(
                  delegate: SliverChildListDelegate(
                      [for (final id in before) _item(id)]),
                ),
                SliverList(
                  key: center,
                  delegate: SliverChildListDelegate(
                      [for (final id in after) _item(id)]),
                ),
              ],
            ),
          ),
        ));

    testWidgets(
        'inserting next to the centre FLIPs only the sliver that '
        'moved', (tester) async {
      final controller = ScrollController(initialScrollOffset: -150);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
          scroll(['p1', 'p2', 'p3', 'p4', 'p5'], ['c1', 'c2'], controller));
      await tester.pumpAndSettle();
      // Centre line at y=150: `before` children stack upwards from it.
      expect(_painted(tester, 'c1').dy, 150);
      expect(_painted(tester, 'p1').dy, 100);
      expect(_painted(tester, 'p2').dy, 50);
      expect(_painted(tester, 'p3').dy, 0);

      await tester
          .pumpWidget(scroll(['pNew', 'p1', 'p2'], ['c1', 'c2'], controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 50));
      // p1: 100 -> 50, p2: 50 -> 0. Strictly in between mid-flight.
      expect(_painted(tester, 'p1').dy, inExclusiveRange(51.0, 99.0));
      expect(_painted(tester, 'p2').dy, inExclusiveRange(1.0, 49.0));
      // The centre sliver did not move: no FLIP for it.
      expect(_painted(tester, 'c1').dy, 150);
      expect(_painted(tester, 'c2').dy, 200);
      await tester.pumpAndSettle();
      expect(_painted(tester, 'p1').dy, closeTo(50, 0.1));
      expect(_painted(tester, 'p2').dy, closeTo(0, 0.1));
      expect(_painted(tester, 'pNew').dy, closeTo(100, 0.1));
    });

    testWidgets('scrolling across the centre is not layout movement',
        (tester) async {
      final controller = ScrollController(initialScrollOffset: -150);
      addTearDown(controller.dispose);
      await tester.pumpWidget(scroll([for (var i = 0; i < 6; i++) 'p$i'],
          [for (var i = 0; i < 6; i++) 'c$i'], controller));
      await tester.pumpAndSettle();
      for (final offset in [60.0, -100.0, 120.0, -20.0]) {
        controller.jumpTo(offset);
        await tester.pump();
        await tester.pump();
        // (The scroll position itself may still be settling its physics;
        // what must stay at rest is every item's FLIP.)
        for (final render in _allMotions(tester)) {
          final c = render.layoutChannels!;
          expect(c.x.value, 0, reason: 'x at offset $offset');
          expect(c.y.value, 0, reason: 'y at offset $offset');
          expect(c.scaleX.value, 1);
          expect(c.scaleY.value, 1);
        }
      }
    });
  });
}

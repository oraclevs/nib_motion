import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _wrap(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: child),
    );

Widget _item(String id,
        {double h = 50, NibLayout layout = NibLayout.inherit}) =>
    NibMotion(
      key: ValueKey('m-$id'),
      layout: layout,
      child: SizedBox(key: ValueKey(id), width: 100, height: h),
    );

Offset _painted(WidgetTester tester, String id) => tester
    .renderObject<RenderBox>(find.byKey(ValueKey(id)))
    .localToGlobal(Offset.zero);

void main() {
  group('RepaintBoundary between the scope and a moving NibMotion', () {
    Widget host(bool above) => _wrap(NibLayoutScope(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (above)
              const SizedBox(key: ValueKey('top'), width: 100, height: 40),
            RepaintBoundary(
              key: const ValueKey('rb'), // keeps the element across the insert
              child: _item('a', layout: NibLayout.position),
            ),
          ]),
        ));

    testWidgets('a move that never repaints the child is still FLIPped',
        (tester) async {
      await tester.pumpWidget(host(false));
      await tester.pumpAndSettle();
      expect(_painted(tester, 'a').dy, 0);

      await tester.pumpWidget(host(true));
      // The boundary re-composites the child without repainting it, so the
      // move is found by the frame hook and the FLIP starts one frame late.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 60));
      expect(_painted(tester, 'a').dy, inExclusiveRange(1.0, 39.0),
          reason: 'travelling to the new slot');
      await tester.pumpAndSettle();
      expect(_painted(tester, 'a').dy, closeTo(40, 0.1));
    });
  });

  group('lazy lists / slivers', () {
    Widget list(List<String> ids,
            {ScrollController? controller, Map<String, double>? heights}) =>
        _wrap(SizedBox(
          width: 100,
          height: 300,
          child: NibLayoutScope(
            child: ListView(
              controller: controller,
              children: [
                for (final id in ids)
                  _item(id, h: heights?[id] ?? 50, layout: NibLayout.position),
              ],
            ),
          ),
        ));

    testWidgets('inserting above a visible item FLIPs it', (tester) async {
      await tester.pumpWidget(list(['a', 'b']));
      await tester.pumpAndSettle();
      expect(_painted(tester, 'a').dy, 0);

      await tester.pumpWidget(list(['new', 'a', 'b']));
      // ListView items sit in their own RepaintBoundary, so the move is found
      // by the frame hook one frame late (documented limitation).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 50));
      // `a` moved 0 -> 50 in layout; it must be travelling, not already there.
      expect(_painted(tester, 'a').dy, inExclusiveRange(1.0, 49.0));
      await tester.pumpAndSettle();
      expect(_painted(tester, 'a').dy, closeTo(50, 0.1));
      expect(_painted(tester, 'b').dy, closeTo(100, 0.1));
    });

    testWidgets('a resize above shifts following items with a FLIP',
        (tester) async {
      await tester.pumpWidget(list(['a', 'b']));
      await tester.pumpAndSettle();
      await tester.pumpWidget(list(['a', 'b'], heights: {'a': 120}));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 50));
      expect(_painted(tester, 'b').dy, inExclusiveRange(51.0, 119.0));
      await tester.pumpAndSettle();
      expect(_painted(tester, 'b').dy, closeTo(120, 0.1));
    });

    testWidgets('scrolling is not layout movement: no FLIP', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
          list([for (var i = 0; i < 20; i++) 'i$i'], controller: controller));
      await tester.pumpAndSettle();
      controller.jumpTo(120);
      await tester.pump();
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(_painted(tester, 'i3').dy, closeTo(3 * 50 - 120, 0.01));
      controller.animateTo(400,
          duration: const Duration(milliseconds: 200), curve: Curves.linear);
      await tester.pumpAndSettle();
      expect(_painted(tester, 'i10').dy, closeTo(10 * 50 - 400, 0.01));
    });

    testWidgets('items created by scrolling do not FLIP on arrival',
        (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
          list([for (var i = 0; i < 40; i++) 'i$i'], controller: controller));
      controller.jumpTo(1000);
      await tester.pump();
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('NibLayoutDefaults opt-out', () {
    Widget host(double top) => _wrap(NibLayoutScope(
          child: NibLayoutDefaults(
            layout: NibLayout.position,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 100, height: top),
              _item('inherits'),
              _item('optsOut', layout: NibLayout.none),
            ]),
          ),
        ));

    testWidgets('explicit NibLayout.none ignores the inherited default',
        (tester) async {
      await tester.pumpWidget(host(0));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(40));
      await tester.pump();
      expect(_painted(tester, 'inherits').dy, closeTo(0, 0.5),
          reason: 'inherits position FLIP from the defaults');
      expect(_painted(tester, 'optsOut').dy, closeTo(90, 0.01),
          reason: 'jumped straight to its new slot');
      await tester.pumpAndSettle();
    });
  });
}

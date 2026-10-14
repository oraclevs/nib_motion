import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _wrap(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: child),
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

Widget _grower(double width,
    {NibLayoutSizeMode mode = NibLayoutSizeMode.clip,
    VoidCallback? onTap,
    NibTransition? transition}) {
  return _wrap(NibMotion(
    layout: NibLayout.size,
    layoutSizeMode: mode,
    layoutTransition: transition,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(key: const ValueKey('box'), width: width, height: 50),
    ),
  ));
}

void main() {
  group('layoutSizeMode: clip', () {
    testWidgets('grow: child keeps its size (no scale), clip reveals it',
        (tester) async {
      await tester.pumpWidget(_grower(50));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_grower(150));
      await tester.pump();
      final render = _render(tester);

      // Not stretched: the transform contains no scale.
      final m = render.transform.storage;
      expect(m[0], closeTo(1.0, 1e-9));
      expect(m[5], closeTo(1.0, 1e-9));
      final box =
          tester.renderObject<RenderBox>(find.byKey(const ValueKey('box')));
      expect(box.size.width, 150, reason: 'laid out at its final size');
      final rect = render.layoutClipRect;
      expect(rect, isNotNull);
      expect(rect!.width, closeTo(50, 1));
      expect(rect.height, closeTo(50, 1));

      await tester.pump(const Duration(milliseconds: 80));
      final mid = render.layoutClipRect;
      expect(mid, isNotNull);
      expect(mid!.width, inExclusiveRange(51, 149));

      await tester.pumpAndSettle();
      expect(render.layoutClipRect, isNull, reason: 'settled: no clip');
      expect(render.transform.isIdentity(), isTrue);
    });

    testWidgets('scale mode still scales (regression guard)', (tester) async {
      await tester.pumpWidget(_grower(50, mode: NibLayoutSizeMode.scale));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_grower(150, mode: NibLayoutSizeMode.scale));
      await tester.pump();
      final render = _render(tester);
      expect(render.transform.storage[0], lessThan(0.5));
      expect(render.layoutClipRect, isNull);
      await tester.pumpAndSettle();
    });

    testWidgets('hit testing follows the clip, not the final box',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_grower(50, onTap: () => taps++));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_grower(150, onTap: () => taps++));
      await tester.pump();

      await tester.tapAt(const Offset(120, 25)); // in final box, outside clip
      expect(taps, 0);
      await tester.tapAt(const Offset(25, 25)); // inside clip
      expect(taps, 1);

      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(120, 25));
      expect(taps, 2);
    });

    testWidgets('semantics clip matches the visible clip', (tester) async {
      await tester.pumpWidget(_grower(50));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_grower(150));
      await tester.pump();
      final render = _render(tester);
      final clip = render.describeApproximatePaintClip(render.child!);
      expect(clip, isNotNull);
      expect(clip!.width, closeTo(50, 1));
      await tester.pumpAndSettle();
      expect(render.describeApproximatePaintClip(render.child!), isNull);
    });

    testWidgets('shrinking never clips (only new content exists)',
        (tester) async {
      await tester.pumpWidget(_grower(150));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_grower(50));
      await tester.pump();
      final rect = _render(tester).layoutClipRect;
      // A clip wider than the box hides nothing.
      expect(rect == null || rect.width >= 50, isTrue);
      await tester.pumpAndSettle();
      expect(_render(tester).layoutClipRect, isNull);
    });

    testWidgets('interrupting a clip animation continues from the painted clip',
        (tester) async {
      await tester.pumpWidget(_grower(50));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_grower(150));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final before = _render(tester).layoutClipRect!.width;
      await tester.pumpWidget(_grower(250));
      await tester.pump();
      expect(_render(tester).layoutClipRect!.width, closeTo(before, 1.5));
      await tester.pumpAndSettle();
    });
  });

  group('layoutTransition.delay', () {
    testWidgets('the inverted state holds until the delay elapses',
        (tester) async {
      Widget host(double x) => _wrap(SizedBox(
            width: 300,
            height: 60,
            child: Stack(children: [
              Positioned(
                left: x,
                child: const NibMotion(
                  layout: NibLayout.position,
                  layoutTransition: NibTransition(
                      duration: Duration(milliseconds: 100),
                      delay: Duration(milliseconds: 500)),
                  child: SizedBox(key: ValueKey('b'), width: 20, height: 20),
                ),
              ),
            ]),
          ));
      await tester.pumpWidget(host(0));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(100));
      await tester.pump();
      Offset painted() => tester
          .renderObject<RenderBox>(find.byKey(const ValueKey('b')))
          .localToGlobal(Offset.zero);
      await tester.pump(const Duration(milliseconds: 300));
      expect(painted().dx, closeTo(0, 0.5), reason: 'still waiting');
      await tester.pump(const Duration(milliseconds: 300)); // delay over
      await tester.pump(const Duration(milliseconds: 60));
      expect(painted().dx, inExclusiveRange(1, 99), reason: 'now moving');
      await tester.pumpAndSettle();
      expect(painted().dx, closeTo(100, 0.5));
    });
  });
}

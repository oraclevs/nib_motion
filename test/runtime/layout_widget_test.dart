import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _wrap(Widget child, {TextDirection dir = TextDirection.ltr}) =>
    Directionality(
      textDirection: dir,
      child: Align(alignment: Alignment.topLeft, child: child),
    );

Widget _item(String id,
        {double w = 50,
        double h = 50,
        NibLayout layout = NibLayout.position,
        NibTransition? t}) =>
    NibMotion(
      key: ValueKey('m-$id'),
      layout: layout,
      layoutTransition: t,
      child: SizedBox(key: ValueKey(id), width: w, height: h),
    );

/// Painted global top-left of the SizedBox with [id] (includes the NibMotion
/// layout transform because the SizedBox is a child of it).
Offset _painted(WidgetTester tester, String id) => tester
    .renderObject<RenderBox>(find.byKey(ValueKey(id)))
    .localToGlobal(Offset.zero);

/// Painted size of the SizedBox with [id].
Size _paintedSize(WidgetTester tester, String id) {
  final box = tester.renderObject<RenderBox>(find.byKey(ValueKey(id)));
  final r = MatrixUtils.transformRect(
      box.getTransformTo(null), Offset.zero & box.size);
  return r.size;
}

void main() {
  group('NibMotion layout: position', () {
    testWidgets('Wrap reorder FLIPs with no first-frame flash', (tester) async {
      Widget host(List<String> ids) => _wrap(SizedBox(
          width: 100,
          child: Wrap(children: [for (final id in ids) _item(id)])));
      await tester.pumpWidget(host(['a', 'b', 'c']));
      await tester.pumpAndSettle();
      expect(_painted(tester, 'c'), const Offset(0, 50));
      await tester.pumpWidget(host(['c', 'a', 'b']));
      await tester.pump();
      // c jumped to slot 0 in layout, but is painted where it was.
      expect(_painted(tester, 'c').dy, closeTo(50, 0.5));
      expect(_painted(tester, 'c').dx, closeTo(0, 0.5));
      // a moved from slot 0 to slot 1 (x 0 -> 50): painted still at 0.
      expect(_painted(tester, 'a').dx, closeTo(0, 0.5));
      await tester.pumpAndSettle();
      expect(_painted(tester, 'c'), const Offset(0, 0));
      expect(_painted(tester, 'a'), const Offset(50, 0));
      expect(_painted(tester, 'b'), const Offset(0, 50));
    });

    testWidgets('Stack reposition animates in place of jumping',
        (tester) async {
      Widget host(double left) => _wrap(SizedBox(
          width: 400,
          height: 100,
          child: Stack(children: [
            Positioned(left: left, top: 0, child: _item('a')),
          ])));
      await tester.pumpWidget(host(0));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(200));
      await tester.pump();
      expect(_painted(tester, 'a').dx, closeTo(0, 0.5));
      await tester.pump(const Duration(milliseconds: 100));
      final mid = _painted(tester, 'a').dx;
      expect(mid, inExclusiveRange(1, 199));
      await tester.pumpAndSettle();
      expect(_painted(tester, 'a').dx, closeTo(200, 0.01));
    });

    testWidgets('Row (RTL) reorder FLIPs correctly', (tester) async {
      Widget host(List<String> ids) => Directionality(
            textDirection: TextDirection.rtl,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                  width: 200,
                  child: Row(children: [for (final id in ids) _item(id)])),
            ),
          );
      await tester.pumpWidget(host(['a', 'b']));
      await tester.pumpAndSettle();
      // RTL: a is at the right edge.
      expect(_painted(tester, 'a').dx, closeTo(150, 0.01));
      expect(_painted(tester, 'b').dx, closeTo(100, 0.01));
      await tester.pumpWidget(host(['b', 'a']));
      await tester.pump();
      expect(_painted(tester, 'a').dx, closeTo(150, 0.5));
      expect(_painted(tester, 'b').dx, closeTo(100, 0.5));
      await tester.pumpAndSettle();
      expect(_painted(tester, 'a').dx, closeTo(100, 0.01));
      expect(_painted(tester, 'b').dx, closeTo(150, 0.01));
    });

    testWidgets('scroll offset changes are not layout changes', (tester) async {
      final controller = ScrollController();
      await tester.pumpWidget(_wrap(SizedBox(
        width: 100,
        height: 100,
        child: SingleChildScrollView(
          controller: controller,
          child: Column(children: [
            for (final id in ['a', 'b', 'c', 'd']) _item(id),
          ]),
        ),
      )));
      await tester.pumpAndSettle();
      controller.jumpTo(60);
      await tester.pump();
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(_painted(tester, 'a').dy, closeTo(-60, 0.01));
    });

    testWidgets('moving the NibLayoutScope itself is ignored', (tester) async {
      Widget host(double inset) => Directionality(
            textDirection: TextDirection.ltr,
            child: Padding(
              padding: EdgeInsets.only(top: inset),
              child: NibLayoutScope(
                child: Column(children: [_item('a'), _item('b')]),
              ),
            ),
          );
      await tester.pumpWidget(host(0));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(80));
      await tester.pump();
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(_painted(tester, 'a').dy, closeTo(80, 0.01));
    });

    testWidgets('scaled ancestor: no flash, correct destination',
        (tester) async {
      Widget host(double left) => _wrap(Transform.scale(
            scale: 2,
            alignment: Alignment.topLeft,
            child: SizedBox(
                width: 400,
                height: 100,
                child: Stack(children: [
                  Positioned(left: left, top: 0, child: _item('a')),
                ])),
          ));
      await tester.pumpWidget(host(0));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(50));
      await tester.pump();
      expect(_painted(tester, 'a').dx, closeTo(0, 0.5));
      await tester.pumpAndSettle();
      expect(_painted(tester, 'a').dx, closeTo(100, 0.01)); // 50 * 2
    });

    testWidgets('interrupting mid-flight continues from the painted position',
        (tester) async {
      Widget host(double left) => _wrap(SizedBox(
          width: 400,
          height: 100,
          child: Stack(children: [
            Positioned(left: left, top: 0, child: _item('a')),
          ])));
      await tester.pumpWidget(host(0));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final before = _painted(tester, 'a').dx;
      expect(before, inExclusiveRange(1, 299));
      await tester.pumpWidget(host(0)); // reverse
      await tester.pump();
      expect(_painted(tester, 'a').dx, closeTo(before, 0.75),
          reason: 'no jump on interruption');
      // Momentum toward +x carries on for a moment.
      await tester.pump(const Duration(milliseconds: 4));
      await tester.pump(const Duration(milliseconds: 4));
      expect(_painted(tester, 'a').dx, greaterThan(before));
      await tester.pumpAndSettle();
      expect(_painted(tester, 'a').dx, closeTo(0, 0.01));
    });

    testWidgets('ten rebuilds in one frame stay consistent', (tester) async {
      Widget host(double left) => _wrap(SizedBox(
          width: 400,
          height: 100,
          child: Stack(children: [
            Positioned(left: left, top: 0, child: _item('a')),
          ])));
      await tester.pumpWidget(host(0));
      await tester.pumpAndSettle();
      for (var i = 1; i <= 10; i++) {
        await tester.pumpWidget(host(i * 20.0));
      }
      await tester.pump();
      expect(_painted(tester, 'a').dx, closeTo(0, 0.5));
      await tester.pumpAndSettle();
      expect(_painted(tester, 'a').dx, closeTo(200, 0.01));
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposal mid-flight is safe', (tester) async {
      Widget host(double left) => _wrap(SizedBox(
          width: 400,
          height: 100,
          child: Stack(children: [
            Positioned(left: left, top: 0, child: _item('a')),
          ])));
      await tester.pumpWidget(host(0));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(200));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion jumps with no ticker', (tester) async {
      Widget host(double left) => NibMotionConfig(
            reducedMotion: true,
            child: _wrap(SizedBox(
                width: 400,
                height: 100,
                child: Stack(children: [
                  Positioned(left: left, top: 0, child: _item('a')),
                ]))),
          );
      await tester.pumpWidget(host(0));
      await tester.pumpWidget(host(200));
      await tester.pump();
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      expect(_painted(tester, 'a').dx, closeTo(200, 0.01));
    });

    testWidgets('does not rebuild the child while animating', (tester) async {
      var builds = 0;
      final child = Builder(builder: (_) {
        builds++;
        return const SizedBox(width: 50, height: 50);
      });
      Widget host(double left) => _wrap(SizedBox(
          width: 400,
          height: 100,
          child: Stack(children: [
            Positioned(
                left: left,
                top: 0,
                child: NibMotion(
                    key: const ValueKey('x'),
                    layout: NibLayout.position,
                    child: child)),
          ])));
      await tester.pumpWidget(host(0));
      await tester.pumpWidget(host(200));
      final after = builds;
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(builds, after);
    });

    testWidgets('layout none is inert', (tester) async {
      Widget host(double left) => _wrap(SizedBox(
          width: 400,
          height: 100,
          child: Stack(children: [
            Positioned(
                left: left, top: 0, child: _item('a', layout: NibLayout.none)),
          ])));
      await tester.pumpWidget(host(0));
      await tester.pumpWidget(host(200));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(_painted(tester, 'a').dx, closeTo(200, 0.01));
    });

    testWidgets('start/complete callbacks fire once per animation',
        (tester) async {
      var starts = 0, completes = 0;
      Widget host(double left) => _wrap(SizedBox(
          width: 400,
          height: 100,
          child: Stack(children: [
            Positioned(
                left: left,
                top: 0,
                child: NibMotion(
                  key: const ValueKey('x'),
                  layout: NibLayout.position,
                  onLayoutAnimationStart: () => starts++,
                  onLayoutAnimationComplete: () => completes++,
                  child: const SizedBox(width: 50, height: 50),
                )),
          ])));
      await tester.pumpWidget(host(0));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(200));
      await tester.pump();
      await tester.pump();
      expect(starts, 1);
      expect(completes, 0);
      await tester.pumpAndSettle();
      expect(completes, 1);
    });
  });

  group('NibMotion layout: runtime changes', () {
    testWidgets('layout can be switched on after the first build',
        (tester) async {
      Widget host(NibLayout mode, double left) => _wrap(SizedBox(
          width: 400,
          height: 100,
          child: Stack(children: [
            Positioned(
                left: left,
                top: 0,
                child: NibMotion(
                  key: const ValueKey('x'),
                  layout: mode,
                  child:
                      const SizedBox(key: ValueKey('a'), width: 50, height: 50),
                )),
          ])));
      await tester.pumpWidget(host(NibLayout.none, 0));
      await tester.pumpWidget(host(NibLayout.none, 100));
      await tester.pump();
      expect(_painted(tester, 'a').dx, closeTo(100, 0.01), reason: 'inert');
      await tester.pumpWidget(host(NibLayout.position, 100)); // arm
      await tester.pump();
      await tester.pumpWidget(host(NibLayout.position, 300));
      await tester.pump();
      expect(_painted(tester, 'a').dx, closeTo(100, 0.5),
          reason: 'now animates from where it was');
      await tester.pumpAndSettle();
      expect(_painted(tester, 'a').dx, closeTo(300, 0.01));
      // ...and off again.
      await tester.pumpWidget(host(NibLayout.none, 0));
      await tester.pump();
      expect(_painted(tester, 'a').dx, closeTo(0, 0.01));
    });
  });

  group('NibMotion layout: size', () {
    testWidgets('size change scales from the old size to the new one',
        (tester) async {
      Widget host(double w) => _wrap(SizedBox(
          width: 400,
          child: Row(children: [
            _item('a', w: w, layout: NibLayout.both),
          ])));
      await tester.pumpWidget(host(50));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(100));
      await tester.pump();
      expect(_paintedSize(tester, 'a').width, closeTo(50, 0.5));
      expect(_painted(tester, 'a').dx, closeTo(0, 0.5));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_paintedSize(tester, 'a').width, inExclusiveRange(51, 99));
      await tester.pumpAndSettle();
      expect(_paintedSize(tester, 'a').width, closeTo(100, 0.01));
    });

    testWidgets('position-only ignores size changes', (tester) async {
      Widget host(double w) => _wrap(SizedBox(
          width: 400,
          child: Row(children: [
            _item('a', w: w, layout: NibLayout.position),
          ])));
      await tester.pumpWidget(host(50));
      await tester.pumpWidget(host(100));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(_paintedSize(tester, 'a').width, closeTo(100, 0.01));
    });
  });
}

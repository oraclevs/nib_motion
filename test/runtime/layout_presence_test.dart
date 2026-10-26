import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

const _fast = NibTransition(duration: Duration(milliseconds: 300));

Widget _cfg(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: NibMotionConfig(
        entranceWarmup: Duration.zero,
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    );

Widget _item(String id, {Widget? child}) => NibMotion(
      key: ValueKey(id),
      layout: NibLayout.position,
      initial: const NibAnim(opacity: 0),
      animate: const NibAnim(opacity: 1),
      exit: const NibAnim(opacity: 0),
      transition: _fast,
      child: child ?? SizedBox(key: ValueKey('box-$id'), width: 50, height: 50),
    );

Widget _column(BuildContext context, List<Widget> children) =>
    Column(mainAxisSize: MainAxisSize.min, children: children);

double _opacity(WidgetTester tester, String id) {
  RenderNibMotion? found;
  void visit(Element e) {
    if (found != null) return;
    if (e.renderObject is RenderNibMotion) {
      found = e.renderObject! as RenderNibMotion;
      return;
    }
    e.visitChildren(visit);
  }

  visit(find.byKey(ValueKey(id)).evaluate().single);
  return found!.opacity.value;
}

double _y(WidgetTester tester, String id) => tester
    .renderObject<RenderBox>(find.byKey(ValueKey('box-$id')))
    .localToGlobal(Offset.zero)
    .dy;

Rect _paintRect(WidgetTester tester, String id) {
  final box = tester.renderObject<RenderBox>(find.byKey(ValueKey('box-$id')));
  return MatrixUtils.transformRect(
      box.getTransformTo(null), Offset.zero & box.size);
}

/// Whether a node labelled [label] is in the live semantics tree. (The
/// `find.bySemanticsLabel` finder reads possibly-stale render-object state.)
bool _inSemanticsTree(WidgetTester tester, String label) {
  bool visit(SemanticsNode n) {
    var found = n.label == label;
    n.visitChildren((c) {
      if (visit(c)) found = true;
      return true;
    });
    return found;
  }

  return visit(RendererBinding
      .instance.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
}

void main() {
  group('NibPresence exiting children', () {
    testWidgets('pop preserves size inside translated and scaled builder',
        (tester) async {
      Widget host(bool show) => _cfg(NibPresence(
            exitLayout: NibExitLayout.pop,
            layoutBuilder: (context, children) => Transform.translate(
              offset: const Offset(30, 40),
              child: Transform.scale(
                scale: 2,
                alignment: Alignment.topLeft,
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: children),
              ),
            ),
            children: [
              if (show)
                const NibMotion(
                  key: ValueKey('a'),
                  exit: NibAnim(opacity: 0),
                  transition: _fast,
                  child:
                      SizedBox(key: ValueKey('box-a'), width: 50, height: 50),
                ),
            ],
          ));

      await tester.pumpWidget(host(true));
      await tester.pumpAndSettle();
      final before = _paintRect(tester, 'a');
      expect(before, const Rect.fromLTWH(30, 40, 100, 100));

      await tester.pumpWidget(host(false));
      await tester.pump();
      expect(find.byKey(const ValueKey('a')), findsOneWidget);
      expect(_paintRect(tester, 'a'), before,
          reason: 'exiting child must keep its painted rectangle');
      expect(tester.getSize(find.byKey(const ValueKey('box-a'))),
          const Size(50, 50),
          reason: 'the overlay must paint a scale, not relayout child content');
      await tester.pumpAndSettle();
    });

    testWidgets('pop preserves rotated nonuniform bounds and excludes hits',
        (tester) async {
      var taps = 0;
      Widget host(bool show) => _cfg(NibPresence(
            exitLayout: NibExitLayout.pop,
            layoutBuilder: (context, children) => Transform.translate(
              offset: const Offset(60, -100),
              child: Transform.rotate(
                angle: math.pi / 2,
                alignment: Alignment.topLeft,
                child: Transform.scale(
                  scaleX: 2,
                  scaleY: 0.5,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: children,
                    ),
                  ),
                ),
              ),
            ),
            children: [
              if (show)
                NibMotion(
                  key: const ValueKey('a'),
                  layout: NibLayout.position,
                  exit: const NibAnim(opacity: 0),
                  transition: _fast,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => taps++,
                    child: const SizedBox(
                        key: ValueKey('box-a'), width: 50, height: 50),
                  ),
                ),
            ],
          ));
      await tester.pumpWidget(host(true));
      await tester.pumpAndSettle();
      final before = _paintRect(tester, 'a');
      expect(before.left, closeTo(35, 0.01));
      expect(before.top, closeTo(50, 0.01));
      expect(before.width, closeTo(25, 0.01));
      expect(before.height, closeTo(100, 0.01));
      await tester.tapAt(before.center);
      await tester.pump();
      expect(taps, 1, reason: 'the painted target is active before exit');

      await tester.pumpWidget(host(false));
      await tester.pump();
      final exiting = _paintRect(tester, 'a');
      expect(exiting.left, closeTo(before.left, 0.01));
      expect(exiting.top, closeTo(before.top, 0.01));
      expect(exiting.width, closeTo(before.width, 0.01));
      expect(exiting.height, closeTo(before.height, 0.01));
      await tester.tapAt(before.center);
      expect(taps, 1, reason: 'the exit overlay cannot receive a tap');

      await tester.pumpWidget(host(true));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('a')), findsOneWidget);
      expect(_paintRect(tester, 'a'), before,
          reason: 're-entry restores the original layout coordinates');
      await tester.tapAt(before.center);
      await tester.pump();
      expect(taps, 2, reason: 'the re-entered target receives taps again');

      await tester.pumpWidget(host(false));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('a')), findsNothing);
    });

    testWidgets('are removed from semantics and focus while exiting',
        (tester) async {
      final handle = tester.ensureSemantics();
      Widget host(bool on) => _cfg(NibPresence(children: [
            if (on)
              _item('a',
                  child: Semantics(
                      label: 'hello',
                      child: const SizedBox(width: 50, height: 50))),
          ]));
      await tester.pumpWidget(host(true));
      await tester.pumpAndSettle();
      expect(_inSemanticsTree(tester, 'hello'), isTrue);
      ExcludeFocus focusWrapper() => tester.widget<ExcludeFocus>(find
          .ancestor(
              of: find.byKey(const ValueKey('a')),
              matching: find.byType(ExcludeFocus))
          .first);
      expect(focusWrapper().excluding, isFalse);

      await tester.pumpWidget(host(false));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('a')), findsOneWidget);
      expect(_inSemanticsTree(tester, 'hello'), isFalse);
      expect(focusWrapper().excluding, isTrue);
      await tester.pumpAndSettle();
      handle.dispose();
    });

    testWidgets('sync exit keeps siblings in place until it finishes',
        (tester) async {
      Widget host(List<String> ids) => _cfg(NibPresence(
          layoutBuilder: _column, children: [for (final id in ids) _item(id)]));
      await tester.pumpWidget(host(['a', 'b']));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(['b']));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_y(tester, 'b'), closeTo(50, 0.01));
      await tester.pumpAndSettle();
      expect(_y(tester, 'b'), closeTo(0, 0.01));
    });

    testWidgets(
        'exitLayout.pop overlays the exiting child; siblings reflow now',
        (tester) async {
      Widget host(List<String> ids) => _cfg(NibPresence(
          layoutBuilder: _column,
          exitLayout: NibExitLayout.pop,
          children: [for (final id in ids) _item(id)]));
      await tester.pumpWidget(host(['a', 'b']));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(['b']));
      await tester.pump();
      // b is laid out at 0 already but FLIP keeps it painted at 50 first.
      expect(_y(tester, 'b'), closeTo(50, 0.5));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_y(tester, 'b'), lessThan(49), reason: 'b is already moving up');
      // a is still mounted as an overlay at its old rect, fading.
      expect(find.byKey(const ValueKey('a')), findsOneWidget);
      expect(_y(tester, 'a'), closeTo(0, 0.01));
      expect(_opacity(tester, 'a'), inExclusiveRange(0.0, 1.0));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('a')), findsNothing);
      expect(_y(tester, 'b'), closeTo(0, 0.01));
    });

    testWidgets('pop: re-adding mid-exit brings the child back into the flow',
        (tester) async {
      Widget host(List<String> ids) => _cfg(NibPresence(
          layoutBuilder: _column,
          exitLayout: NibExitLayout.pop,
          children: [for (final id in ids) _item(id)]));
      await tester.pumpWidget(host(['a', 'b']));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(['b']));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(host(['a', 'b']));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('a')), findsOneWidget);
      expect(_opacity(tester, 'a'), 1);
      expect(_y(tester, 'a'), closeTo(0, 0.01));
      expect(_y(tester, 'b'), closeTo(50, 0.01));
    });
  });

  group('NibPresence stagger', () {
    testWidgets('exits start one after another', (tester) async {
      Widget host(List<String> ids) => _cfg(NibPresence(
          stagger: const Duration(milliseconds: 100),
          children: [for (final id in ids) _item(id)]));
      await tester.pumpWidget(host(['a', 'b', 'c']));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host([]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_opacity(tester, 'a'), lessThan(1));
      expect(_opacity(tester, 'b'), 1);
      expect(_opacity(tester, 'c'), 1);
      await tester.pump(const Duration(milliseconds: 60)); // t=110: b started
      await tester.pump(const Duration(milliseconds: 40)); // t=150
      expect(_opacity(tester, 'b'), lessThan(1));
      expect(_opacity(tester, 'c'), 1);
      await tester.pumpAndSettle();
      expect(find.byType(NibMotion), findsNothing);
    });

    testWidgets('staggerFrom last reverses the order', (tester) async {
      Widget host(List<String> ids) => _cfg(NibPresence(
          stagger: const Duration(milliseconds: 100),
          staggerFrom: NibStaggerFrom.last,
          children: [for (final id in ids) _item(id)]));
      await tester.pumpWidget(host(['a', 'b', 'c']));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host([]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_opacity(tester, 'c'), lessThan(1));
      expect(_opacity(tester, 'a'), 1);
      await tester.pumpAndSettle();
    });

    testWidgets('entrances of a batch are staggered', (tester) async {
      await tester.pumpWidget(_cfg(
          NibPresence(stagger: const Duration(milliseconds: 100), children: [
        for (final id in ['a', 'b', 'c']) _item(id)
      ])));
      await tester.pump(); // post-frame entrance callbacks
      await tester.pump(const Duration(milliseconds: 16)); // tickers start
      await tester.pump(const Duration(milliseconds: 50));
      expect(_opacity(tester, 'a'), greaterThan(0));
      expect(_opacity(tester, 'c'), 0);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 50));
      expect(_opacity(tester, 'c'), greaterThan(0));
      await tester.pumpAndSettle();
      expect(_opacity(tester, 'c'), 1);
    });

    testWidgets('re-adding during a staggered exit delay cancels the exit',
        (tester) async {
      Widget host(List<String> ids) => _cfg(NibPresence(
          stagger: const Duration(milliseconds: 200),
          children: [for (final id in ids) _item(id)]));
      await tester.pumpWidget(host(['a', 'b']));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host([]));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(host(['b'])); // b was waiting for its delay
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('b')), findsOneWidget);
      expect(_opacity(tester, 'b'), 1);
      expect(find.byKey(const ValueKey('a')), findsNothing);
    });
  });
}

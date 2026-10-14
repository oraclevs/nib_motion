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

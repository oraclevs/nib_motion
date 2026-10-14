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

void main() {
  group('spring tokens where a transition is expected', () {
    test('NibTransition.of wraps a spring description', () {
      final t = NibTransition.of(NibSpring.smooth);
      expect(t.spring, NibSpring.smooth);
      expect(t.type, NibTransitionType.spring);
      expect(NibSpring.smooth.transition, t);
    });

    testWidgets('NibMotion(spring:) is shorthand for a spring transition',
        (tester) async {
      await tester.pumpWidget(_wrap(NibMotion(
        animate: const NibAnim(x: 100),
        spring: NibSpring.bouncy,
        child: const SizedBox(width: 10, height: 10),
      )));
      var peak = 0.0;
      await tester.pump();
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final x = _render(tester).translateX.value;
        if (x > peak) peak = x;
      }
      expect(peak, greaterThan(100), reason: 'bouncy spring overshoots');
      await tester.pumpAndSettle();
      expect(_render(tester).translateX.value, 100);
    });

    test('transition and spring together is an error', () {
      expect(
          () => NibMotion(
                transition: NibTransition.springGentle,
                spring: NibSpring.smooth,
                child: const SizedBox(),
              ),
          throwsAssertionError);
    });

    testWidgets('spring shorthand resolves to the same transition',
        (tester) async {
      const a = NibMotion(
        spring: NibSpringDescription.gentle,
        child: SizedBox(),
      );
      expect(a.transition, NibTransition.springGentle);
    });
  });

  group('NibMotion.initial change warning', () {
    Widget build(NibAnim initial) => _wrap(NibMotion(
          initial: initial,
          child: const SizedBox(width: 10, height: 10),
        ));

    testWidgets('warns once when initial changes, keeps behaviour',
        (tester) async {
      final original = debugPrint;
      final printed = <String>[];
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) printed.add(message);
      };
      try {
        await tester.pumpWidget(build(const NibAnim(x: 10)));
        await tester.pumpWidget(build(const NibAnim(x: 10)));
        expect(printed.where((m) => m.contains('NibMotion.initial')), isEmpty,
            reason: 'equal initial values do not warn');

        await tester.pumpWidget(build(const NibAnim(x: 50)));
        final warnings = printed.where((m) => m.contains('NibMotion.initial'));
        expect(warnings.length, 1);
        expect(warnings.first, contains('Key'));
        expect(_render(tester).translateX.value, 10,
            reason: 'initial is still read only once');

        await tester.pumpWidget(build(const NibAnim(x: 70)));
        expect(printed.where((m) => m.contains('NibMotion.initial')).length, 1,
            reason: 'only once per widget state');
      } finally {
        debugPrint = original;
      }
    });
  });

  group('NibPresence.layout', () {
    Widget item(String id) => NibMotion(
          key: ValueKey(id),
          exit: const NibAnim(opacity: 0),
          transition:
              const NibTransition(duration: Duration(milliseconds: 200)),
          child: SizedBox(key: ValueKey('box-$id'), width: 50, height: 50),
        );

    Widget host(List<String> ids,
            {NibPresenceAxis axis = NibPresenceAxis.column}) =>
        _wrap(NibPresence.layout(
          axis: axis,
          children: [for (final id in ids) item(id)],
        ));

    Offset painted(WidgetTester tester, String id) => tester
        .renderObject<RenderBox>(find.byKey(ValueKey('box-$id')))
        .localToGlobal(Offset.zero);

    testWidgets('siblings FLIP into the freed space with one call',
        (tester) async {
      await tester.pumpWidget(host(['a', 'b', 'c']));
      await tester.pumpAndSettle();
      expect(painted(tester, 'b').dy, closeTo(50, 0.01));

      await tester.pumpWidget(host(['b', 'c']));
      await tester.pump();
      expect(painted(tester, 'b').dy, closeTo(50, 0.75),
          reason: 'b still painted at its old slot (inverted)');
      await tester.pump(const Duration(milliseconds: 80));
      final mid = painted(tester, 'b').dy;
      expect(mid, inExclusiveRange(0.5, 49.5), reason: 'travelling to slot 0');
      await tester.pumpAndSettle();
      expect(painted(tester, 'b').dy, closeTo(0, 0.1));
      expect(painted(tester, 'c').dy, closeTo(50, 0.1));
      expect(find.byKey(const ValueKey('box-a')), findsNothing);
    });

    testWidgets('row axis and wrap work', (tester) async {
      await tester.pumpWidget(host(['a', 'b'], axis: NibPresenceAxis.row));
      await tester.pumpAndSettle();
      expect(painted(tester, 'b').dx, closeTo(50, 0.01));
      await tester.pumpWidget(host(['b'], axis: NibPresenceAxis.row));
      await tester.pump();
      expect(painted(tester, 'b').dx, closeTo(50, 0.75));
      await tester.pumpAndSettle();
      expect(painted(tester, 'b').dx, closeTo(0, 0.1));

      await tester.pumpWidget(host(['a', 'b'], axis: NibPresenceAxis.wrap));
      await tester.pumpAndSettle();
      expect(painted(tester, 'b').dx, closeTo(50, 0.01));
    });

    testWidgets('childLayout: none turns FLIP off; explicit position wins',
        (tester) async {
      Widget h(List<String> ids, {required NibLayout childLayout}) =>
          _wrap(NibPresence.layout(
            childLayout: childLayout,
            children: [
              for (final id in ids)
                NibMotion(
                  key: ValueKey(id),
                  exit: const NibAnim(opacity: 0),
                  // 'c' asks for position itself; the others inherit.
                  layout: id == 'c' ? NibLayout.position : NibLayout.none,
                  transition: const NibTransition(
                      duration: Duration(milliseconds: 200)),
                  child:
                      SizedBox(key: ValueKey('box-$id'), width: 50, height: 50),
                ),
            ],
          ));
      await tester.pumpWidget(h(['a', 'b', 'c'], childLayout: NibLayout.none));
      await tester.pumpAndSettle();
      await tester.pumpWidget(h(['b', 'c'], childLayout: NibLayout.none));
      await tester.pump();
      expect(painted(tester, 'b').dy, closeTo(0, 0.01),
          reason: 'b inherits none: jumps, no FLIP');
      expect(painted(tester, 'c').dy, closeTo(100, 0.75),
          reason: 'c set position itself: FLIPs from its old slot');
      await tester.pumpAndSettle();
    });
  });
}

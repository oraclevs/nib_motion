import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _item(String id) => NibMotion(
      key: ValueKey(id),
      initial: const NibAnim(opacity: 0),
      animate: const NibAnim(opacity: 1),
      exit: const NibAnim(opacity: 0),
      transition: const NibTransition(duration: Duration(milliseconds: 300)),
      child: const SizedBox(width: 20, height: 20),
    );

Widget _host(List<String> ids) => Directionality(
      textDirection: TextDirection.ltr,
      child: NibPresence(children: [for (final id in ids) _item(id)]),
    );

double _opacityOf(WidgetTester tester, String id) {
  final element = find.byKey(ValueKey(id)).evaluate().single;
  RenderObject? found;
  void visit(Element e) {
    if (found != null) return;
    if (e.renderObject is RenderNibMotion) {
      found = e.renderObject;
      return;
    }
    e.visitChildren(visit);
  }

  visit(element);
  return (found! as RenderNibMotion).opacity.value;
}

void main() {
  group('NibPresence lifecycle', () {
    testWidgets('rejects missing child keys with an actionable error',
        (tester) async {
      await tester.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: NibPresence(children: [SizedBox(width: 20, height: 20)]),
      ));
      expect(tester.takeException(), isA<FlutterError>());
    });

    testWidgets('rejects duplicate child keys before losing an entry',
        (tester) async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: NibPresence(children: [_item('a'), _item('a')]),
      ));
      expect(tester.takeException(), isA<FlutterError>());
    });

    testWidgets('child removed then re-added mid-exit animates back in',
        (tester) async {
      await tester.pumpWidget(_host(['a']));
      await tester.pumpAndSettle();
      expect(_opacityOf(tester, 'a'), 1);

      await tester.pumpWidget(_host([]));
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byKey(const ValueKey('a')), findsOneWidget,
          reason: 'still exiting');
      expect(_opacityOf(tester, 'a'), inInclusiveRange(0.05, 0.95));

      await tester.pumpWidget(_host(['a']));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('a')), findsOneWidget);
      expect(_opacityOf(tester, 'a'), 1,
          reason: 're-entering child must return to its animate state');
    });

    testWidgets('exit continues from the current opacity when re-removed',
        (tester) async {
      await tester.pumpWidget(_host(['a']));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_host([]));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(_host(['a']));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(_host([]));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('a')), findsNothing);
    });

    testWidgets('reordering children reorders the mounted widgets',
        (tester) async {
      await tester.pumpWidget(_host(['a', 'b', 'c']));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_host(['c', 'a', 'b']));
      await tester.pumpAndSettle();
      final order = tester
          .widgetList<NibMotion>(find.byType(NibMotion))
          .map((w) => (w.key! as ValueKey).value)
          .toList();
      expect(order, ['c', 'a', 'b']);
    });

    testWidgets('an exiting child keeps its slot among reordered siblings',
        (tester) async {
      await tester.pumpWidget(_host(['a', 'b', 'c']));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_host(['a', 'c']));
      await tester.pump(const Duration(milliseconds: 100));
      final order = tester
          .widgetList<NibMotion>(find.byType(NibMotion))
          .map((w) => (w.key! as ValueKey).value)
          .toList();
      expect(order, ['a', 'b', 'c']);
      await tester.pumpAndSettle();
    });

    testWidgets('rapid insertion and removal ends consistent', (tester) async {
      var ids = <String>[];
      await tester.pumpWidget(_host(ids));
      for (var i = 0; i < 60; i++) {
        ids = i.isEven ? ['a', 'b', 'c'] : ['b'];
        await tester.pumpWidget(_host(ids));
        await tester.pump(Duration(milliseconds: 20 + (i % 5) * 30));
      }
      await tester.pumpAndSettle();
      expect(find.byType(NibMotion), findsNWidgets(ids.length));
      expect(tester.takeException(), isNull);
    });
  });
}

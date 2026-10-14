import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _hero(String key, {double w = 50, double h = 50, Object id = 'hero'}) =>
    NibMotion(
      key: ValueKey(key),
      layout: NibLayout.both,
      layoutId: id,
      child: SizedBox(key: ValueKey('box-$key'), width: w, height: h),
    );

Widget _host(Widget child, {bool scope = true}) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 500,
          height: 400,
          child: scope ? NibLayoutScope(child: child) : child,
        ),
      ),
    );

Offset _origin(WidgetTester tester, String key) => tester
    .renderObject<RenderBox>(find.byKey(ValueKey('box-$key')))
    .localToGlobal(Offset.zero);

Size _size(WidgetTester tester, String key) {
  final box = tester.renderObject<RenderBox>(find.byKey(ValueKey('box-$key')));
  return MatrixUtils.transformRect(
          box.getTransformTo(null), Offset.zero & box.size)
      .size;
}

void main() {
  group('layoutId shared transitions', () {
    testWidgets('a remounted id animates from the old rectangle across parents',
        (tester) async {
      Widget host(bool left) => _host(Stack(children: [
            if (left)
              Positioned(left: 0, top: 0, child: _hero('one'))
            else
              Positioned(
                  left: 300, top: 200, child: _hero('two', w: 100, h: 100)),
          ]));
      await tester.pumpWidget(host(true));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(false));
      await tester.pump();
      expect(find.byKey(const ValueKey('one')), findsNothing);
      expect(_origin(tester, 'two').dx, closeTo(0, 0.5));
      expect(_origin(tester, 'two').dy, closeTo(0, 0.5));
      expect(_size(tester, 'two').width, closeTo(50, 0.5));
      await tester.pump(const Duration(milliseconds: 120));
      expect(_origin(tester, 'two').dx, inExclusiveRange(1, 299));
      expect(_size(tester, 'two').width, inExclusiveRange(51, 99));
      await tester.pumpAndSettle();
      expect(_origin(tester, 'two'), const Offset(300, 200));
      expect(_size(tester, 'two'), const Size(100, 100));
    });

    testWidgets('works between different container types', (tester) async {
      Widget host(bool column) => _host(column
          ? Column(children: [
              const SizedBox(height: 40),
              Row(children: [_hero('col')])
            ])
          : Wrap(children: [
              const SizedBox(width: 200, height: 10),
              _hero('wrap')
            ]));
      await tester.pumpWidget(host(true));
      await tester.pumpAndSettle();
      final from = _origin(tester, 'col');
      await tester.pumpWidget(host(false));
      await tester.pump();
      expect(_origin(tester, 'wrap').dx, closeTo(from.dx, 0.5));
      expect(_origin(tester, 'wrap').dy, closeTo(from.dy, 0.5));
      await tester.pumpAndSettle();
      expect(_origin(tester, 'wrap'), isNot(from));
    });

    testWidgets('two live widgets sharing an id do not animate each other',
        (tester) async {
      await tester.pumpWidget(_host(Stack(children: [
        Positioned(left: 0, top: 0, child: _hero('a')),
        Positioned(left: 200, top: 0, child: _hero('b')),
      ])));
      await tester.pump();
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(_origin(tester, 'b').dx, closeTo(200, 0.01));
    });

    testWidgets('a stale snapshot is not reused', (tester) async {
      Widget host(int state) => _host(Stack(children: [
            if (state == 1) Positioned(left: 0, top: 0, child: _hero('one')),
            if (state == 3) Positioned(left: 300, top: 0, child: _hero('two')),
          ]));
      await tester.pumpWidget(host(1));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(2));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(host(3));
      await tester.pump();
      expect(_origin(tester, 'two').dx, closeTo(300, 0.01));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('without a scope the id is inert and nothing throws',
        (tester) async {
      Widget host(bool left) => _host(
          Stack(children: [
            Positioned(
                left: left ? 0 : 300,
                top: 0,
                child: _hero(left ? 'one' : 'two')),
          ]),
          scope: false);
      await tester.pumpWidget(host(true));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(false));
      await tester.pump();
      expect(_origin(tester, 'two').dx, closeTo(300, 0.01));
      expect(tester.takeException(), isNull);
    });

    testWidgets('different ids never interact', (tester) async {
      Widget host(bool first) => _host(Stack(children: [
            Positioned(
                left: first ? 0 : 300,
                top: 0,
                child: _hero(first ? 'one' : 'two', id: first ? 'x' : 'y')),
          ]));
      await tester.pumpWidget(host(true));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(false));
      await tester.pump();
      expect(_origin(tester, 'two').dx, closeTo(300, 0.01));
    });
  });
}

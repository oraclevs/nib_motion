import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

const items = [
  NibNavItem(icon: Icon(Icons.home), label: 'Discover'),
  NibNavItem(icon: Icon(Icons.search), label: 'Explore'),
  NibNavItem(icon: Icon(Icons.person), label: 'Profile'),
];

NibNavBarPainter painter(WidgetTester tester) => tester
    .widget<CustomPaint>(
      find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is NibNavBarPainter),
    )
    .painter! as NibNavBarPainter;

Widget bar(int index, {bool reduce = false, ValueChanged<int>? onChanged}) =>
    MaterialApp(
        home: Center(
            child: MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: SizedBox(
          width: 330,
          child: NibNavBar(
            items: items,
            currentIndex: index,
            onIndexChanged: onChanged ?? (_) {},
            indicator:
                const NibNavIndicatorStyle(type: NibNavIndicatorType.liquid),
          )),
    )));

void main() {
  testWidgets(
      'liquid shader compiles, flows on rapid retarget and stops at rest',
      (tester) async {
    NibShaderLoader.assetKeyResolver =
        (key) => key.replaceFirst('packages/nib_motion/', '');
    addTearDown(NibShaderLoader.resetForTesting);
    await tester.pumpWidget(bar(0));
    await tester.runAsync(() async {
      await NibShaderLoader.load(
          'packages/nib_motion/lib/shaders/nav_water.frag');
    });
    await tester.pump();
    expect(painter(tester).liquidShader, isNotNull);
    final start = painter(tester).indicatorX.value;
    await tester.pumpWidget(bar(2));
    await tester.pump(const Duration(milliseconds: 80));
    expect(painter(tester).indicatorX.value, greaterThan(start));
    expect(painter(tester).liquidPhase!.value, lessThan(1));
    await tester.pumpWidget(bar(1));
    await tester.pumpAndSettle();
    final p = painter(tester);
    expect(p.indicatorX.value + p.indicatorWidth.value / 2, closeTo(165, .1));
    expect(p.liquidTail!.value, closeTo(p.indicatorX.value, .1));
    expect(p.liquidPhase!.value, 1);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion jumps and lens encompasses the label column',
      (tester) async {
    await tester.pumpWidget(bar(0, reduce: true));
    await tester.pumpWidget(bar(2, reduce: true));
    final p = painter(tester);
    expect(p.indicatorWidth.value, 102);
    expect(p.indicatorX.value + p.indicatorWidth.value / 2, 275);
    expect(p.liquidTail!.value, p.indicatorX.value);
    expect(p.liquidPhase!.value, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('each full tab exposes selected semantics and a tap action',
      (tester) async {
    final semantics = tester.ensureSemantics();
    int? selected;
    await tester.pumpWidget(bar(0, onChanged: (index) => selected = index));
    final discover = tester
        .getSemantics(find.bySemanticsLabel('Discover'))
        .getSemanticsData();
    expect(discover.label, 'Discover');
    // Flutter 3.29 has hasFlag but not the newer flagsCollection API.
    // ignore: deprecated_member_use
    expect(discover.hasFlag(SemanticsFlag.isButton), isTrue);
    // ignore: deprecated_member_use
    expect(discover.hasFlag(SemanticsFlag.isSelected), isTrue);
    // ignore: deprecated_member_use
    expect(discover.hasFlag(SemanticsFlag.isFocusable), isTrue);
    expect(discover.hasAction(SemanticsAction.tap), isTrue);
    expect(discover.hasAction(SemanticsAction.focus), isTrue);
    await tester.tap(find.bySemanticsLabel('Explore'));
    expect(selected, 1);
    await tester.pumpAndSettle();
    semantics.dispose();
  });
  testWidgets(
      'Tab traversal activates with Enter and Space and shows focus ring',
      (tester) async {
    final activated = <int>[];
    await tester.pumpWidget(bar(0, onChanged: activated.add));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(activated, [0]);
    expect(
        find.byWidgetPredicate((w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).border != null),
        findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(activated, [0, 1]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

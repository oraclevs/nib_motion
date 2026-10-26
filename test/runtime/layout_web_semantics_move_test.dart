import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  testWidgets('keyed move and sibling removal preserve focus and semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final key = GlobalKey();
    final focusNode = FocusNode();
    final moving = NibMotion(
      key: key,
      layout: NibLayout.position,
      child: Semantics(
        label: 'Moving item',
        child: Focus(
          focusNode: focusNode,
          child: const SizedBox(width: 40, height: 40),
        ),
      ),
    );

    Widget host(bool moved) => MaterialApp(
          home: Scaffold(
            body: NibLayoutScope(
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Column(children: [
                      if (!moved) moving,
                      if (!moved) const SizedBox(width: 40, height: 40),
                    ]),
                  ),
                  SizedBox(
                    width: 100,
                    child: Column(children: [if (moved) moving]),
                  ),
                ],
              ),
            ),
          ),
        );

    await tester.pumpWidget(host(false));
    await tester.pumpAndSettle();
    final element = tester.element(find.byKey(key));
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
    final oldX = tester.getTopLeft(find.byKey(key)).dx;

    await tester.pumpWidget(host(true));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(identical(tester.element(find.byKey(key)), element), isTrue);
    expect(tester.getTopLeft(find.byKey(key)).dx, greaterThan(oldX));
    expect(find.bySemanticsLabel('Moving item'), findsOneWidget);
    expect(focusNode.hasFocus, isTrue);
    semantics.dispose();
    focusNode.dispose();
  });
}

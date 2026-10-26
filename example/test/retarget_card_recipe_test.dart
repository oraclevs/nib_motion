import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion_example/recipes/retarget_card_recipe.dart';

void main() {
  testWidgets('retarget card reverses mid-flight and exposes one label',
      (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: RetargetCardRecipe())),
    ));
    final card = find.byKey(const ValueKey('retarget-card'));
    final origin = tester.getTopLeft(card);
    expect(find.bySemanticsLabel('Animated card'), findsOneWidget);

    await tester.tap(find.text('Move card'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getTopLeft(card).dx, greaterThan(origin.dx));

    await tester.tap(find.text('Reset card'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(card).dx, closeTo(origin.dx, 0.5));
    expect(find.text('Move card'), findsOneWidget);
    semantics.dispose();
  });
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

import 'package:nib_motion_example/readme/entrance.dart' as entrance;
import 'package:nib_motion_example/readme/retarget.dart' as retarget;

void main() {
  test('README Dart examples match the runnable sources', () {
    final readme = File('../README.md').readAsStringSync();
    for (final name in ['entrance', 'retarget']) {
      final source = File('lib/readme/$name.dart').readAsStringSync().trim();
      expect(readme, contains('```dart\n$source\n```'));
    }
  });

  testWidgets('entrance reaches its visible destination', (tester) async {
    entrance.main();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    final render = tester.renderObject<RenderNibMotion>(find.byType(NibMotion));
    expect(render.opacity.value, 1);
    expect(render.translateY.value, 0);
  });

  testWidgets('button retargets a moving spring and stays usable',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: retarget.SpringDemo()));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('Tap to reset'), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('Tap to lift'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

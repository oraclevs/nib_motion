import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';
import 'package:nib_motion_example/brand_mark.dart';

void main() {
  testWidgets('ink mark animates its flourish and pen without an exception',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: NibMotionBrandMark(loop: false)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2400));
    expect(find.byType(NibDrawPath), findsOneWidget);
    expect(find.byType(NibMotion), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

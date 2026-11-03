// Run from example/:
// flutter test ../doc/maintainers/repros/gradient_reduced_motion.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  testWidgets('gradient resumes after reduced motion is toggled',
      (tester) async {
    var reduced = true;
    late StateSetter update;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (context, setState) {
        update = setState;
        return NibMotionConfig(
          reducedMotion: reduced,
          child: const NibGradientText(
            'Motion preference',
            gradient: LinearGradient(colors: [Colors.orange, Colors.blue]),
          ),
        );
      }),
    ));
    for (final preference in [false, true, false]) {
      update(() => reduced = preference);
      await tester.pump(const Duration(milliseconds: 25));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  Widget wrap(Widget child) => Directionality(textDirection: TextDirection.ltr, child: child);

  group('NibMotionWidgetExtension', () {
    testWidgets('animate() wraps the widget in a NibMotion', (tester) async {
      await tester.pumpWidget(
        wrap(const SizedBox(width: 10, height: 10).animate(animate: const NibAnim(opacity: 1.0))),
      );
      expect(find.byType(NibMotion), findsOneWidget);
    });

    testWidgets('shimmer() wraps the widget in a NibShimmer', (tester) async {
      await tester.pumpWidget(wrap(const SizedBox(width: 10, height: 10).shimmer()));
      expect(find.byType(NibShimmer), findsOneWidget);
    });

    testWidgets('revealOnScroll() wraps the widget in a NibScrollReveal', (tester) async {
      await tester.pumpWidget(wrap(const SizedBox(width: 10, height: 10).revealOnScroll()));
      expect(find.byType(NibScrollReveal), findsOneWidget);
    });
  });
}

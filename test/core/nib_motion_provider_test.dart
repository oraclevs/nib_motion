import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  group('NibMotionProvider', () {
    testWidgets('exposes its defaultTransition via NibMotionConfig.of',
        (tester) async {
      const transition = NibTransition.springSnappy;
      late BuildContext capturedContext;

      await tester.pumpWidget(
        NibMotionProvider(
          defaultTransition: transition,
          child: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(
          NibMotionProvider.of(capturedContext)?.defaultTransition, transition);
      expect(NibMotionConfig.defaultTransitionOf(capturedContext), transition);
    });

    testWidgets(
        'respectReducedMotion: false disables reduced-motion regardless of MediaQuery',
        (tester) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: NibMotionProvider(
            respectReducedMotion: false,
            child: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(NibMotionConfig.shouldReduceMotion(capturedContext), isFalse);
    });

    testWidgets(
        'respectReducedMotion: true (default) defers to MediaQuery.disableAnimations',
        (tester) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: NibMotionProvider(
            child: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(NibMotionConfig.shouldReduceMotion(capturedContext), isTrue);
    });
  });
}

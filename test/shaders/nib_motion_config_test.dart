import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/src/core/nib_transition.dart';
import 'package:nib_motion/src/core/reduced_motion.dart';

void main() {
  testWidgets('init() completes and sets globalDefaultTransition', (tester) async {
    const customTransition = NibTransition(duration: Duration(milliseconds: 777));

    await NibMotionConfig.init(
      preloadShaders: false,
      defaultTransition: customTransition,
    );

    expect(NibMotionConfig.globalDefaultTransition, customTransition);
  });

  testWidgets('init() with preloadShaders: true completes without throwing', (tester) async {
    // Shader compilation may or may not succeed in this test environment;
    // NibShaderLoader.preloadAll swallows individual failures, so init()
    // must still complete cleanly either way.
    await expectLater(NibMotionConfig.init(), completes);
  });

  testWidgets('respectReducedMotion: false leaves reducedMotionEnabled false', (tester) async {
    await NibMotionConfig.init(preloadShaders: false, respectReducedMotion: false);
    expect(NibMotionConfig.reducedMotionEnabled, isFalse);
  });

  testWidgets('reducedMotionEnabled reflects the platform accessibility flag at init time', (
    tester,
  ) async {
    final dispatcher = tester.platformDispatcher;
    addTearDown(() => dispatcher.clearAccessibilityFeaturesTestValue());

    dispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );

    await NibMotionConfig.init(preloadShaders: false, respectReducedMotion: true);
    expect(NibMotionConfig.reducedMotionEnabled, isTrue);

    dispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures();
    await NibMotionConfig.init(preloadShaders: false, respectReducedMotion: true);
    expect(NibMotionConfig.reducedMotionEnabled, isFalse);
  });
}

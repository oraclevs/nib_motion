import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/src/shaders/shader_loader.dart';

void main() {
  // `flutter test` runs against a headless VM target that does not bundle
  // this package's own `flutter.shaders` assets the way a real host app's
  // build would (asset bundling for `flutter test` only includes the
  // *running* package's declared assets when it is the root package under
  // test — `nib_motion` is in that position here, so `FragmentProgram
  // .fromAsset` may actually succeed locally, but is not guaranteed to
  // succeed in every CI/test environment, e.g. ones without Impeller/Skia
  // shader compilation available). Rather than assert on compilation
  // succeeding or failing, these tests verify the loader's caching/
  // singleton behavior, which is what `NibMotionConfig.init` and the
  // shader-backed widgets actually depend on: identical asset keys must
  // resolve to the same in-flight/resolved Future, and a reset must force
  // a fresh load.
  setUp(NibShaderLoader.resetForTesting);

  // The cached Futures returned below may reject (see the file comment
  // above) because the default `flutter test` VM target doesn't bundle this
  // package's own `flutter.shaders` assets. These tests only assert on
  // Future *identity* (the caching behavior), not on whether the Future
  // resolves — but an unawaited rejected Future still surfaces as an
  // uncaught async error at tear-down, so each Future under test is marked
  // with `.ignore()` to silence that without affecting the identity
  // comparison already captured above it.
  test('shimmer() returns the same Future instance on repeated calls', () {
    final first = NibShaderLoader.shimmer();
    final second = NibShaderLoader.shimmer();
    expect(first, same(second));
    first.ignore();
  });

  test('dissolve() returns the same Future instance on repeated calls', () {
    final first = NibShaderLoader.dissolve();
    final second = NibShaderLoader.dissolve();
    expect(first, same(second));
    first.ignore();
  });

  test('gradientSweep() returns the same Future instance on repeated calls', () {
    final first = NibShaderLoader.gradientSweep();
    final second = NibShaderLoader.gradientSweep();
    expect(first, same(second));
    first.ignore();
  });

  test('different shaders get different cached Futures', () {
    final shimmer = NibShaderLoader.shimmer();
    final dissolve = NibShaderLoader.dissolve();
    expect(shimmer, isNot(same(dissolve)));
    shimmer.ignore();
    dissolve.ignore();
  });

  test('resetForTesting forces a fresh Future on the next call', () {
    final before = NibShaderLoader.shimmer();
    NibShaderLoader.resetForTesting();
    final after = NibShaderLoader.shimmer();
    expect(before, isNot(same(after)));
    before.ignore();
    after.ignore();
  });

  test('preloadAll completes without throwing regardless of shader compilation outcome', () async {
    // preloadAll() swallows individual shader load failures internally, so
    // this resolves cleanly whether or not shader compilation is actually
    // supported in this test environment.
    await expectLater(NibShaderLoader.preloadAll(), completes);
  });

  test('asset keys point at this package\'s bundled shader files', () {
    expect(NibShaderAssets.shimmer, 'packages/nib_motion/lib/shaders/shimmer.frag');
    expect(NibShaderAssets.dissolve, 'packages/nib_motion/lib/shaders/dissolve.frag');
    expect(
      NibShaderAssets.gradientSweep,
      'packages/nib_motion/lib/shaders/gradient_sweep.frag',
    );
  });
}

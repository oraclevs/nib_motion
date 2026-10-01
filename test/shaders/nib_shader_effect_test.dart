import 'dart:ui' show FragmentProgram;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _host(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: child);

void main() {
  group('uniform layout', () {
    test('time, size, then uniforms in order', () {
      final a = MotionValue<double>(0.25);
      final b = MotionValue<double>(0.75);
      expect(
        NibShaderEffect.floatsFor(
          time: 2,
          size: const Size(100, 40),
          uniforms: [a, b],
          includeTime: true,
          includeSize: true,
        ),
        [2, 100, 40, 0.25, 0.75],
      );
    });

    test('time and size are optional', () {
      final a = MotionValue<double>(1);
      expect(
        NibShaderEffect.floatsFor(
          time: 9,
          size: const Size(1, 1),
          uniforms: [a],
          includeTime: false,
          includeSize: false,
        ),
        [1],
      );
      expect(
        NibShaderEffect.floatsFor(
          time: 9,
          size: const Size(5, 6),
          uniforms: const [],
          includeTime: false,
          includeSize: true,
        ),
        [5, 6],
      );
    });

    test('reads live values at call time', () {
      final a = MotionValue<double>(1);
      List<double> read() => NibShaderEffect.floatsFor(
            time: 0,
            size: Size.zero,
            uniforms: [a],
            includeTime: false,
            includeSize: false,
          );
      expect(read(), [1]);
      a.value = 2;
      expect(read(), [2]);
    });
  });

  group('NibShaderEffect widget', () {
    testWidgets('requires exactly one of program / asset', (tester) async {
      expect(
          () => NibShaderEffect(child: const SizedBox()), throwsAssertionError);
    });

    testWidgets('paints the child while the shader is loading', (tester) async {
      await tester.pumpWidget(_host(const NibShaderEffect(
        asset: NibShaderAssets.shimmer,
        child: Text('content', textDirection: TextDirection.ltr),
      )));
      expect(find.text('content'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a missing asset reports the error and keeps the child',
        (tester) async {
      Object? error;
      await tester.pumpWidget(_host(NibShaderEffect(
        asset: 'shaders/does_not_exist.frag',
        onLoadError: (e) => error = e,
        child: const Text('content', textDirection: TextDirection.ltr),
      )));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      expect(error, isNotNull);
      expect(find.text('content'), findsOneWidget);
    });

    testWidgets('enabled:false never starts the time ticker', (tester) async {
      await tester.pumpWidget(_host(const NibShaderEffect(
        asset: NibShaderAssets.shimmer,
        includeTime: true,
        enabled: false,
        child: SizedBox(width: 10, height: 10),
      )));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('includeTime runs a ticker; reduced motion does not',
        (tester) async {
      await tester.pumpWidget(_host(const NibShaderEffect(
        asset: NibShaderAssets.shimmer,
        includeTime: true,
        child: SizedBox(width: 10, height: 10),
      )));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      NibMotionConfig.setReducedMotion(true);
      addTearDown(() => NibMotionConfig.setReducedMotion(null));
      await tester.pumpWidget(_host(const NibShaderEffect(
        asset: NibShaderAssets.shimmer,
        includeTime: true,
        child: SizedBox(width: 10, height: 11),
      )));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('unmount mid-run leaves no ticker and no listeners',
        (tester) async {
      final u = MotionValue<double>(0);
      await tester.pumpWidget(_host(NibShaderEffect(
        asset: NibShaderAssets.shimmer,
        includeTime: true,
        uniforms: [u],
        child: const SizedBox(width: 10, height: 10),
      )));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox());
      expect(tester.binding.transientCallbackCount, 0);
      u.value =
          1; // would fail if a disposed render object were still listening
      expect(u.hasListeners, isFalse);
    });

    testWidgets('with a real program: uniform change repaints, no rebuild',
        (tester) async {
      // Inside this package's own tests the shader asset key is the root one.
      FragmentProgram? program;
      await tester.runAsync(() async {
        program = await FragmentProgram.fromAsset('lib/shaders/shimmer.frag');
      });
      expect(program, isNotNull, reason: 'the real shader must load');
      var builds = 0;
      final u = MotionValue<double>(1);
      await tester.pumpWidget(_host(NibShaderEffect(
        program: program,
        uniforms: [u], // shimmer.frag: uTime, uSpeed, ... (layout differs)
        includeSize: false,
        child: Builder(builder: (_) {
          builds++;
          return const SizedBox(width: 40, height: 40);
        }),
      )));
      final mounted = builds;
      u.value = 2;
      await tester.pump();
      u.value = 3;
      await tester.pump();
      expect(builds, mounted);
      expect(tester.takeException(), isNull);
    });
  });
}

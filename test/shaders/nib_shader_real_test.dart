// Real-shader smoke tests. Inside this package's own `flutter test` the
// bundled shaders resolve under the root-package asset key; the loader's
// `assetKeyResolver` hook points the widgets at it.
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

const _shot = ValueKey('shot');

Widget _host(Widget child, {Size size = const Size(100, 60)}) => Directionality(
      textDirection: TextDirection.ltr,
      child: NibMotionConfig(
        reducedMotion: false,
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: _shot,
            child:
                SizedBox(width: size.width, height: size.height, child: child),
          ),
        ),
      ),
    );

Future<Color> _pixel(WidgetTester tester, Offset p) async {
  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(_shot));
  final c = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final i = (p.dy.round() * image.width + p.dx.round()) * 4;
    return Color.fromARGB(data.getUint8(i + 3), data.getUint8(i),
        data.getUint8(i + 1), data.getUint8(i + 2));
  });
  return c!;
}

void main() {
  setUp(() {
    NibShaderLoader.resetForTesting();
    NibShaderLoader.assetKeyResolver =
        (key) => key.replaceFirst('packages/nib_motion/', '');
  });
  tearDown(NibShaderLoader.resetForTesting);

  testWidgets('the resolver hook loads every bundled shader', (tester) async {
    await tester.runAsync(() async {
      await NibShaderLoader.shimmer();
      await NibShaderLoader.dissolve();
      await NibShaderLoader.gradientSweep();
      await NibShaderLoader.liquidGlass();
    });
  });

  testWidgets('NibShimmer recolours its child with the shader', (tester) async {
    await tester.runAsync(NibShaderLoader.shimmer);
    Widget shimmer({required bool enabled}) => _host(NibShimmer(
          enabled: enabled,
          baseColor: const Color(0xFFFF0000),
          shimmerColor: const Color(0xFFFFFF00),
          child: const ColoredBox(color: Color(0xFFFFFFFF)),
        ));
    await tester.pumpWidget(shimmer(enabled: false));
    await tester.pump();
    final plain = await _pixel(tester, const Offset(50, 30));
    expect(plain, const Color(0xFFFFFFFF), reason: 'disabled: child untouched');

    await tester.pumpWidget(shimmer(enabled: true));
    await tester.pump(); // program future resolves
    await tester.pump(const Duration(milliseconds: 300));
    final on = await _pixel(tester, const Offset(50, 30));
    expect(on.a, greaterThan(0.5));
    expect(on, isNot(plain), reason: 'the shader replaced the white child');
    expect(on.r, greaterThan(on.b),
        reason: 'red base / yellow highlight, not white or blue');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('NibDissolve outward: visible at start, gone at the end',
      (tester) async {
    await tester.runAsync(NibShaderLoader.dissolve);
    var done = false;
    await tester.pumpWidget(_host(NibDissolve(
      duration: const Duration(milliseconds: 400),
      onComplete: () => done = true,
      child: const ColoredBox(color: Color(0xFF00AA00)),
    )));
    await tester.pump();
    final start = await _pixel(tester, const Offset(50, 30));
    expect(start.g, greaterThan(0.5), reason: 'child visible at progress 0');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(done, isTrue);
    final end = await _pixel(tester, const Offset(50, 30));
    expect(end.a, lessThan(0.2), reason: 'fully dissolved at progress 1');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('NibShaderEffect with a real program loads and paints',
      (tester) async {
    final u = MotionValue<double>(1);
    await tester.runAsync(NibShaderLoader.shimmer);
    await tester.pumpWidget(_host(NibShaderEffect(
      asset: NibShaderAssets.shimmer,
      includeTime: true,
      includeSize: false,
      uniforms: [u],
      child: const SizedBox(width: 100, height: 60),
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    u.value = 2;
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    expect(u.hasListeners, isFalse);
  });
}

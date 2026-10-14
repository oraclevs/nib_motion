// `NibShaderEffect(sampleChild: true)` feeds the child's pixels to the shader
// as sampler 0 via `ImageFilter.shader`, which needs Impeller. Pixel tests run
// with `flutter test --enable-impeller test/shaders`; under the default
// renderer the widget must fall back to painting the child untouched.
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

const _shot = ValueKey('shot');
const _w = 120.0, _h = 80.0;

Widget _host(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: NibMotionConfig(
        reducedMotion: false,
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: _shot,
            child: SizedBox(width: _w, height: _h, child: child),
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

/// Uniforms after the size pair for `liquid_glass.frag`: radius, thickness,
/// refractive index, chromatic aberration, saturation, light intensity,
/// light (2), tint rgba (4), origin (2), glass size (2).
List<MotionValue<double>> _glassUniforms({required Color tint}) => [
      for (final v in <double>[
        0, // radius
        1, // thickness
        1.0, // refractive index
        0, // chromatic aberration
        1, // saturation
        0, // light intensity
        0, 0, // light direction
        tint.r, tint.g, tint.b, tint.a,
        0, 0, // origin
        _w, _h, // glass size
      ])
        MotionValue<double>(v),
    ];

void main() {
  setUp(() {
    NibShaderLoader.resetForTesting();
    NibShaderLoader.assetKeyResolver =
        (key) => key.replaceFirst('packages/nib_motion/', '');
    TestWidgetsFlutterBinding.ensureInitialized();
  });
  tearDown(NibShaderLoader.resetForTesting);

  test('sampleChild requires the size uniform (first vec2)', () {
    expect(
      () => NibShaderEffect(
        asset: NibShaderAssets.liquidGlass,
        sampleChild: true,
        includeSize: false,
        child: const SizedBox(),
      ),
      throwsAssertionError,
    );
    // The default overlay mode is unaffected.
    NibShaderEffect(
      asset: NibShaderAssets.liquidGlass,
      includeSize: false,
      child: const SizedBox(),
    );
  });

  testWidgets('without Impeller support the child paints untouched',
      (tester) async {
    if (ui.ImageFilter.isShaderFilterSupported) {
      return; // covered by the Impeller test below
    }
    await tester.runAsync(NibShaderLoader.liquidGlass);
    await tester.pumpWidget(_host(NibShaderEffect(
      asset: NibShaderAssets.liquidGlass,
      sampleChild: true,
      uniforms: _glassUniforms(tint: const Color(0xFFFF0000)),
      child: const ColoredBox(color: Color(0xFFFFFFFF)),
    )));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(await _pixel(tester, const Offset(60, 40)), const Color(0xFFFFFFFF));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Impeller: the shader receives and transforms the child pixels',
      (tester) async {
    if (!ui.ImageFilter.isShaderFilterSupported) {
      return; // run with --enable-impeller
    }
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(NibShaderLoader.liquidGlass);

    final tint = _glassUniforms(tint: const Color(0x00FF0000));
    await tester.pumpWidget(_host(NibShaderEffect(
      asset: NibShaderAssets.liquidGlass,
      sampleChild: true,
      uniforms: tint,
      child: const ColoredBox(color: Color(0xFFFFFFFF)),
    )));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    final untinted = await _pixel(tester, const Offset(60, 40));
    expect(untinted.g, greaterThan(0.8),
        reason: 'no tint: the child sampled through the shader stays light');

    // Opaque red tint: the output is now the shader's, not the child's.
    tint[8].value = 1; // r
    tint[9].value = 0; // g
    tint[10].value = 0; // b
    tint[11].value = 1; // a
    await tester.pump();
    final tinted = await _pixel(tester, const Offset(60, 40));
    expect(tinted.r, greaterThan(0.8));
    expect(tinted.g, lessThan(0.3),
        reason: 'the live uniform changed what the shader drew');
    await tester.pumpWidget(const SizedBox());
  });
}

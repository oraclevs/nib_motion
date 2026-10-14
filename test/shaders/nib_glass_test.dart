import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

const _shot = ValueKey('shot');

/// Vertical red/blue stripes behind a glass pane.
Widget _backdrop(Widget glass, {double w = 200, double h = 120}) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: _shot,
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(children: [
              Row(children: [
                for (var i = 0; i < 10; i++)
                  Expanded(
                    child: ColoredBox(
                      color: i.isEven
                          ? const Color(0xFFD32F2F)
                          : const Color(0xFF1976D2),
                      child: const SizedBox.expand(),
                    ),
                  ),
              ]),
              Positioned(
                  left: 40, top: 20, width: 120, height: 80, child: glass),
            ]),
          ),
        ),
      ),
    );

Future<List<int>> _bytes(WidgetTester tester) async {
  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(_shot));
  final out = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    return data.buffer.asUint8List().toList();
  });
  return out!;
}

void main() {
  setUp(() {
    NibShaderLoader.resetForTesting();
    NibShaderLoader.assetKeyResolver =
        (key) => key.replaceFirst('packages/nib_motion/', '');
  });
  tearDown(NibShaderLoader.resetForTesting);

  group('NibGlass', () {
    testWidgets('the real liquid_glass program loads', (tester) async {
      final program = await tester.runAsync(NibShaderLoader.liquidGlass);
      expect(program, isNotNull);
      // A uniform-count smoke check: 18 floats (see the setFloat order in
      // nib_glass.dart: uSize, radius, thickness, index, chroma, saturation,
      // intensity, light, tint, origin, glass size).
      final shader = program!.fragmentShader();
      for (var i = 0; i < 18; i++) {
        shader.setFloat(i, 0.5);
      }
      expect(() => shader.setFloat(18, 0), throwsA(anything),
          reason: 'the .frag declares exactly 18 float uniforms');
      shader.dispose();
    });

    testWidgets('renders over a backdrop with every parameter set',
        (tester) async {
      await tester.runAsync(NibShaderLoader.liquidGlass);
      await tester.pumpWidget(_backdrop(const NibGlass(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        blurSigma: 2,
        tint: Color(0x33FFFFFF),
        thickness: 24,
        refractiveIndex: 1.4,
        chromaticAberration: 0.05,
        saturation: 1.5,
        highlight: 0.8,
        lightDirection: Offset(0.3, -1),
        child: SizedBox.expand(),
      )));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(NibGlass), findsOneWidget);
    });

    testWidgets('falls back when the shader asset is unavailable',
        (tester) async {
      NibShaderLoader.assetKeyResolver = (key) => 'does/not/exist.frag';
      await tester.pumpWidget(_backdrop(const NibGlass(
        child: Center(child: SizedBox(width: 10, height: 10)),
      )));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets,
          reason: 'fallback paints its own tint and rim');
    });

    testWidgets('fallback painter changes with tint, highlight and light',
        (tester) async {
      // Force the fallback even under Impeller: no shader asset.
      NibShaderLoader.assetKeyResolver = (key) => 'does/not/exist.frag';
      Future<List<int>> shot(NibGlass glass) async {
        await tester.pumpWidget(_backdrop(glass));
        await tester.pump();
        return _bytes(tester);
      }

      const child = SizedBox.expand();
      final base = await shot(const NibGlass(child: child));
      final tinted =
          await shot(const NibGlass(tint: Color(0xAAFF00FF), child: child));
      final lit = await shot(const NibGlass(
          highlight: 1, lightDirection: Offset(1, 1), child: child));
      final dark = await shot(const NibGlass(highlight: 0, child: child));
      expect(tinted, isNot(base));
      expect(lit, isNot(base));
      expect(dark, isNot(base));
    });

    testWidgets('parameters can change at runtime without errors',
        (tester) async {
      await tester.runAsync(NibShaderLoader.liquidGlass);
      for (final t in [8.0, 30.0, 0.0]) {
        await tester.pumpWidget(_backdrop(NibGlass(
          thickness: t,
          refractiveIndex: 1 + t / 100,
          blurSigma: t / 10,
          child: const SizedBox.expand(),
        )));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('survives zero size, NaN light, zero sigma and a clipper',
        (tester) async {
      await tester.runAsync(NibShaderLoader.liquidGlass);
      await tester.pumpWidget(_backdrop(const NibGlass(
        blurSigma: 0,
        lightDirection: Offset(double.nan, double.nan),
        child: SizedBox.expand(),
      )));
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child:
              SizedBox(width: 0, height: 0, child: NibGlass(child: SizedBox())),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(_backdrop(NibGlass(
        clipper: _CapsuleClipper(),
        child: const SizedBox.expand(),
      )));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(ClipPath), findsOneWidget);
    });

    testWidgets('unmounting mid-load does not throw (disposal)',
        (tester) async {
      await tester.pumpWidget(_backdrop(const NibGlass(child: SizedBox())));
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 100))); // load completes after unmount
      expect(tester.takeException(), isNull);
    });

    testWidgets('debugShaderPathAvailable is false without Impeller',
        (tester) async {
      final ok = await tester.runAsync(NibGlass.debugShaderPathAvailable);
      // The test harness has no Impeller image-filter shaders.
      expect(ok, ui.ImageFilter.isShaderFilterSupported);
    });

    testWidgets('reduced motion does not change how glass renders',
        (tester) async {
      // Glass is a static material (no animation of its own).
      await tester.pumpWidget(NibMotionConfig(
        reducedMotion: true,
        child: _backdrop(const NibGlass(child: SizedBox.expand())),
      ));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('glass NibNavBar', () {
    testWidgets('builds inside NibScaffold with glass: true', (tester) async {
      await tester.runAsync(NibShaderLoader.liquidGlass);
      await tester.pumpWidget(MaterialApp(
        home: NibScaffold(
          screens: [
            NibNavScreen(child: SizedBox.expand()),
            NibNavScreen(child: SizedBox.expand())
          ],
          navItems: [
            NibNavItem(icon: Icon(Icons.home)),
            NibNavItem(icon: Icon(Icons.search)),
          ],
          navBarStyle: NibNavBarStyle(glass: true, glassBlur: 4),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(NibGlass), findsOneWidget);
    });

    testWidgets('a non-glass bar has no NibGlass', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: NibScaffold(
          screens: [
            NibNavScreen(child: SizedBox.expand()),
            NibNavScreen(child: SizedBox.expand())
          ],
          navItems: [
            NibNavItem(icon: Icon(Icons.home)),
            NibNavItem(icon: Icon(Icons.search)),
          ],
        ),
      ));
      await tester.pump();
      expect(find.byType(NibGlass), findsNothing);
    });
  });
}

class _CapsuleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size, Radius.circular(size.shortestSide / 2)));

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

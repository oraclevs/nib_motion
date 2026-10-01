// Pixel tests of the real `liquid_glass.frag` path. `ImageFilter.shader`
// needs Impeller, so these only run with:
//   flutter test --enable-impeller test/shaders/nib_glass_shader_path_test.dart
// (they report themselves skipped under the default Skia test renderer).
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

const _shot = ValueKey('shot');
const _w = 300, _h = 180;

Widget _scene(NibGlass glass,
        {bool gray = false, Offset at = const Offset(50, 30)}) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: _shot,
          child: SizedBox(
            width: _w.toDouble(),
            height: _h.toDouble(),
            child: Stack(children: [
              Row(children: [
                for (var i = 0; i < 15; i++)
                  Expanded(
                    child: ColoredBox(
                      color: gray
                          ? (i.isEven
                              ? const Color(0xFF303030)
                              : const Color(0xFFB0B0B0))
                          : (i.isEven
                              ? const Color(0xFFD32F2F)
                              : const Color(0xFFFFEB3B)),
                      child: const SizedBox.expand(),
                    ),
                  ),
              ]),
              Positioned(
                  left: at.dx,
                  top: at.dy,
                  width: 200,
                  height: 120,
                  child: glass),
            ]),
          ),
        ),
      ),
    );

Future<Uint8List> _render(WidgetTester tester, NibGlass glass,
    {bool gray = false, Offset at = const Offset(50, 30)}) async {
  // Image-filter shaders work in physical pixels; pin DPR 1 so test pixels
  // are logical pixels.
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_scene(glass, gray: gray, at: at));
  for (var i = 0; i < 3; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(
      find.descendant(
          of: find.byType(NibGlass), matching: find.byType(CustomPaint)),
      findsNothing,
      reason: 'the shader path (not the fallback) must be active');
  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(_shot));
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
        .buffer
        .asUint8List();
  });
  return Uint8List.fromList(bytes!);
}

/// Number of pixels whose channels differ by more than [threshold], and the
/// bounding box of those pixels.
({int count, Rect box}) _diff(Uint8List a, Uint8List b, {int threshold = 6}) {
  var count = 0;
  var minX = _w, minY = _h, maxX = -1, maxY = -1;
  for (var y = 0; y < _h; y++) {
    for (var x = 0; x < _w; x++) {
      final i = (y * _w + x) * 4;
      final d = [0, 1, 2]
          .map((c) => (a[i + c] - b[i + c]).abs())
          .reduce((p, q) => p > q ? p : q);
      if (d > threshold) {
        count++;
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
  }
  return (
    count: count,
    box:
        Rect.fromLTRB(minX.toDouble(), minY.toDouble(), maxX + 1.0, maxY + 1.0),
  );
}

void main() {
  setUp(() {
    NibShaderLoader.resetForTesting();
    NibShaderLoader.assetKeyResolver =
        (key) => key.replaceFirst('packages/nib_motion/', '');
  });
  tearDown(NibShaderLoader.resetForTesting);

  bool supported() => ui.ImageFilter.isShaderFilterSupported;

  testWidgets('refraction bends the rim but leaves the flat centre alone',
      (tester) async {
    if (!supported()) return;
    await tester.runAsync(NibShaderLoader.liquidGlass);
    const base = NibGlass(
        thickness: 40,
        chromaticAberration: 0,
        highlight: 0,
        tint: Color(0x00000000),
        saturation: 1,
        blurSigma: 0,
        child: SizedBox.expand());
    final flat = await _render(
        tester,
        const NibGlass(
            thickness: 40,
            refractiveIndex: 1.0,
            chromaticAberration: 0,
            highlight: 0,
            tint: Color(0x00000000),
            saturation: 1,
            blurSigma: 0,
            child: SizedBox.expand()));
    final bent = await _render(tester, base.copy(refractiveIndex: 1.6));
    final d = _diff(flat, bent);
    expect(d.count, greaterThan(50), reason: 'index 1.6 must bend the rim');
    // Glass spans x 50..250, y 30..150 (logical) at DPR 1; the flat centre
    // (more than 40px inside) is untouched.
    final centre = const Rect.fromLTRB(100, 70, 200, 110);
    expect(d.box.overlaps(centre) && _diffIn(flat, bent, centre) > 0, isFalse,
        reason: 'no distortion in the optically flat centre');
  });

  testWidgets('chromatic aberration separates colour channels at the rim',
      (tester) async {
    if (!supported()) return;
    await tester.runAsync(NibShaderLoader.liquidGlass);
    final off = await _render(
        tester,
        const NibGlass(
            thickness: 40,
            refractiveIndex: 1.6,
            chromaticAberration: 0,
            highlight: 0,
            tint: Color(0x00000000),
            saturation: 1,
            blurSigma: 0,
            child: SizedBox.expand()));
    final on = await _render(
        tester,
        const NibGlass(
            thickness: 40,
            refractiveIndex: 1.6,
            chromaticAberration: 0.3,
            highlight: 0,
            tint: Color(0x00000000),
            saturation: 1,
            blurSigma: 0,
            child: SizedBox.expand()));
    expect(_diff(off, on).count, greaterThan(0),
        reason: 'dispersion must change some rim pixels');
  });

  testWidgets(
      'rim highlight is visible on a neutral backdrop and follows '
      'the light direction', (tester) async {
    if (!supported()) return;
    await tester.runAsync(NibShaderLoader.liquidGlass);
    NibGlass glass(double h, Offset light) => NibGlass(
        thickness: 30,
        refractiveIndex: 1.0,
        chromaticAberration: 0,
        highlight: h,
        lightDirection: light,
        tint: const Color(0x00000000),
        saturation: 1,
        blurSigma: 0,
        child: const SizedBox.expand());
    final none =
        await _render(tester, glass(0, const Offset(-1, -1)), gray: true);
    final topLeft =
        await _render(tester, glass(1, const Offset(-1, -1)), gray: true);
    final bottomRight =
        await _render(tester, glass(1, const Offset(1, 1)), gray: true);
    expect(_diff(none, topLeft).count, greaterThan(50),
        reason: 'highlight 1 vs 0 must brighten the rim');
    expect(_diff(topLeft, bottomRight).count, greaterThan(0),
        reason: 'the light direction moves the brightest part of the rim');
  });

  testWidgets(
      'the glass shape is placed at the widget, not at the layer origin',
      (tester) async {
    if (!supported()) return;
    await tester.runAsync(NibShaderLoader.liquidGlass);
    const glass = NibGlass(
        thickness: 40,
        refractiveIndex: 1.6,
        chromaticAberration: 0,
        highlight: 0,
        tint: Color(0x00000000),
        saturation: 1,
        blurSigma: 0,
        child: SizedBox.expand());
    // The stripes repeat every 40px horizontally and are uniform vertically,
    // so a glass moved by (40, 20) must render the same pixels, shifted.
    final a = await _render(tester, glass, at: const Offset(50, 30));
    final b = await _render(tester, glass, at: const Offset(90, 50));
    var different = 0;
    for (var y = 0; y < 120; y++) {
      for (var x = 0; x < 200; x++) {
        final i = ((30 + y) * _w + 50 + x) * 4;
        final j = ((50 + y) * _w + 90 + x) * 4;
        for (var c = 0; c < 3; c++) {
          if ((a[i + c] - b[j + c]).abs() > 12) {
            different++;
            break;
          }
        }
      }
    }
    expect(different, lessThan(150),
        reason: 'refraction must follow the glass wherever it sits in the '
            'layer ($different of 24000 pixels differ)');
  });

  testWidgets('refraction is mirror-symmetric and never samples black',
      (tester) async {
    if (!supported()) return;
    await tester.runAsync(NibShaderLoader.liquidGlass);
    final px = await _render(
        tester,
        const NibGlass(
            thickness: 40,
            refractiveIndex: 1.6,
            chromaticAberration: 0,
            highlight: 0,
            tint: Color(0x00000000),
            saturation: 1,
            blurSigma: 0,
            child: SizedBox.expand()));
    // Backdrop stripes are symmetric about x=150, the glass is centred there.
    var asym = 0;
    for (var y = 30; y < 150; y++) {
      for (var x = 50; x < 150; x++) {
        final i = (y * _w + x) * 4, j = (y * _w + (299 - x)) * 4;
        if ((px[i] - px[j]).abs() > 12 || (px[i + 1] - px[j + 1]).abs() > 12) {
          asym++;
        }
      }
    }
    expect(asym, lessThan(100), reason: '$asym asymmetric pixels');
    // The backdrop is red/yellow: nothing inside the glass may be near-black
    // (that would be the transparent border of the backdrop texture).
    var dark = 0;
    for (var y = 32; y < 148; y++) {
      for (var x = 52; x < 248; x++) {
        final i = (y * _w + x) * 4;
        if (px[i] < 60 && px[i + 1] < 60 && px[i + 2] < 60) dark++;
      }
    }
    expect(dark, 0, reason: '$dark near-black pixels inside the glass');
  });

  testWidgets('tint and saturation change the interior', (tester) async {
    if (!supported()) return;
    await tester.runAsync(NibShaderLoader.liquidGlass);
    NibGlass glass({Color tint = const Color(0x00000000), double sat = 1}) =>
        NibGlass(
            thickness: 20,
            refractiveIndex: 1.0,
            chromaticAberration: 0,
            highlight: 0,
            tint: tint,
            saturation: sat,
            blurSigma: 0,
            child: const SizedBox.expand());
    final plain = await _render(tester, glass());
    final tinted = await _render(tester, glass(tint: const Color(0x800000FF)));
    final sat = await _render(tester, glass(sat: 0));
    final centre = const Rect.fromLTRB(100, 70, 200, 110);
    expect(_diffIn(plain, tinted, centre), greaterThan(1000));
    expect(_diffIn(plain, sat, centre), greaterThan(1000),
        reason: 'saturation 0 desaturates the backdrop seen through glass');
  });
}

int _diffIn(Uint8List a, Uint8List b, Rect r, {int threshold = 6}) {
  var count = 0;
  for (var y = r.top.toInt(); y < r.bottom; y++) {
    for (var x = r.left.toInt(); x < r.right; x++) {
      final i = (y * _w + x) * 4;
      for (var c = 0; c < 3; c++) {
        if ((a[i + c] - b[i + c]).abs() > threshold) {
          count++;
          break;
        }
      }
    }
  }
  return count;
}

extension on NibGlass {
  NibGlass copy({double? refractiveIndex}) => NibGlass(
        thickness: thickness,
        refractiveIndex: refractiveIndex ?? this.refractiveIndex,
        chromaticAberration: chromaticAberration,
        highlight: highlight,
        tint: tint,
        saturation: saturation,
        blurSigma: blurSigma,
        child: child,
      );
}

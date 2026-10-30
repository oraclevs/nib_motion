import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Future<void> _ready(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  }
}

Future<Uint8List> _pixels(
    WidgetTester tester, GlobalKey key, double dpr) async {
  return (await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage(pixelRatio: dpr);
    try {
      return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer
          .asUint8List();
    } finally {
      image.dispose();
    }
  }))!;
}

void main() {
  setUp(() {
    NibShaderLoader.resetForTesting();
    NibShaderLoader.assetKeyResolver =
        (key) => key.replaceFirst('packages/nib_motion/', '');
  });
  tearDown(NibShaderLoader.resetForTesting);

  for (final (dpr, extent) in [
    (1.0, 64.0),
    (1.5, 64.0),
    (3.0, 64.0),
    (1.5, 63.3)
  ]) {
    testWidgets(
        'neutral sampled water preserves physical lines at DPR $dpr size $extent',
        (tester) async {
      await tester.runAsync(() => NibShaderLoader.load(
          'packages/nib_motion/lib/shaders/water_material.frag'));
      final controller = NibWaterController(
          drops: const [],
          config: const NibWaterConfig(refraction: 0, highlight: 0));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      });
      final key = GlobalKey();
      Widget scene(bool water) {
        final source = CustomPaint(painter: _Lines(dpr));
        return MaterialApp(
            home: MediaQuery(
                data: MediaQueryData(
                    size: const Size(800, 600), devicePixelRatio: dpr),
                child: Center(
                    child: RepaintBoundary(
                  key: key,
                  child: SizedBox(
                      width: extent,
                      height: extent,
                      child: water
                          ? NibWaterSurface(
                              controller: controller,
                              sampling: NibWaterSampling.live,
                              surface: true,
                              background: source)
                          : source),
                ))));
      }

      await tester.pumpWidget(scene(false));
      final direct = await _pixels(tester, key, dpr);
      await tester.pumpWidget(scene(true));
      await _ready(tester);
      final sampled = await _pixels(tester, key, dpr);
      var error = 0;
      for (var i = 0; i < direct.length; i++) {
        error += (direct[i] - sampled[i]).abs();
      }
      final mean = error / direct.length;
      debugPrint('neutral DPR=$dpr mean channel error=$mean / 255');
      expect(mean, lessThanOrEqualTo(3),
          reason: 'Forced shader sampling must retain physical-pixel detail.');
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('nested transform and opacity match direct pixels each frame',
      (tester) async {
    await tester.runAsync(() => NibShaderLoader.load(
        'packages/nib_motion/lib/shaders/water_material.frag'));
    final water = NibWaterController(drops: const []);
    final phase = ValueNotifier<int>(0);
    final directKey = GlobalKey(), waterKey = GlobalKey();
    Widget source() => AnimatedBuilder(
        animation: phase,
        child:
            const RepaintBoundary(child: ColoredBox(color: Color(0xFF804020))),
        builder: (_, child) => Transform.translate(
            offset: Offset(phase.value * 2, 0),
            child: Opacity(opacity: .25 + phase.value * .15, child: child)));
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data:
                const MediaQueryData(size: Size(800, 600), devicePixelRatio: 1),
            child: Center(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
              RepaintBoundary(
                  key: directKey,
                  child: SizedBox(width: 64, height: 64, child: source())),
              RepaintBoundary(
                  key: waterKey,
                  child: SizedBox(
                      width: 64,
                      height: 64,
                      child: NibWaterSurface(
                          controller: water,
                          sampling: NibWaterSampling.live,
                          material: NibWaterMaterial.neutral,
                          surface: true,
                          background: source()))),
            ])))));
    await _ready(tester);
    for (var i = 0; i < 4; i++) {
      phase.value = i;
      await tester.pump(const Duration(milliseconds: 16));
      final direct = await _pixels(tester, directKey, 1);
      final sample = await _pixels(tester, waterKey, 1);
      var error = 0;
      for (var n = 0; n < direct.length; n++) {
        error += (direct[n] - sample[n]).abs();
      }
      expect(error / direct.length, lessThanOrEqualTo(1));
    }
    await tester.pumpWidget(const SizedBox());
    phase.dispose();
    water.dispose();
  });

  testWidgets('neutral sampled transparency is composited once',
      (tester) async {
    await tester.runAsync(() => NibShaderLoader.load(
        'packages/nib_motion/lib/shaders/water_material.frag'));
    final controller = NibWaterController(
        drops: const [],
        config: const NibWaterConfig(refraction: 0, highlight: 0));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
    final key = GlobalKey();
    Widget scene(bool water) {
      const source = ColoredBox(color: Color(0x80800000));
      return Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
              child: RepaintBoundary(
                  key: key,
                  child: SizedBox(
                      width: 64,
                      height: 64,
                      child: water
                          ? NibWaterSurface(
                              controller: controller,
                              sampling: NibWaterSampling.live,
                              surface: true,
                              background: source)
                          : source))));
    }

    await tester.pumpWidget(scene(false));
    final direct = await _pixels(tester, key, 1);
    await tester.pumpWidget(scene(true));
    await _ready(tester);
    final sampled = await _pixels(tester, key, 1);
    debugPrint('neutral alpha direct=${direct[3]} sampled=${sampled[3]}');
    expect((direct[3] - sampled[3]).abs(), lessThanOrEqualTo(1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('nested paint-only source is sampled in the current frame',
      (tester) async {
    await tester.runAsync(() => NibShaderLoader.load(
        'packages/nib_motion/lib/shaders/water_material.frag'));
    final controller = NibWaterController(
        drops: const [],
        config: const NibWaterConfig(refraction: 0, highlight: 0));
    final phase = ValueNotifier<int>(0);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
    addTearDown(phase.dispose);
    final key = GlobalKey();
    await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
            child: RepaintBoundary(
                key: key,
                child: SizedBox(
                    width: 64,
                    height: 64,
                    child: NibWaterSurface(
                        controller: controller,
                        sampling: NibWaterSampling.live,
                        surface: true,
                        background: RepaintBoundary(
                            child: CustomPaint(painter: _Phase(phase)))))))));
    await _ready(tester);
    for (var sequence = 1; sequence <= 4; sequence++) {
      phase.value = sequence;
      await tester.pump(const Duration(milliseconds: 16));
      final pixels = await _pixels(tester, key, 1);
      debugPrint('source sequence=$sequence presented red=${pixels[0]}');
      expect(pixels[0], sequence * 40,
          reason: 'Nested paint changes must not show an older sample.');
    }
    await tester.pumpWidget(const SizedBox());
  });
}

class _Lines extends CustomPainter {
  _Lines(this.dpr);
  final double dpr;
  @override
  void paint(Canvas canvas, Size size) {
    for (var x = 0; x < (size.width * dpr).ceil(); x++) {
      canvas.drawRect(
          Rect.fromLTWH(x / dpr, 0, 1 / dpr, size.height),
          Paint()
            ..isAntiAlias = false
            ..color = x.isEven ? Colors.black : Colors.white);
    }
  }

  @override
  bool shouldRepaint(_Lines old) => old.dpr != dpr;
}

class _Phase extends CustomPainter {
  _Phase(this.phase) : super(repaint: phase);
  final ValueNotifier<int> phase;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawRect(Offset.zero & size,
      Paint()..color = Color.fromARGB(255, phase.value * 40, 0, 0));
  @override
  bool shouldRepaint(_Phase old) => old.phase != phase;
}

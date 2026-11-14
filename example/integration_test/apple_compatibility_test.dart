import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nib_motion/nib_motion.dart';

const _evidence = String.fromEnvironment('NIB_QA_SCREENSHOT_DIR');
final _shot = GlobalKey();

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: _shot,
            child: SizedBox(width: 240, height: 180, child: child),
          ),
        ),
      ),
    );

Future<void> _frames(WidgetTester tester, [int count = 8]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
  }
}

Future<Uint8List> _pixels(WidgetTester tester) async {
  final boundary =
      _shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      return Uint8List.fromList(
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
              .buffer
              .asUint8List());
    } finally {
      image.dispose();
    }
  }))!;
}

Future<void> _screenshot(WidgetTester tester, String name) async {
  if (!Platform.isMacOS || _evidence.isEmpty) return;
  final boundary =
      _shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      return (await image.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
    } finally {
      image.dispose();
    }
  });
  await File('$_evidence/$name.png').writeAsBytes(bytes!);
}

Widget _stripes() => Row(children: [
      for (var i = 0; i < 12; i++)
        Expanded(
          child: ColoredBox(
            color: i.isEven ? const Color(0xFF1846C0) : const Color(0xFFF5D341),
            child: const SizedBox.expand(),
          ),
        ),
    ]);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('QA-WATER-01 Metal water renders and responds to twelve impulses',
      (tester) async {
    final controller = NibWaterController(
      drops: List.generate(
          10,
          (i) => NibWaterDrop(
                id: i + 1,
                center: Offset(12 + i * 24.0, 90),
                radius: 16,
              )),
    );
    expect(controller.drops, hasLength(10));
    final reports = <NibWaterRenderStatus>[];
    await tester.pumpWidget(_host(NibWaterSurface(
      controller: controller,
      sampling: NibWaterSampling.live,
      surface: true,
      background: _stripes(),
      onStatus: reports.add,
    )));
    await _frames(tester, 20);
    expect(reports.any((r) => r.path == NibWaterRenderPath.refractive), isTrue);
    final before = await _pixels(tester);
    for (var i = 0; i < 12; i++) {
      controller.disturb(Offset(30 + i * 16.0, 90), strength: 24);
    }
    expect(controller.impulses, hasLength(12));
    await _frames(tester, 5);
    final after = await _pixels(tester);
    expect(after, isNot(equals(before)));
    await _screenshot(tester, 'water');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('QA-WATER-02 all sampling policies mount and dispose',
      (tester) async {
    for (final policy in NibWaterSampling.values) {
      final controller = NibWaterController(drops: const []);
      final reports = <NibWaterRenderStatus>[];
      await tester.pumpWidget(_host(NibWaterSurface(
        controller: controller,
        sampling: policy,
        surface: true,
        background: _stripes(),
        onStatus: reports.add,
      )));
      await _frames(tester, 20);
      expect(
          reports.any((r) => r.path == NibWaterRenderPath.refractive), isTrue,
          reason: '$policy did not bind a shader sample');
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('QA-GLASS-01 Impeller glass refracts a live backdrop',
      (tester) async {
    expect(await NibGlass.debugShaderPathAvailable(), isTrue);
    await tester.pumpWidget(_host(Stack(fit: StackFit.expand, children: [
      _stripes(),
      const Center(
        child: SizedBox(
          width: 180,
          height: 120,
          child: NibGlass(child: SizedBox.expand()),
        ),
      ),
    ])));
    await _frames(tester);
    final image = await _pixels(tester);
    expect(image.any((v) => v != 0), isTrue);
    await _screenshot(tester, 'glass');
    expect(tester.takeException(), isNull);
  });

  testWidgets('QA-DISSOLVE-01 dissolved pixels reveal the backdrop',
      (tester) async {
    await NibShaderLoader.dissolve();
    await tester.pumpWidget(_host(const Stack(fit: StackFit.expand, children: [
      ColoredBox(color: Color(0xFFFF0000)),
      NibDissolve(
        duration: Duration(seconds: 2),
        child: ColoredBox(color: Color(0xFF00FF00)),
      ),
    ])));
    await _frames(tester);
    expect(find.byType(Opacity), findsNothing);
    await tester.pump(const Duration(milliseconds: 1000));
    await _frames(tester);
    final image = await _pixels(tester);
    var red = 0, green = 0;
    for (var i = 0; i < image.length; i += 4) {
      if (image[i] > 200 && image[i + 1] < 50) red++;
      if (image[i + 1] > 200 && image[i] < 50) green++;
    }
    expect(red, greaterThan(0));
    expect(green, greaterThan(0));
    await _screenshot(tester, 'dissolve');
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('QA-SHADERS-01 every bundled shader creates a program',
      (tester) async {
    await Future.wait([
      NibShaderLoader.shimmer(),
      NibShaderLoader.dissolve(),
      NibShaderLoader.gradientSweep(),
      NibShaderLoader.liquidGlass(),
      NibShaderLoader.load('packages/nib_motion/lib/shaders/nav_water.frag'),
      NibShaderLoader.load(
          'packages/nib_motion/lib/shaders/water_material.frag'),
    ]);
  });

  testWidgets(
      'QA-MOTION-01 retargeting and reduced motion remain interruptible',
      (tester) async {
    final controller = NibMotionController();
    await tester.pumpWidget(_host(NibMotion(
      controller: controller,
      transition: NibTransition.springGentle,
      child: const ColoredBox(color: Colors.blue),
    )));
    controller.start(target: const NibAnim(x: 100));
    await tester.pump(const Duration(milliseconds: 100));
    final moving = controller.motionValueOf(NibProperty.x)!;
    final position = moving.value;
    controller.start(target: const NibAnim(x: 0));
    expect(moving.value, closeTo(position, 0.001));
    await _frames(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();

    final water = NibWaterController(drops: const []);
    await tester.pumpWidget(_host(NibWaterSurface(
      controller: water,
      surface: true,
      reducedMotion: true,
      background: _stripes(),
    )));
    await _frames(tester, 2);
    water.disturb(const Offset(120, 90));
    expect(water.impulses, isEmpty);
    await tester.pumpWidget(const SizedBox());
    water.dispose();
  });

  testWidgets('QA-LIFECYCLE-01 pause and resume preserve water resources',
      (tester) async {
    final controller = NibWaterController(drops: const []);
    final reports = <NibWaterRenderStatus>[];
    await tester.pumpWidget(_host(NibWaterSurface(
      controller: controller,
      sampling: NibWaterSampling.live,
      surface: true,
      background: _stripes(),
      onStatus: reports.add,
    )));
    await _frames(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _frames(tester);
    expect(reports.any((r) => r.path == NibWaterRenderPath.refractive), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('QA-PERF-01 fixed interaction workload records elapsed time',
      (tester) async {
    final controller = NibWaterController(drops: const []);
    await tester.pumpWidget(_host(NibWaterSurface(
      controller: controller,
      sampling: NibWaterSampling.live,
      surface: true,
      background: _stripes(),
    )));
    await _frames(tester);
    final timer = Stopwatch()..start();
    for (var i = 0; i < 40; i++) {
      controller.disturb(Offset(20 + (i % 10) * 20.0, 90));
      await tester.pump(const Duration(milliseconds: 16));
    }
    timer.stop();
    debugPrint('QA-PERF-01 elapsed_us=${timer.elapsedMicroseconds} frames=40');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}

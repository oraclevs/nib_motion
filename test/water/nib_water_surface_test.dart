import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

NibWaterController _controller() => NibWaterController(drops: const [
      NibWaterDrop(id: 1, center: Offset(80, 80), radius: 32),
      NibWaterDrop(id: 2, center: Offset(240, 120), radius: 32),
    ]);

Widget _host(
  NibWaterController controller, {
  Matrix4? transform,
  bool paused = false,
  bool reducedMotion = false,
  bool systemReduced = false,
  bool ticker = true,
  NibWaterInteraction interaction = NibWaterInteraction.disturb,
  bool surface = false,
  Size size = const Size(320, 220),
  Widget background = const ColoredBox(color: Colors.blue),
  Widget? child,
  ValueChanged<NibWaterRenderStatus>? onStatus,
  Listenable? backgroundChanges,
}) =>
    MaterialApp(
        home: MediaQuery(
      data: MediaQueryData(
          size: const Size(800, 600), disableAnimations: systemReduced),
      child: TickerMode(
          enabled: ticker,
          child: Center(
              child: Transform(
            transform: transform ?? Matrix4.identity(),
            alignment: Alignment.center,
            child: SizedBox.fromSize(
                size: size,
                child: NibWaterSurface(
                  controller: controller,
                  background: background,
                  paused: paused,
                  reducedMotion: reducedMotion,
                  interaction: interaction,
                  surface: surface,
                  onStatus: onStatus,
                  backgroundChanges: backgroundChanges,
                  child: child,
                )),
          ))),
    ));

Future<void> _frames(WidgetTester tester, [int count = 4]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Offset _point(WidgetTester tester, Offset local) => tester
    .renderObject<RenderBox>(find.byType(NibWaterSurface))
    .localToGlobal(local);

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  await tester.pump();
  expect(tester.takeException(), isNull);
  expect(tester.binding.transientCallbackCount, 0);
}

void main() {
  setUp(() {
    NibShaderLoader.resetForTesting();
    NibShaderLoader.assetKeyResolver =
        (key) => key.replaceFirst('packages/nib_motion/', '');
  });
  tearDown(NibShaderLoader.resetForTesting);
  for (final entry in <String, Matrix4>{
    'identity': Matrix4.identity(),
    '2x': Matrix4.diagonal3Values(2, 2, 1),
    'nonuniform': Matrix4.diagonal3Values(1.6, .7, 1),
    'rotated': Matrix4.rotationZ(math.pi / 7),
    'nested scale and rotation': Matrix4.rotationZ(-math.pi / 9)
      ..multiply(Matrix4.diagonal3Values(1.4, .8, 1)),
  }.entries) {
    testWidgets(
        '${entry.key}: impulses and drag use receiver-local coordinates',
        (tester) async {
      final controller = _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller, transform: entry.value));
      await _frames(tester, 2);
      const start = Offset(80, 80), end = Offset(112, 97);
      final contact = await tester.startGesture(_point(tester, start));
      expect(controller.impulses, hasLength(1));
      expect(
          (controller.impulses.single.center - start).distance, lessThan(.001));
      await contact.moveTo(_point(tester, end));
      expect(controller.impulses, hasLength(2));
      expect((controller.impulses.last.center - end).distance, lessThan(.001));
      await contact.up();
      expect(controller.activeInputs, 0);
      controller.reset();
      await tester.pumpWidget(_host(controller,
          transform: entry.value,
          interaction: NibWaterInteraction.drag,
          reducedMotion: true));
      await _frames(tester, 2);
      final drag = await tester.startGesture(_point(tester, start));
      expect(controller.activeInputs, 1);
      await drag.moveTo(_point(tester, end));
      expect((controller.drops.first.center - end).distance, lessThan(.001));
      expect(controller.impulses, isEmpty);
      await drag.cancel();
      expect(controller.activeInputs, 0);
      await _unmount(tester);
      expect(controller.isDisposed, isFalse);
    });
  }

  testWidgets(
      'visible mount accepts input; two pointers own distinct bodies only',
      (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester
        .pumpWidget(_host(controller, interaction: NibWaterInteraction.drag));
    await _frames(tester, 2);
    final one = await tester.startGesture(_point(tester, const Offset(80, 80)),
        pointer: 1);
    final duplicate = await tester
        .startGesture(_point(tester, const Offset(85, 80)), pointer: 2);
    final two = await tester
        .startGesture(_point(tester, const Offset(240, 120)), pointer: 3);
    expect(controller.activeInputs, 2);
    await duplicate.up();
    expect(controller.activeInputs, 2);
    await one.moveTo(_point(tester, const Offset(110, 80)));
    await _frames(tester);
    final beforeCancel = controller.drops.first.center;
    await one.cancel();
    expect(controller.activeInputs, 1);
    await _frames(tester);
    expect(controller.drops.first.center, beforeCancel);
    expect(controller.drops.first.velocity, Offset.zero);
    await two.up();
    expect(controller.activeInputs, 0);
    await _unmount(tester);
  });

  testWidgets(
      'normal release preserves target; mode changes cancel ownership and stale moves',
      (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester
        .pumpWidget(_host(controller, interaction: NibWaterInteraction.drag));
    await _frames(tester, 2);
    final drag =
        await tester.startGesture(_point(tester, const Offset(80, 80)));
    await drag.moveTo(_point(tester, const Offset(125, 80)));
    await _frames(tester, 2);
    final released = controller.drops.first.center.dx;
    await drag.up();
    await _frames(tester, 4);
    expect(controller.activeInputs, 0);
    expect(controller.drops.first.center.dx, greaterThan(released));
    final second = await tester
        .startGesture(_point(tester, controller.drops.first.center));
    expect(controller.activeInputs, 1);
    await tester.pumpWidget(_host(controller));
    expect(controller.activeInputs, 0);
    await second.moveBy(const Offset(40, 0));
    expect(controller.impulses, isEmpty);
    await second.up();
    await _unmount(tester);
  });

  testWidgets(
      'full-surface drag setting disturbs instead of translating bodies',
      (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller,
        interaction: NibWaterInteraction.drag, surface: true));
    await _frames(tester, 2);
    final pointer =
        await tester.startGesture(_point(tester, const Offset(80, 80)));
    await pointer.moveBy(const Offset(40, 0));
    expect(controller.activeInputs, 0);
    expect(controller.impulses, hasLength(2));
    expect(controller.drops.first.center, const Offset(80, 80));
    await pointer.up();
    await _unmount(tester);
  });

  testWidgets(
      'system reduced motion wins and disabling it does not replay waves',
      (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller));
    await _frames(tester, 2);
    controller.disturb(const Offset(50, 50));
    await _frames(tester);
    expect(controller.simulationTime, greaterThan(0));
    await tester.pumpWidget(_host(controller, systemReduced: true));
    expect(controller.isReducedMotion, isTrue);
    expect(controller.impulses, isEmpty);
    final time = controller.simulationTime;
    await _frames(tester);
    expect(controller.simulationTime, time);
    await tester.tapAt(_point(tester, const Offset(80, 80)));
    expect(controller.impulses, isEmpty);
    await tester.pumpWidget(_host(controller));
    await _frames(tester);
    expect(controller.isReducedMotion, isFalse);
    expect(controller.simulationTime, time);
    await _unmount(tester);
  });

  testWidgets('package reduced motion settles water and reacts to changes',
      (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    Widget host(bool reduce) => NibMotionConfig(
          reducedMotion: reduce,
          child: _host(controller),
        );
    await tester.pumpWidget(host(false));
    await _frames(tester, 2);
    controller.disturb(const Offset(50, 50));
    await _frames(tester);
    expect(controller.simulationTime, greaterThan(0));
    await tester.pumpWidget(host(true));
    expect(controller.isReducedMotion, isTrue);
    expect(controller.impulses, isEmpty);
    final time = controller.simulationTime;
    await tester.tapAt(_point(tester, const Offset(80, 80)));
    await _frames(tester);
    expect(controller.impulses, isEmpty);
    expect(controller.simulationTime, time);
    await tester.pumpWidget(host(false));
    expect(controller.isReducedMotion, isFalse);
    await _frames(tester);
    expect(controller.simulationTime, time);
    await _unmount(tester);
  });

  for (final policy in ['pause', 'ticker', 'lifecycle']) {
    testWidgets(
        '$policy freezes active simulation, cancels input, discards suspended time',
        (tester) async {
      final controller = _controller();
      addTearDown(controller.dispose);
      await tester
          .pumpWidget(_host(controller, interaction: NibWaterInteraction.drag));
      await _frames(tester, 2);
      final pointer =
          await tester.startGesture(_point(tester, const Offset(80, 80)));
      controller.disturb(const Offset(50, 60));
      await _frames(tester);
      final before = controller.simulationTime;
      expect(before, greaterThan(0));
      expect(controller.activeInputs, 1);
      if (policy == 'lifecycle') {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      } else {
        await tester.pumpWidget(_host(controller,
            interaction: NibWaterInteraction.drag,
            paused: policy == 'pause',
            ticker: policy != 'ticker'));
      }
      expect(controller.activeInputs, 0);
      await tester.pump(const Duration(seconds: 20));
      expect(controller.simulationTime, before);
      if (policy == 'lifecycle') {
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      }
      await tester
          .pumpWidget(_host(controller, interaction: NibWaterInteraction.drag));
      await _frames(tester, 2);
      expect(controller.simulationTime - before, lessThan(.1));
      expect(controller.simulationTime, greaterThan(before));
      await pointer.cancel();
      await _unmount(tester);
    });
  }

  testWidgets(
      'scrolling scene offscreen stops time and resumes without catch-up',
      (tester) async {
    final controller = _controller();
    final scroll = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(scroll.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Center(
            child: SizedBox(
      width: 320,
      height: 240,
      child: SingleChildScrollView(
          controller: scroll,
          child: Column(children: [
            SizedBox(
                height: 200,
                child: NibWaterSurface(
                    controller: controller,
                    background: const ColoredBox(color: Colors.blue))),
            const SizedBox(height: 1200),
          ])),
    ))));
    await _frames(tester, 2);
    controller.disturb(const Offset(80, 80));
    await _frames(tester);
    expect(controller.simulationTime, greaterThan(0));
    scroll.jumpTo(400);
    await _frames(tester, 2);
    final hiddenTime = controller.simulationTime;
    await tester.pump(const Duration(seconds: 20));
    expect(controller.simulationTime, hiddenTime);
    scroll.jumpTo(0);
    await _frames(tester, 3);
    expect(controller.simulationTime, greaterThan(hiddenTime));
    expect(controller.simulationTime - hiddenTime, lessThan(.1));
    await _unmount(tester);
  });

  testWidgets(
      'controller swap and resize preserve external ownership and local bounds',
      (tester) async {
    final first = _controller(), next = _controller();
    addTearDown(first.dispose);
    addTearDown(next.dispose);
    await tester
        .pumpWidget(_host(first, interaction: NibWaterInteraction.drag));
    await _frames(tester, 2);
    final pointer =
        await tester.startGesture(_point(tester, const Offset(80, 80)));
    expect(first.activeInputs, 1);
    await tester.pumpWidget(_host(next, size: const Size(260, 180)));
    await _frames(tester, 2);
    expect(first.activeInputs, 0);
    expect(first.isDisposed, isFalse);
    expect(tester.getSize(find.byType(NibWaterSurface)), const Size(260, 180));
    await pointer.cancel();
    await tester.tapAt(_point(tester, const Offset(210, 130)));
    expect(next.impulses.last.center, const Offset(210, 130));
    expect(first.impulses, isEmpty);
    await _unmount(tester);
    expect(next.isDisposed, isFalse);
    next.disturb(Offset.zero);
    expect(next.impulses, isNotEmpty);
  });

  testWidgets('foreground retains semantic button and focus across merge/split',
      (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    var presses = 0;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_host(controller,
        reducedMotion: true,
        child: Center(
            child: TextButton(
                focusNode: focus,
                onPressed: () => presses++,
                child: const Text('Keep reading')))));
    await _frames(tester, 2);
    focus.requestFocus();
    await tester.pump();
    controller.merge();
    controller.split();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    expect(find.bySemanticsLabel('Keep reading'), findsOneWidget);
    await tester.tap(find.text('Keep reading'));
    expect(presses, 1);
    await _unmount(tester);
    semantics.dispose();
  });

  testWidgets(
      'capture reuses unchanged background, refreshes changes and stops while paused',
      (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    final reports = <NibWaterRenderStatus>[];
    await tester.runAsync(() => NibShaderLoader.load(
        'packages/nib_motion/lib/shaders/water_material.frag'));
    Future<void> captureFrames() async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
      }
      await tester.pump();
    }

    await tester.pumpWidget(_host(controller, onStatus: reports.add));
    await captureFrames();
    expect(reports, isNotEmpty);
    expect(reports.last.path, NibWaterRenderPath.refractive,
        reason:
            'This tests Flutter test-engine sampler binding, not a browser/GPU pass.');
    final initialCaptures = reports.last.captureCount;
    expect(initialCaptures, greaterThan(0));
    controller.disturb(const Offset(80, 80));
    await captureFrames();
    expect(reports.last.captureCount, initialCaptures,
        reason: 'Water repaints must not recapture their own background.');
    await tester.pumpWidget(_host(controller,
        onStatus: reports.add,
        background: const ColoredBox(color: Colors.red)));
    await captureFrames();
    expect(reports.last.captureCount, greaterThan(initialCaptures));
    final changedCaptures = reports.last.captureCount;
    await tester.pumpWidget(_host(controller,
        onStatus: reports.add,
        paused: true,
        background: const ColoredBox(color: Colors.green)));
    await captureFrames();
    expect(reports.last.captureCount, changedCaptures);
    await tester.pumpWidget(_host(controller,
        onStatus: reports.add,
        background: const ColoredBox(color: Colors.green),
        size: const Size(260, 180)));
    await captureFrames();
    expect(reports.last.captureCount, greaterThan(changedCaptures));
    final beforeContinuous = reports.last.captureCount;
    for (final color in [
      Colors.orange,
      Colors.purple,
      Colors.cyan,
      Colors.yellow
    ]) {
      await tester.pumpWidget(_host(controller,
          onStatus: reports.add,
          background: ColoredBox(color: color),
          size: const Size(260, 180)));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await captureFrames();
    expect(reports.last.captureCount, greaterThan(beforeContinuous),
        reason:
            'A changing background must make progress rather than starve capture.');
    final reportCount = reports.length;
    await _unmount(tester);
    expect(reports, hasLength(reportCount),
        reason: 'No late status after disposal.');
  });

  testWidgets(
      'active waves repaint without rebuilding background or foreground',
      (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    var backgroundBuilds = 0, foregroundBuilds = 0;
    await tester.pumpWidget(_host(controller, background: Builder(builder: (_) {
      backgroundBuilds++;
      return const ColoredBox(color: Colors.blue);
    }), child: Builder(builder: (_) {
      foregroundBuilds++;
      return const SizedBox();
    })));
    await _frames(tester, 2);
    final beforeBackground = backgroundBuilds,
        beforeForeground = foregroundBuilds;
    controller.disturb(const Offset(80, 80));
    await _frames(tester, 20);
    expect(controller.simulationTime, greaterThan(.2));
    expect(backgroundBuilds, beforeBackground);
    expect(foregroundBuilds, beforeForeground);
    await _unmount(tester);
  });

  testWidgets(
      'real captured shader refracts pixels and refreshes content inside its mask',
      (tester) async {
    await tester.runAsync(() => NibShaderLoader.load(
        'packages/nib_motion/lib/shaders/water_material.frag'));
    var controller = NibWaterController(
        drops: const [NibWaterDrop(id: 1, center: Offset(120, 90), radius: 65)],
        config: const NibWaterConfig(refraction: 0, highlight: 0));
    addTearDown(controller.dispose);
    final key = GlobalKey();
    final reports = <NibWaterRenderStatus>[];
    Widget scene(bool alternate) => MaterialApp(
            home: Center(
                child: RepaintBoundary(
          key: key,
          child: SizedBox(
              width: 240,
              height: 180,
              child: NibWaterSurface(
                  controller: controller,
                  onStatus: reports.add,
                  background: Row(children: [
                    for (var stripe = 0; stripe < 20; stripe++)
                      Expanded(
                          child: ColoredBox(
                              color: stripe.isEven
                                  ? (alternate ? Colors.red : Colors.blue)
                                  : Colors.white,
                              child: const SizedBox.expand())),
                  ]))),
        )));
    Future<void> finishCapture() async {
      for (var step = 0; step < 5; step++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
      }
      await tester.pump();
      expect(reports.last.path, NibWaterRenderPath.refractive);
    }

    final visualPath = Platform.environment['NIB_WATER_VISUAL_EVIDENCE'];
    final checkpoints = <Map<String, Object?>>[];
    Future<Uint8List> pixels({String? checkpoint}) async {
      final bytes = await tester.runAsync(() async {
        final image = await (key.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage();
        try {
          if (checkpoint != null && visualPath != null) {
            final directory = Directory(visualPath);
            await directory.create(recursive: true);
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            await File('${directory.path}/$checkpoint.png').writeAsBytes(
                png!.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes));
            checkpoints.add({
              'name': checkpoint,
              'width': image.width,
              'height': image.height,
              'phase': controller.phase.name,
              'simulationTime': controller.simulationTime,
              'impulseAges':
                  controller.impulses.map((item) => item.age).toList(),
              'drops': controller.drops
                  .map((drop) => {
                        'id': drop.id,
                        'bodyId': drop.bodyId,
                        'center': [drop.center.dx, drop.center.dy],
                        'radius': drop.radius,
                      })
                  .toList(),
              'captureCount': reports.last.captureCount,
            });
          }
          return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
              .buffer
              .asUint8List();
        } finally {
          image.dispose();
        }
      });
      return bytes!;
    }

    int changed(Uint8List a, Uint8List b, Rect rect) {
      var count = 0;
      for (var y = rect.top.toInt(); y < rect.bottom; y++) {
        for (var x = rect.left.toInt(); x < rect.right; x++) {
          final offset = (y * 240 + x) * 4;
          var difference = 0;
          for (var channel = 0; channel < 3; channel++) {
            difference += (a[offset + channel] - b[offset + channel]).abs();
          }
          if (difference > 24) count++;
        }
      }
      return count;
    }

    await tester.pumpWidget(scene(false));
    await finishCapture();
    final flat = await pixels();
    controller.configure(const NibWaterConfig(refraction: 16, highlight: 0));
    await tester.pump();
    final refracted = await pixels(checkpoint: 'wave-baseline');
    final inside =
        changed(flat, refracted, const Rect.fromLTWH(65, 35, 110, 110));
    final outside = changed(flat, refracted, const Rect.fromLTWH(0, 0, 30, 30));
    expect(inside, greaterThan(200),
        reason: 'Optical strength must move captured background pixels.');
    expect(outside, 0,
        reason: 'The water mask must leave outside content unchanged.');
    controller.disturb(const Offset(120, 90));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 60));
    expect(controller.impulses.single.age, closeTo(.12, .000001));
    final wave = await pixels(checkpoint: 'wave-120ms');
    final waveChanged =
        changed(refracted, wave, const Rect.fromLTWH(65, 35, 110, 110));
    expect(waveChanged, greaterThan(200),
        reason: 'A real evolving impulse must change optical pixels.');
    for (var step = 0; step < 100; step++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(controller.impulses, isEmpty);
    expect(controller.isActive, isFalse);
    final settled = await pixels(checkpoint: 'wave-settled');
    final settledChanged =
        changed(refracted, settled, const Rect.fromLTWH(65, 35, 110, 110));
    expect(settledChanged, lessThanOrEqualTo(2),
        reason: 'Settled waves must return to the baseline optics.');
    await tester.pumpWidget(scene(true));
    await finishCapture();
    final updated = await pixels();
    final updatedInside =
        changed(refracted, updated, const Rect.fromLTWH(85, 55, 70, 70));
    expect(updatedInside, greaterThan(500),
        reason: 'New background must replace old samples inside the water.');
    debugPrint(
        'Water test-engine optical pixels: refractedInside=$inside; unchangedOutside=$outside; wave120ms=$waveChanged; settledDelta=$settledChanged; updatedInside=$updatedInside. Not a browser/GPU result.');
    controller = NibWaterController(drops: const [
      NibWaterDrop(id: 1, center: Offset(70, 90), radius: 28),
      NibWaterDrop(id: 2, center: Offset(170, 90), radius: 28),
    ]);
    addTearDown(controller.dispose);
    await tester.pumpWidget(scene(false));
    await finishCapture();
    expect(controller.phase, NibWaterPhase.separated);
    expect(controller.fieldAt(const Offset(120, 90)), lessThan(.5));
    await pixels(checkpoint: 'separated');
    controller.merge();
    await tester.pump();
    await _frames(tester, 4);
    expect(controller.phase, NibWaterPhase.merging);
    expect(controller.fieldAt(const Offset(120, 90)), greaterThan(.5));
    expect((controller.drops[0].center - controller.drops[1].center).distance,
        greaterThan(56));
    await pixels(checkpoint: 'neck');
    await _frames(tester, 180);
    expect(controller.phase, NibWaterPhase.merged);
    await pixels(checkpoint: 'merged');
    controller.split();
    await _frames(tester, 200);
    expect(controller.phase, NibWaterPhase.separated);
    expect(controller.drops.map((drop) => drop.bodyId).toSet(), hasLength(2));
    await pixels(checkpoint: 'split');
    if (visualPath != null) {
      File('$visualPath/metadata.json')
          .writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
        'provenance':
            'Actual NibWaterSurface fragment shader and captured Flutter subtree in native flutter test; NOT a browser, physical GPU, or device result.',
        'command':
            'NIB_WATER_VISUAL_EVIDENCE=<output directory> flutter test --no-pub test/water/nib_water_surface_test.dart --plain-name "real captured shader refracts pixels and refreshes content inside its mask" --reporter expanded',
        'pixelThreshold': 'Summed RGB difference > 24',
        'waveAgeSeconds': .12,
        'refractedInteriorPixels': inside,
        'changedOutsidePixels': outside,
        'waveInteriorPixels': waveChanged,
        'settledInteriorPixels': settledChanged,
        'updatedBackgroundInteriorPixels': updatedInside,
        'checkpoints': checkpoints,
      }));
    }
    await _unmount(tester);
  });

  testWidgets(
      'disturb mode bounds simultaneous contacts and releases capacity on up',
      (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller));
    await _frames(tester, 2);
    final contacts = <TestGesture>[];
    for (var i = 0; i < 11; i++) {
      contacts.add(await tester.startGesture(
          _point(tester, const Offset(80, 80)),
          pointer: 100 + i));
    }
    expect(controller.impulses, hasLength(10));
    expect(controller.activeInputs, 0);
    await contacts.last.moveBy(const Offset(40, 0));
    expect(controller.impulses, hasLength(10),
        reason: 'Rejected contact must not add wake samples.');
    await contacts.first.up();
    final replacement = await tester
        .startGesture(_point(tester, const Offset(90, 90)), pointer: 200);
    expect(controller.impulses, hasLength(11));
    await replacement.cancel();
    for (final contact in contacts.skip(1)) {
      await contact.cancel();
    }
    await _unmount(tester);
  });

  testWidgets(
      'nested composited background scrolling refreshes real shader samples',
      (tester) async {
    await tester.runAsync(() => NibShaderLoader.load(
        'packages/nib_motion/lib/shaders/water_material.frag'));
    final controller = NibWaterController(
        drops: const [NibWaterDrop(id: 1, center: Offset(120, 90))],
        config: const NibWaterConfig(highlight: 0));
    final scroll = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(scroll.dispose);
    final key = GlobalKey();
    final reports = <NibWaterRenderStatus>[];
    await tester.pumpWidget(MaterialApp(
        home: Center(
            child: RepaintBoundary(
      key: key,
      child: SizedBox(
          width: 240,
          height: 180,
          child: NibWaterSurface(
            controller: controller,
            surface: true,
            onStatus: reports.add,
            background: SingleChildScrollView(
                controller: scroll,
                child: Column(children: [
                  for (final color in const [
                    Color(0xFF0000FF),
                    Color(0xFFFF0000),
                    Color(0xFF00FF00)
                  ])
                    RepaintBoundary(
                        child: SizedBox(
                            height: 180,
                            width: 240,
                            child: ColoredBox(color: color))),
                ])),
          )),
    ))));
    Future<void> capture() async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
      }
      await tester.pump();
      expect(reports.last.path, NibWaterRenderPath.refractive);
    }

    Future<List<int>> centerPixel() async => (await tester.runAsync(() async {
          final image = await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
          try {
            final data =
                await image.toByteData(format: ui.ImageByteFormat.rawRgba);
            final offset = (90 * 240 + 120) * 4;
            return data!.buffer.asUint8List().sublist(offset, offset + 4);
          } finally {
            image.dispose();
          }
        }))!;
    await capture();
    expect(await centerPixel(), [0, 0, 255, 255]);
    final before = reports.last.captureCount;
    scroll.jumpTo(180);
    await capture();
    expect(reports.last.captureCount, greaterThan(before));
    expect(await centerPixel(), [255, 0, 0, 255],
        reason:
            'The shader must show current nested-scroll content, not its old blue image.');
    final second = reports.last.captureCount;
    scroll.jumpTo(360);
    await capture();
    expect(reports.last.captureCount, greaterThan(second));
    expect(await centerPixel(), [0, 255, 0, 255]);
    debugPrint(
        'Water nested-scroll shader samples: blue -> red -> green, capture counts $before -> $second -> ${reports.last.captureCount}.');
    await _unmount(tester);
  });

  testWidgets(
      'background signal refreshes, swaps listeners, and remains caller-owned',
      (tester) async {
    await tester.runAsync(() => NibShaderLoader.load(
        'packages/nib_motion/lib/shaders/water_material.frag'));
    final controller = _controller();
    final first = _BackgroundSignal(), second = _BackgroundSignal();
    addTearDown(controller.dispose);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    final reports = <NibWaterRenderStatus>[];
    Future<void> capture() async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
      }
      await tester.pump();
    }

    await tester.pumpWidget(
        _host(controller, backgroundChanges: first, onStatus: reports.add));
    await capture();
    expect(first.listening, isTrue);
    expect(second.listening, isFalse);
    final initial = reports.last.captureCount;
    first.ping();
    await capture();
    expect(reports.last.captureCount, greaterThan(initial));
    await tester.pumpWidget(
        _host(controller, backgroundChanges: second, onStatus: reports.add));
    await capture();
    expect(first.listening, isFalse);
    expect(second.listening, isTrue);
    final afterSwap = reports.last.captureCount;
    first.ping();
    await capture();
    expect(reports.last.captureCount, afterSwap);
    second.ping();
    await capture();
    expect(reports.last.captureCount, greaterThan(afterSwap));
    await _unmount(tester);
    expect(second.listening, isFalse);
    expect(first.disposed, isFalse);
    expect(second.disposed, isFalse);
    first.ping();
    second.ping();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

class _BackgroundSignal extends ChangeNotifier {
  bool disposed = false;
  bool get listening => hasListeners;
  void ping() => notifyListeners();
  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

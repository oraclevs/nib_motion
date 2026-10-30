import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Future<void> frames(WidgetTester tester, [int count = 5]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 80));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
  }
}

void main() {
  setUp(() {
    NibShaderLoader.resetForTesting();
    NibShaderLoader.assetKeyResolver =
        (key) => key.replaceFirst('packages/nib_motion/', '');
  });
  tearDown(NibShaderLoader.resetForTesting);

  testWidgets('failed shader loads can recover on a later mount',
      (tester) async {
    await tester.runAsync(() async {
      const key = 'water-retry-probe';
      NibShaderLoader.assetKeyResolver = (_) => 'missing-water-probe.frag';
      await expectLater(NibShaderLoader.load(key), throwsA(anything));
      NibShaderLoader.assetKeyResolver =
          (_) => 'lib/shaders/water_material.frag';
      expect(await NibShaderLoader.load(key), isNotNull);
    });
  });

  testWidgets(
      'live underwater controls retain taps, focus, slider and semantics',
      (tester) async {
    final water = NibWaterController(
        drops: const [], config: const NibWaterConfig(refraction: 4));
    final text = TextEditingController();
    var taps = 0, value = .5;
    final semantics = tester.ensureSemantics();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      water.dispose();
      text.dispose();
    });
    await tester.pumpWidget(MaterialApp(
        home: Center(
            child: SizedBox(
                width: 320,
                height: 400,
                child: NibWaterSurface(
                    controller: water,
                    sampling: NibWaterSampling.live,
                    surface: true,
                    background: Material(
                        child: StatefulBuilder(
                            builder: (_, update) => Column(children: [
                                  Align(
                                      alignment: Alignment.centerLeft,
                                      child: ElevatedButton(
                                          onPressed: () => taps++,
                                          child:
                                              const Text('Underwater action'))),
                                  Slider(
                                      value: value,
                                      onChanged: (v) =>
                                          update(() => value = v)),
                                  TextField(controller: text),
                                  const Expanded(
                                      child: SingleChildScrollView(
                                          child: SizedBox(
                                              height: 800,
                                              child: Text('Scrollable text')))),
                                ]))))))));
    await frames(tester);
    water.disturb(const Offset(20, 25));
    await tester.tap(find.text('Underwater action'));
    expect(taps, 1);
    await tester.drag(find.byType(Slider), const Offset(60, 0));
    expect(value, greaterThan(.5));
    await tester.enterText(find.byType(TextField), 'clear water');
    expect(text.text, 'clear water');
    text.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
    await tester.pump();
    expect(text.selection.textInside(text.text), 'clear');
    expect(tester.getSemantics(find.text('Underwater action')).label,
        contains('Underwater action'));
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -100));
    await frames(tester);
    expect(tester.takeException(), isNull);
    expect(water.activeInputs, 0);
    semantics.dispose();
  });

  testWidgets('throttled sampling refreshes only when its interval is due',
      (tester) async {
    await tester.runAsync(() => NibShaderLoader.load(
        'packages/nib_motion/lib/shaders/water_material.frag'));
    final water = NibWaterController(drops: const []);
    final reports = <NibWaterRenderStatus>[];
    addTearDown(water.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Center(
            child: SizedBox(
                width: 100,
                height: 100,
                child: NibWaterSurface(
                    controller: water,
                    sampling: NibWaterSampling.throttled,
                    sampleInterval: const Duration(seconds: 1),
                    onStatus: reports.add,
                    background: const ColoredBox(color: Colors.blue))))));
    await frames(tester, 2);
    final before = reports.last.captureCount;
    water.disturb(const Offset(
        50, 50)); // Ensure a scene is composed; no timer polls idle content.
    await tester.pump(const Duration(milliseconds: 400));
    expect(reports.last.captureCount, before);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(reports.last.captureCount, before + 1);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'static invalidation, pause, resize and 30 mount cycles release cleanly',
      (tester) async {
    await tester.runAsync(() => NibShaderLoader.load(
        'packages/nib_motion/lib/shaders/water_material.frag'));
    final water = NibWaterController(drops: const []);
    final signal = ValueNotifier<int>(0);
    final reports = <NibWaterRenderStatus>[];
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      water.dispose();
      signal.dispose();
    });
    Widget host({bool paused = false, double width = 120}) => MaterialApp(
        home: Center(
            child: SizedBox(
                width: width,
                height: 100,
                child: NibWaterSurface(
                    controller: water,
                    sampling: NibWaterSampling.static,
                    paused: paused,
                    backgroundChanges: signal,
                    onStatus: reports.add,
                    background: const ColoredBox(color: Colors.blue)))));
    await tester.pumpWidget(host());
    await frames(tester);
    expect(reports.last.backend, 'layerSampler');
    final count = reports.last.captureCount;
    await frames(tester);
    expect(reports.last.captureCount, count);
    signal.value++;
    await frames(tester);
    expect(reports.last.captureCount, count + 1);
    await tester.pumpWidget(host(paused: true));
    signal.value++;
    await frames(tester);
    expect(reports.last.captureCount, count + 1);
    await tester.pumpWidget(host(width: 140));
    await frames(tester);
    expect(reports.last.resolution!.width, 420);
    for (var i = 0; i < 30; i++) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(host());
      await frames(tester, 2);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
  });
}

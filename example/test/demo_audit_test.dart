import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';
import 'package:nib_motion_example/demos.dart';
import 'package:nib_motion_example/main.dart';
import 'package:nib_motion_example/screens/multi_axis_screen.dart';
import 'package:nib_motion_example/screens/pages_screen.dart';
import 'package:nib_motion_example/screens/presence_layout_screen.dart';
import 'package:nib_motion_example/screens/reduced_motion_screen.dart';
import 'package:nib_motion_example/screens/simulation_screen.dart';

const _originalTitles = [
  'Interruption',
  'Drag, inertia, snap',
  'Presence',
  'Layout (FLIP)',
  'Reduced motion',
  'Effects & tokens',
  'Timeline',
  'Multi-axis values',
  'Viewport progress',
  'Routes',
  'Sliver header + list FLIP',
  'Timeline drag-scrub',
  'Spring tuner',
  'Velocity + Offset adapter',
  'NibPresence.layout',
  'Layout size modes',
  'NibValueBuilder',
  'Page, tab, viewport progress',
  'Directional transitions',
  'Hot reload replay',
  'Custom Simulation',
];

Future<void> _frames(WidgetTester tester, [int count = 8]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
  expect(tester.takeException(), isNull);
  expect(tester.binding.transientCallbackCount, 0,
      reason: 'No demo tickers remain after navigation away.');
}

void main() {
  test('the complete original registry keeps its titles and ordering', () {
    expect(demoEntries.take(21).map((entry) => entry.title), _originalTitles);
  });

  for (final size in const [Size(375, 812), Size(1440, 900)]) {
    for (final title in _originalTitles) {
      testWidgets('$title opens and disposes at $size, with reduced motion',
          (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final entry = demoEntries.singleWhere((entry) => entry.title == title);
        for (final reduced in [false, true]) {
          await tester.pumpWidget(MaterialApp(
            home: NibMotionConfig(
              reducedMotion: reduced,
              entranceWarmup: Duration.zero,
              child: entry.builder(),
            ),
          ));
          await _frames(tester);
          expect(tester.takeException(), isNull);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(tester.takeException(), isNull);
          await _leave(tester);
        }
      });
    }
  }

  // Known runtime failure is preserved as an executable reproduction in
  // doc/maintainers/repros/gradient_reduced_motion.dart.
  for (final title in _originalTitles) {
    testWidgets('$title survives rapid controls and leaving mid-animation',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final entry = demoEntries.singleWhere((entry) => entry.title == title);
      await tester.pumpWidget(MaterialApp(home: entry.builder()));
      await _frames(tester);
      for (var i = 0; i < 6; i++) {
        final controls = find
            .byWidgetPredicate((widget) =>
                widget is FilledButton ||
                widget is ActionChip ||
                widget is ChoiceChip ||
                widget is Switch)
            .hitTestable();
        if (controls.evaluate().isNotEmpty) {
          await tester.tap(controls.first);
          await tester.pump(const Duration(milliseconds: 25));
        }
      }
      final sliders = find.byType(Slider).hitTestable();
      if (sliders.evaluate().isNotEmpty) {
        await tester.drag(sliders.first, const Offset(70, 0));
        await tester.pump(const Duration(milliseconds: 25));
      }
      final scroll = find.byType(Scrollable).hitTestable();
      if (scroll.evaluate().isNotEmpty) {
        await tester.drag(scroll.first, const Offset(0, -160));
        await tester.pump(const Duration(milliseconds: 25));
      }
      expect(tester.takeException(), isNull);
      await _leave(tester);
    }, skip: title == 'Reduced motion');
  }

  testWidgets('multi-axis colors fit a phone and expose accessible labels',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(home: MultiAxisScreen()));
    await _frames(tester);
    for (final color in ['Indigo', 'Orange', 'Teal', 'Pink']) {
      final button = find.bySemanticsLabel(color);
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(tester.takeException(), isNull);
    await _leave(tester);
    semantics.dispose();
  });

  testWidgets('presence row remains scrollable after repeated additions',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: PresenceLayoutScreen()));
    await tester.tap(find.widgetWithText(ChoiceChip, 'row'));
    await _frames(tester);
    for (var i = 0; i < 8; i++) {
      await tester.tap(find.widgetWithText(ActionChip, 'Add'));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await _frames(tester);
    expect(tester.takeException(), isNull);
    final horizontal = find.byWidgetPredicate((widget) =>
        widget is SingleChildScrollView &&
        widget.scrollDirection == Axis.horizontal);
    expect(horizontal, findsOneWidget);
    await tester.drag(horizontal, const Offset(-400, 0));
    await _frames(tester);
    expect(tester.takeException(), isNull);
    await _leave(tester);
  });

  testWidgets('rapid simulation restarts keep one bounce chain',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: SimulationScreen()));
    for (var i = 0; i < 8; i++) {
      await tester.tap(find.text('Drop'));
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(find.text('bounces: 0'), findsOneWidget,
        reason: 'Superseded runs must not count a new impact.');
    for (var i = 0; i < 500; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('bounces: 0'), findsNothing);
    expect(tester.binding.transientCallbackCount, 0,
        reason: 'The last drop eventually rests.');
    expect(tester.takeException(), isNull);
    await _leave(tester);
  });

  testWidgets('page indicator survives repeated width and tab changes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: PagesScreen()));
    for (var i = 0; i < 8; i++) {
      await tester.binding.setSurfaceSize(Size(i.isEven ? 375 : 1440, 900));
      await tester.pump();
      await tester.tap(find.text('Tab ${i % 4}'));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await _frames(tester);
    expect(tester.takeException(), isNull);
    await _leave(tester);
  });

  testWidgets('imperative physics pads respect reduced motion on interaction',
      (tester) async {
    for (final title in [
      'Interruption',
      'Multi-axis values',
      'Velocity + Offset adapter',
    ]) {
      final entry = demoEntries.singleWhere((entry) => entry.title == title);
      await tester.pumpWidget(MaterialApp(
        home: NibMotionConfig(reducedMotion: true, child: entry.builder()),
      ));
      await _frames(tester);
      final pad = title == 'Velocity + Offset adapter'
          ? find.ancestor(
              of: find.text('tap to move (Offset)'),
              matching: find.byWidgetPredicate((widget) =>
                  widget is GestureDetector && widget.onTapDown != null))
          : find.byWidgetPredicate((widget) =>
              widget is GestureDetector && widget.onTapDown != null);
      await tester.tapAt(tester.getTopLeft(pad.first) + const Offset(200, 40));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0,
          reason: '$title must apply the target without starting a solver.');
      expect(tester.takeException(), isNull);
      await _leave(tester);
    }
  });

  testWidgets('reduced-motion control snaps its declarative example',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ReducedMotionScreen()));
    await _frames(tester);
    await tester.tap(find.text('Toggle state'));
    await tester.pump();
    final motion = find.byWidgetPredicate((widget) =>
        widget is NibMotion &&
        widget.animate is NibAnim &&
        (widget.animate! as NibAnim).x == 200);
    expect(motion, findsOneWidget);
    final render = tester.renderObject<RenderNibMotion>(motion);
    expect(render.translateX.value, 200);
    await _leave(tester);
  });

  for (final size in const [Size(343, 700), Size(375, 812), Size(1440, 900)]) {
    testWidgets('Daily Focus opens and disposes at $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const DailyFocusApp());
      await _frames(tester, 20);
      expect(find.text('Morning run — 5km'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _leave(tester);
    });
  }
}

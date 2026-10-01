// Pumps every demo screen and pokes its controls; fails on any exception.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion_example/demos.dart';
import 'package:nib_motion_example/screens/interruption_screen.dart';
import 'package:nib_motion_example/screens/pages_screen.dart';
import 'package:nib_motion_example/screens/routes_screen.dart';
import 'package:nib_motion_example/screens/simulation_screen.dart';
import 'package:nib_motion_example/screens/sliver_screen.dart';
import 'package:nib_motion_example/screens/velocity_screen.dart';

Future<void> _frames(WidgetTester tester, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

void main() {
  for (final size in const [Size(420, 900), Size(1200, 800)]) {
    for (final entry in demoEntries) {
      testWidgets(
          '${entry.title} builds, animates and takes input '
          '(${size.width.toInt()}x${size.height.toInt()})', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(home: entry.builder()));
        await _frames(tester);

        for (final type in <Type>[
          FilledButton,
          ActionChip,
          FilterChip,
          ChoiceChip,
          Switch
        ]) {
          final finder = find.byType(type);
          for (var i = 0; i < finder.evaluate().length && i < 4; i++) {
            await tester.tap(finder.at(i), warnIfMissed: false);
            await _frames(tester, 4);
          }
        }

        // Generic gesture poke in the middle of the body.
        final body = tester.getCenter(find.byType(Scaffold).first);
        await tester.tapAt(body);
        await _frames(tester, 3);
        await tester.dragFrom(body, const Offset(-120, -160));
        await _frames(tester, 10);

        expect(tester.takeException(), isNull);
        // Leave the tree so tickers/timers are disposed before the test ends.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('menu lists every demo and opens one', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const DemosApp());
    for (final e in demoEntries) {
      expect(find.text(e.title), findsOneWidget);
    }
    await tester.tap(find.text('Interruption'));
    await tester.pumpAndSettle();
    expect(find.text('Interruption'), findsWidgets);
  });

  testWidgets('interruption demo: retargeting mid-flight reports live velocity',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: InterruptionScreen()));
    final track = find.byType(GestureDetector).first;
    final topLeft = tester.getTopLeft(track);
    await tester.tapAt(topLeft + const Offset(300, 40));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.textContaining('velocity = 0 px/s'), findsNothing,
        reason: 'mid-flight the readout shows non-zero velocity');
    await tester.pump(const Duration(seconds: 6));
    expect(find.textContaining('velocity = 0 px/s'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('routes: dialog returns its result and closes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: RoutesScreen()));
    await tester.tap(find.text('showNibDialog'));
    await _frames(tester, 8);
    expect(find.text('Delete item?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await _frames(tester, 20);
    expect(find.text('Delete item?'), findsNothing);
    expect(find.text('Last result: dialog returned true'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('routes: back-swipe page pops when dragged past the threshold',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: RoutesScreen()));
    await tester.tap(find.text('Page + backSwipe'));
    await _frames(tester, 12);
    expect(find.text('Detail page'), findsOneWidget);
    await tester.dragFrom(const Offset(4, 400), const Offset(300, 0));
    await _frames(tester, 30);
    expect(find.text('Detail page'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sliver: inserting a row adds it and the list keeps working',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: SliverScreen()));
    await _frames(tester);
    expect(find.text('Item 8'), findsNothing);
    await tester.tap(find.text('Insert at top'));
    await _frames(tester, 12);
    expect(find.text('Item 8'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await _frames(tester, 6);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('velocity: the readout is non-zero after a fling',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: VelocityScreen()));
    await _frames(tester);
    final g = await tester.startGesture(tester.getCenter(find.text('fling')));
    for (var i = 1; i <= 4; i++) {
      await g.moveBy(const Offset(25, 0),
          timeStamp: Duration(milliseconds: 8 * i));
    }
    await g.up(timeStamp: const Duration(milliseconds: 40));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.textContaining('vx = 0 px/s'), findsNothing);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('simulation: drop bounces and eventually rests', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: SimulationScreen()));
    await tester.tap(find.text('Drop'));
    for (var i = 0; i < 400; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.textContaining('bounces:'), findsOneWidget);
    expect(find.text('bounces: 0'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pages: swiping the PageView moves to the next page',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: PagesScreen()));
    await _frames(tester);
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await _frames(tester, 12);
    await tester.tap(find.text('Tab 2'));
    await _frames(tester, 12);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

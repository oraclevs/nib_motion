import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';
import 'package:nib_motion_example/demos.dart';
import 'package:nib_motion_example/gallery/app.dart';
import 'package:nib_motion_example/gallery/fullscreen.dart';
import 'package:nib_motion_example/gallery/review.dart';
import 'package:nib_motion_example/main.dart' show DailyFocusApp;
import 'package:nib_motion_example/screens/interruption_screen.dart';
import 'package:nib_motion_example/screens/routes_screen.dart';

Future<void> frames(WidgetTester tester, [int count = 8]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

void main() {
  test('all original titles and stable URLs remain available', () {
    expect(demoEntries.map((e) => e.title), [
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
    ]);
    expect(galleryEntries.map((e) => e.slug).toSet().length,
        galleryEntries.length);
    expect(galleryEntries.length, greaterThanOrEqualTo(24));
    for (final entry in galleryEntries) {
      expect(entry.slug, matches(RegExp(r'^[a-z0-9-]+$')));
      expect(entry.source, startsWith('example/lib/'));
      expect(entry.instructions, isNotEmpty);
    }
  });

  testWidgets('fullscreen is safely unavailable on a native test host',
      (tester) async {
    expect(supportsPresentationFullscreen, isFalse);
    expect(await enterPresentationFullscreen(), isFalse);
    await tester.pumpWidget(const DemosApp(initialPath: '/'));
    await frames(tester);
    expect(find.byTooltip('Enter presentation fullscreen (Esc to leave)'),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('route parser round-trips shared links and unknown routes', () async {
    const parser = GalleryRouteParser();
    for (final path in ['/', '/demo/interruption', '/demo/not-here']) {
      final route = await parser
          .parseRouteInformation(RouteInformation(uri: Uri.parse(path)));
      expect(route, path);
      expect(parser.restoreRouteInformation(route).uri.path, path);
    }
  });

  test('review exports round-trip all states and unicode notes', () {
    final input = {
      'interruption': const DemoReview(
          status: ReviewStatus.approved, notes: 'Works — try rapid input.'),
      'drag': const DemoReview(
          status: ReviewStatus.needsImprovement, notes: 'Keyboard control'),
    };
    final output = exportReviews(input, ['interruption', 'drag', 'presence']);
    final restored =
        importReviews(output, {'interruption', 'drag', 'presence'});
    expect(restored['interruption']!.status, ReviewStatus.approved);
    expect(restored['interruption']!.notes, input['interruption']!.notes);
    expect(restored['drag']!.status, ReviewStatus.needsImprovement);
    expect(restored['presence']!.status, ReviewStatus.notReviewed);
  });

  test('malformed review imports fail before applying changes', () {
    for (final input in [
      'bad json',
      '[]',
      '{}',
      '{"schemaVersion":2,"reviews":{}}',
      jsonEncode({
        'schemaVersion': 1,
        'reviews': {
          'unknown': {'status': 'approved', 'notes': ''}
        }
      }),
      jsonEncode({
        'schemaVersion': 1,
        'reviews': {
          'drag': {'status': 'bogus', 'notes': ''}
        }
      }),
      jsonEncode({
        'schemaVersion': 1,
        'reviews': {
          'drag': {'status': 'approved', 'notes': 42}
        }
      }),
      jsonEncode({
        'schemaVersion': 1,
        'reviews': {
          'drag': {'status': 'approved', 'notes': 'x' * 10001}
        }
      }),
      'x' * 1000001,
    ]) {
      expect(() => importReviews(input, {'drag'}), throwsFormatException);
    }
  });

  testWidgets('desktop search, filter, navigation and reset', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const DemosApp(initialPath: '/'));
    await frames(tester);
    await tester.enterText(
        find.byKey(const ValueKey('gallery-search')), 'Interruption');
    await tester.pump();
    expect(find.byKey(const ValueKey('nav-interruption')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-drag')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('nav-interruption')));
    await frames(tester);
    expect(find.byType(InterruptionScreen), findsOneWidget);
    final oldState = tester.state(find.byType(InterruptionScreen));
    await tester.tap(find.byKey(const ValueKey('replay-demo')));
    await frames(tester);
    expect(
        tester.state(find.byType(InterruptionScreen)), isNot(same(oldState)));
    await tester.tap(find.byKey(const ValueKey('back-to-gallery')));
    await frames(tester);
    expect(find.byType(InterruptionScreen), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('gallery-search')), '');
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accessibility').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('nav-reduced-motion')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-interruption')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(375, 812),
    const Size(768, 1024),
    const Size(1440, 1000)
  ]) {
    testWidgets(
        'overview adapts to ${size.width.toInt()}px and supports keyboard controls',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(const DemosApp(initialPath: '/'));
      await frames(tester);
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Use light theme'), findsOneWidget);
      await tester.tap(find.byTooltip('Use light theme'));
      await frames(tester);
      expect(find.byTooltip('Use dark theme'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      expect(FocusManager.instance.primaryFocus, isNotNull);
      if (size.width < 1000) {
        await tester.tap(find.byTooltip('Open example navigation'));
        await tester.pumpAndSettle();
      }
      await tester.enterText(
          find.byKey(const ValueKey('gallery-search')), 'spring tuner');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('nav-spring-tuner')));
      await frames(tester);
      expect(find.byKey(const ValueKey('detail-spring-tuner')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await frames(tester);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  testWidgets('deep link, unknown route and browser back restoration',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const DemosApp(initialPath: '/demo/interruption'));
    await frames(tester);
    expect(find.byType(InterruptionScreen), findsOneWidget);
    final router = Router.of(tester.element(find.byType(InterruptionScreen)))
        .routerDelegate as GalleryRouter;
    await router.setNewRoutePath('/demo/not-here');
    await frames(tester);
    expect(find.text('Example not found'), findsOneWidget);
    await router.setNewRoutePath('/demo/interruption');
    await frames(tester);
    expect(find.byType(InterruptionScreen), findsOneWidget);
    expect(await router.popRoute(), isTrue);
    await frames(tester);
    expect(find.byType(InterruptionScreen), findsNothing);
    expect(await router.popRoute(), isFalse);
  });

  testWidgets(
      'Daily Focus stays inside the gallery route without another MaterialApp',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const DemosApp(initialPath: '/demo/daily-focus'));
    await frames(tester);
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.widget<DailyFocusApp>(find.byType(DailyFocusApp)).embedded,
        isTrue);
    final router = Router.of(tester.element(find.byType(DailyFocusApp)))
        .routerDelegate as GalleryRouter;
    expect(router.currentConfiguration, '/demo/daily-focus');
    await router.setNewRoutePath('/demo/readme-entrance');
    await frames(tester);
    expect(find.byType(DailyFocusApp), findsNothing);
    await router.setNewRoutePath('/demo/daily-focus');
    await frames(tester);
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(router.currentConfiguration, '/demo/daily-focus');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'back closes an example dialog or child route before leaving the example',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const DemosApp(initialPath: '/demo/routes'));
    await frames(tester);
    final router = Router.of(tester.element(find.byType(RoutesScreen)))
        .routerDelegate as GalleryRouter;
    await tester.tap(find.text('showNibDialog'));
    await frames(tester);
    expect(find.text('Delete item?'), findsOneWidget);
    expect(await router.popRoute(), isTrue);
    await frames(tester, 20);
    expect(find.text('Delete item?'), findsNothing);
    expect(router.currentConfiguration, '/demo/routes');
    await tester.tap(find.text('Page + backSwipe'));
    await frames(tester);
    expect(find.text('Detail page'), findsOneWidget);
    expect(await router.popRoute(), isTrue);
    await frames(tester, 20);
    expect(find.text('Detail page'), findsNothing);
    expect(router.currentConfiguration, '/demo/routes');
  });

  testWidgets('reduced-motion preference reaches active motion widgets',
      (tester) async {
    await tester
        .pumpWidget(const DemosApp(initialPath: '/demo/readme-entrance'));
    await frames(tester);
    await tester.tap(find.byTooltip('Motion preference'));
    await tester.pumpAndSettle();
    await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<String>, 'Reduce motion'));
    await frames(tester);
    final motionContext = tester.element(find.byType(NibMotion).first);
    expect(NibMotionConfig.shouldReduceMotion(motionContext), isTrue);
    expect(MediaQuery.of(motionContext).disableAnimations, isTrue);
  });

  testWidgets(
      'owner review can be exported and a validated import updates notes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const DemosApp(initialPath: '/demo/interruption'));
    await frames(tester);
    await tester.tap(find.byTooltip('Show owner review'));
    await tester.pump();
    final scrollable = tester.state<ScrollableState>(find
        .descendant(
            of: find.byKey(const ValueKey('detail-interruption')),
            matching: find.byType(Scrollable))
        .first);
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();
    await tester.tap(find.text('Approved'));
    await tester.pump();
    final notes = find.widgetWithText(TextFormField, 'Review notes');
    await tester.ensureVisible(notes);
    await tester.enterText(notes, 'Ready after owner review.');
    await tester.tap(find.text('Needs improvement'));
    await tester.pump();
    await tester.ensureVisible(find.text('Export JSON'));
    await tester.tap(find.text('Export JSON'));
    await tester.pumpAndSettle();
    final output =
        tester.widget<SelectableText>(find.byType(SelectableText)).data!;
    final decoded =
        importReviews(output, galleryEntries.map((e) => e.slug).toSet());
    expect(decoded['interruption']!.status, ReviewStatus.needsImprovement);
    expect(decoded['interruption']!.notes, 'Ready after owner review.');
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import JSON'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Paste exported JSON'), '{}');
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await tester.pump();
    expect(find.textContaining('Expected a NibMotion review export'),
        findsOneWidget);
    final imported = exportReviews({
      'interruption': const DemoReview(
          status: ReviewStatus.needsImprovement, notes: 'Try keyboard access.')
    }, [
      'interruption'
    ]);
    await tester.enterText(
        find.widgetWithText(TextField, 'Paste exported JSON'), imported);
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await tester.pumpAndSettle();
    expect(find.text('Try keyboard access.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'repeated route changes dispose old animations and leave overview idle',
      (tester) async {
    await tester.pumpWidget(const DemosApp(initialPath: '/demo/interruption'));
    await frames(tester);
    final router = Router.of(tester.element(find.byType(InterruptionScreen)))
        .routerDelegate as GalleryRouter;
    for (var i = 0; i < 3; i++) {
      for (final slug in [
        'text',
        'variants',
        'timeline',
        'navigation',
        'interruption'
      ]) {
        router.go(slug);
        await frames(tester, 2);
        expect(tester.takeException(), isNull);
      }
    }
    router.go(null);
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(375, 812), const Size(1200, 900)]) {
    for (final entry in galleryEntries) {
      testWidgets(
          'gallery deep link opens ${entry.slug} at ${size.width.toInt()}px and disposes it',
          (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(DemosApp(initialPath: '/demo/${entry.slug}'));
        await frames(tester);
        expect(find.byKey(ValueKey('detail-${entry.slug}')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('back-to-gallery')));
        await frames(tester);
        expect(find.byKey(ValueKey('detail-${entry.slug}')), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
      });
    }
  }
}

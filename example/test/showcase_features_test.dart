import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';
import 'package:nib_motion_example/screens/showcase_effects.dart';
import 'package:nib_motion_example/screens/showcase_navigation.dart';
import 'package:nib_motion_example/screens/showcase_paths.dart';
import 'package:nib_motion_example/screens/showcase_text.dart';
import 'package:nib_motion_example/screens/showcase_variants.dart';

void main() {
  setUp(() {
    NibShaderLoader.resetForTesting();
    // Exercise the advertised fallback path without depending on a test GPU.
    NibShaderLoader.assetKeyResolver = (_) => 'missing/showcase_shader.frag';
  });
  tearDown(NibShaderLoader.resetForTesting);

  for (final width in [375.0, 1100.0]) {
    Future<void> pumpScreen(WidgetTester tester, Widget screen,
        {bool reduced = false}) async {
      await tester.binding.setSurfaceSize(Size(width, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
            colorSchemeSeed: const Color(0xFFB84D28),
            brightness: width == 375 ? Brightness.light : Brightness.dark),
        home: NibMotionConfig(
          reducedMotion: reduced,
          entranceWarmup: Duration.zero,
          child: screen,
        ),
      ));
      await tester.pump();
    }

    Future<void> tap(WidgetTester tester, String label) async {
      final target = find.text(label);
      await tester.ensureVisible(target);
      await tester.pump();
      await tester.tap(target);
      await tester.pump();
    }

    Future<void> unmount(WidgetTester tester) async {
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 4));
      expect(tester.takeException(), isNull);
    }

    testWidgets('text modes replay and complete at $width', (tester) async {
      await pumpScreen(tester, const ShowcaseTextScreen());
      await tap(tester, 'Typewriter');
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Small details. Strong impressions.'), findsOneWidget);
      await tap(tester, 'Replay text');
      expect(find.text('Small details. Strong impressions.'), findsNothing);
      await tap(tester, 'Wipe');
      expect(find.byType(NibTextReveal), findsOneWidget);
      await tap(tester, 'Characters');
      expect(tester.widget<NibText>(find.byType(NibText)).config.unit,
          NibTextUnit.character);
      await unmount(tester);
    });

    testWidgets('effect choices and fallback controls work at $width',
        (tester) async {
      await pumpScreen(tester, const ShowcaseEffectsScreen());
      await tap(tester, 'Replay dissolve');
      await tap(tester, 'Shimmer');
      expect(
          tester.widget<NibShimmer>(find.byType(NibShimmer)).enabled, isTrue);
      await tap(tester, 'Animate shimmer');
      expect(
          tester.widget<NibShimmer>(find.byType(NibShimmer)).enabled, isFalse);
      await tap(tester, 'Glass');
      expect(find.byType(NibGlass), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('path pauses and replays at $width', (tester) async {
      await pumpScreen(tester, const ShowcasePathsScreen());
      await tester.pump(const Duration(milliseconds: 600));
      final render =
          tester.renderObject<RenderNibPathMotion>(find.byType(NibPathMotion));
      expect(render.progress.value, greaterThan(0));
      await tap(tester, 'Pause path');
      final paused = render.progress.value;
      await tester.pump(const Duration(milliseconds: 500));
      expect(render.progress.value, paused);
      expect(find.text('Path paused'), findsOneWidget);
      await tap(tester, 'Replay path');
      expect(render.progress.value, lessThan(paused));
      await tester.pump(const Duration(seconds: 1));
      expect(render.progress.value, greaterThan(paused));
      await unmount(tester);
    });

    testWidgets('variants and preset controls work at $width', (tester) async {
      await pumpScreen(tester, const ShowcaseVariantsScreen());
      await tap(tester, 'Rest the group');
      expect(find.text('Lift the group'), findsOneWidget);
      await tap(tester, 'Replay stagger');
      expect(find.text('Rest the group'), findsOneWidget);
      await tap(tester, 'Play presets');
      await tester.pump(const Duration(milliseconds: 500));
      final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(toggle.value, isTrue);
      await unmount(tester);
    });

    testWidgets('navigation switches real screen content at $width',
        (tester) async {
      await pumpScreen(tester, const ShowcaseNavigationScreen());
      expect(find.text('Room to think.'), findsOneWidget);
      await tap(tester, 'Next destination');
      await tester.pumpAndSettle();
      expect(find.text('Keep what matters.'), findsOneWidget);
      expect(find.text('Room to think.'), findsNothing);
      await tap(tester, 'Slide');
      await tap(tester, 'Next destination');
      await tester.pumpAndSettle();
      expect(find.text('A little, every day.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('reduced motion leaves all feature screens usable at $width',
        (tester) async {
      await pumpScreen(tester, const ShowcaseTextScreen(), reduced: true);
      await tap(tester, 'Typewriter');
      expect(find.text('Small details. Strong impressions.'), findsOneWidget);
      await pumpScreen(tester, const ShowcasePathsScreen(), reduced: true);
      expect(
          tester
              .renderObject<RenderNibPathMotion>(find.byType(NibPathMotion))
              .progress
              .value,
          1);
      await tap(tester, 'Replay path');
      expect(
          tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
          isNull);
      await pumpScreen(tester, const ShowcaseVariantsScreen(), reduced: true);
      await tap(tester, 'Play presets');
      await pumpScreen(tester, const ShowcaseEffectsScreen(), reduced: true);
      await tap(tester, 'Shimmer');
      await pumpScreen(tester, const ShowcaseNavigationScreen(), reduced: true);
      await tap(tester, 'Next destination');
      await tester.pumpAndSettle();
      expect(find.text('Keep what matters.'), findsOneWidget);
      await unmount(tester);
    });
  }
}

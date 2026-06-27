import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/src/debug/nib_perf_overlay.dart';

void main() {
  group('NibPerfOverlay', () {
    testWidgets('builds without throwing and shows a placeholder initially', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: NibPerfOverlay())),
      );

      expect(find.byType(NibPerfOverlay), findsOneWidget);
      // Before any FrameTiming callback has fired, the widget shows a
      // placeholder rather than a bogus number.
      expect(find.textContaining('FPS:'), findsOneWidget);
    });

    testWidgets('updates its displayed text after pumping frames', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: NibPerfOverlay())),
      );

      // Pump a number of frames to give the engine the opportunity to
      // deliver FrameTiming batches via addTimingsCallback. We don't assert
      // a specific FPS value (timing data in the test harness is not
      // representative of real device performance) — only that the widget
      // continues to build correctly and still shows the FPS label after
      // multiple frames have elapsed.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(find.byType(NibPerfOverlay), findsOneWidget);
      expect(find.textContaining('FPS:'), findsOneWidget);
    });

    testWidgets('disposes cleanly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: NibPerfOverlay())),
      );

      await tester.pumpWidget(const MaterialApp(home: Scaffold()));

      expect(find.byType(NibPerfOverlay), findsNothing);
    });
  });
}

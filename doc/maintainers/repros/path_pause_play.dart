// Expected to fail on the current runtime: play restarts the elapsed clock.
// Run from example/:
// flutter test ../doc/maintainers/repros/path_pause_play.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  testWidgets('path motion play resumes from its paused position',
      (tester) async {
    final controller = NibPathMotionController();
    await tester.pumpWidget(MaterialApp(
      home: NibMotionConfig(
        reducedMotion: false,
        child: NibPathMotion(
          controller: controller,
          path: Path()
            ..moveTo(0, 0)
            ..lineTo(100, 0),
          duration: const Duration(seconds: 1),
          curve: Curves.linear,
          child: const SizedBox(width: 10, height: 10),
        ),
      ),
    ));
    await tester.pump();
    final render =
        tester.renderObject<RenderNibPathMotion>(find.byType(NibPathMotion));
    await tester.pump(const Duration(milliseconds: 600));
    final before = render.progress.value;
    controller.pause();
    await tester.pump(const Duration(milliseconds: 200));
    expect(render.progress.value, before);
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final after = render.progress.value;
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    expect(before, closeTo(0.6, 0.01));
    expect(after, closeTo(0.7, 0.01),
        reason: 'A resume should retain the 600 ms already played.');
  });

  testWidgets('draw path play resumes from its paused stroke', (tester) async {
    final controller = NibDrawPathController();
    await tester.pumpWidget(MaterialApp(
      home: NibMotionConfig(
        reducedMotion: false,
        child: NibDrawPath(
          controller: controller,
          path: Path()
            ..moveTo(0, 0)
            ..lineTo(100, 0),
          duration: const Duration(seconds: 1),
          curve: Curves.linear,
        ),
      ),
    ));
    await tester.pump();
    final render =
        tester.renderObject<RenderNibDrawPath>(find.byType(NibDrawPath));
    await tester.pump(const Duration(milliseconds: 600));
    final before = render.progress.value;
    controller.pause();
    await tester.pump(const Duration(milliseconds: 200));
    expect(render.progress.value, before);
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final after = render.progress.value;
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    expect(before, closeTo(0.6, 0.01));
    expect(after, closeTo(0.7, 0.01),
        reason: 'A resume should retain the 600 ms already drawn.');
  });
}

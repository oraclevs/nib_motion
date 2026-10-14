import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

class _Rig {
  _Rig(this.timeline, this.controller);
  final NibTimeline timeline;
  final NibMotionController controller;
}

_Rig _rig() {
  final controller = NibMotionController();
  final timeline = NibTimeline([
    NibTimelineEntry(
      controller: controller,
      target: const NibAnim(x: 100),
      from: const NibAnim(x: 0),
      at: Duration.zero,
      transition: const NibTransition(
          duration: Duration(milliseconds: 1000), curve: Curves.linear),
    ),
  ]);
  return _Rig(timeline, controller);
}

Widget _host(
  _Rig rig,
  NibScrubRelease release, {
  TextDirection direction = TextDirection.ltr,
  bool reduced = false,
}) =>
    Directionality(
      textDirection: direction,
      child: NibMotionConfig(
        reducedMotion: reduced,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            height: 100,
            child: NibTimelineDragScrubber(
              timeline: rig.timeline,
              release: release,
              child: NibMotion(
                controller: rig.controller,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );

/// Drags [dx] px over [ms] ms in 16 ms steps, with a final fast flick if
/// [flickPxPerSecond] is given, then releases.
Future<void> _scrub(
  WidgetTester tester,
  double dx, {
  double flickPxPerSecond = 0,
  Offset start = const Offset(20, 50),
}) async {
  final g = await tester.startGesture(start);
  const steps = 8;
  for (var i = 1; i <= steps; i++) {
    await g.moveBy(Offset(dx / steps, 0),
        timeStamp:
            Duration(milliseconds: i * (flickPxPerSecond > 0 ? 8 : 100)));
  }
  await g.up();
}

void main() {
  tearDown(() => NibMotionConfig.setReducedMotion(null));

  testWidgets('stay: progress stays where the finger left it', (tester) async {
    final rig = _rig();
    await tester.pumpWidget(_host(rig, NibScrubRelease.stay));
    await _scrub(tester, 60); // 60 / 200 = 0.3
    await tester.pump(); // starts the release ticker
    await tester.pump(const Duration(seconds: 2));
    expect(rig.timeline.progress.value, closeTo(0.3, 0.02));
  });

  testWidgets('snapToNearest: lands on the nearer end with a spring',
      (tester) async {
    final low = _rig();
    await tester.pumpWidget(_host(low, NibScrubRelease.snapToNearest));
    await _scrub(tester, 60); // 0.3 -> 0
    await tester.pump(); // starts the release ticker
    await tester.pump(const Duration(milliseconds: 50));
    expect(low.timeline.progress.value, inExclusiveRange(0.0, 0.3),
        reason: 'animating, not jumping');
    await tester.pump(const Duration(seconds: 3));
    expect(low.timeline.progress.value, 0);
    await tester.pumpWidget(const SizedBox());

    final high = _rig();
    await tester.pumpWidget(_host(high, NibScrubRelease.snapToNearest));
    await _scrub(tester, 140); // 0.7 -> 1
    await tester.pump(); // starts the release ticker
    await tester.pump(const Duration(seconds: 3));
    expect(high.timeline.progress.value, 1);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('snapToNearest: a flick toward the far end wins over position',
      (tester) async {
    final rig = _rig();
    await tester.pumpWidget(_host(rig, NibScrubRelease.snapToNearest));
    await _scrub(tester, 70, flickPxPerSecond: 4000); // at 0.35 but flung right
    await tester.pump(); // starts the release ticker
    await tester.pump(const Duration(seconds: 3));
    expect(rig.timeline.progress.value, 1);
  });

  testWidgets('momentum: keeps going after release and stays within 0..1',
      (tester) async {
    final rig = _rig();
    await tester.pumpWidget(_host(rig, NibScrubRelease.momentum));
    await _scrub(tester, 40, flickPxPerSecond: 3000);
    await tester.pump(); // starts the release ticker
    final atRelease = rig.timeline.progress.value;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(rig.timeline.progress.value, greaterThan(atRelease + 0.02),
        reason: 'coasting forward');
    await tester.pump(const Duration(seconds: 10));
    final rest = rig.timeline.progress.value;
    expect(rest, inInclusiveRange(0.0, 1.0));
    await tester.pump(const Duration(seconds: 1));
    expect(rig.timeline.progress.value, rest, reason: 'came to rest');
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('momentum: a slow release barely moves', (tester) async {
    final rig = _rig();
    await tester.pumpWidget(_host(rig, NibScrubRelease.momentum));
    await _scrub(tester, 40);
    await tester.pump(); // starts the release ticker
    final atRelease = rig.timeline.progress.value;
    await tester.pump(const Duration(seconds: 5));
    expect(rig.timeline.progress.value, closeTo(atRelease, 0.05));
  });

  testWidgets('springBack: returns to where the scrub began', (tester) async {
    final rig = _rig();
    await tester.pumpWidget(_host(rig, NibScrubRelease.springBack));
    rig.timeline.seek(0.25);
    await _scrub(tester, 80); // to ~0.65
    await tester.pump(); // starts the release ticker
    expect(rig.timeline.progress.value, closeTo(0.65, 0.03));
    await tester.pump(const Duration(seconds: 3));
    expect(rig.timeline.progress.value, closeTo(0.25, 1e-6));
  });

  testWidgets('a new drag cancels the release animation', (tester) async {
    final rig = _rig();
    await tester.pumpWidget(_host(rig, NibScrubRelease.snapToNearest));
    await _scrub(tester, 140); // 0.7, springing to 1
    await tester.pump(); // starts the release ticker
    await tester.pump(const Duration(milliseconds: 40));
    final g = await tester.startGesture(const Offset(20, 50));
    await g.moveBy(const Offset(-80, 0));
    await g.moveBy(const Offset(0, 0));
    final held = rig.timeline.progress.value;
    await tester.pump(const Duration(milliseconds: 200));
    expect(rig.timeline.progress.value, closeTo(held, 1e-6),
        reason: 'the finger owns the progress again');
    await g.up();
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
      'RTL: dragging toward the leading edge moves forward and flicks '
      'carry the right sign', (tester) async {
    final rig = _rig();
    await tester.pumpWidget(
        _host(rig, NibScrubRelease.momentum, direction: TextDirection.rtl));
    await _scrub(tester, -40,
        flickPxPerSecond: 3000, start: const Offset(180, 50));
    final atRelease = rig.timeline.progress.value;
    expect(atRelease, greaterThan(0.1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(rig.timeline.progress.value, greaterThan(atRelease + 0.02));
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('reduced motion: release modes jump without a ticker',
      (tester) async {
    final rig = _rig();
    await tester
        .pumpWidget(_host(rig, NibScrubRelease.snapToNearest, reduced: true));
    await _scrub(tester, 140);
    await tester.pump(); // starts the release ticker
    await tester.pump();
    expect(rig.timeline.progress.value, 1);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('dispose mid-release leaves no ticker behind', (tester) async {
    final rig = _rig();
    await tester.pumpWidget(_host(rig, NibScrubRelease.momentum));
    await _scrub(tester, 40, flickPxPerSecond: 3000);
    await tester.pump(); // starts the release ticker
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}

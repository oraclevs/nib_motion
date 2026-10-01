import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

class _Rig {
  _Rig(this.controller, this.timeline);
  final NibMotionController controller;
  final NibTimeline timeline;
}

Widget _host({
  required NibMotionController controller,
  required NibTimeline timeline,
  TextDirection direction = TextDirection.ltr,
  Axis axis = Axis.horizontal,
  bool reverse = false,
  bool respectTextDirection = true,
  VoidCallback? onStart,
  VoidCallback? onEnd,
}) =>
    Directionality(
      textDirection: direction,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 200,
          height: 200,
          child: NibTimelineDragScrubber(
            timeline: timeline,
            axis: axis,
            reverse: reverse,
            respectTextDirection: respectTextDirection,
            onScrubStart: onStart,
            onScrubEnd: onEnd,
            child: NibMotion(
              controller: controller,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );

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
  return _Rig(controller, timeline);
}

double _x(WidgetTester tester) {
  RenderNibMotion? render;
  void visit(RenderObject o) {
    if (o is RenderNibMotion) render ??= o;
    o.visitChildren(visit);
  }

  tester.binding.rootElement!.renderObject!.visitChildren(visit);
  return render!.translateX.value;
}

Future<void> _drag(WidgetTester tester, Offset by) async {
  final g = await tester.startGesture(const Offset(100, 100));
  await g.moveBy(by ~/ 2);
  await g.moveBy(by - by ~/ 2);
  await g.up();
  await tester.pump();
}

void main() {
  testWidgets('dragging across the full extent scrubs 0..1', (tester) async {
    final r = _rig();
    addTearDown(r.timeline.dispose);
    addTearDown(r.controller.dispose);
    await tester
        .pumpWidget(_host(controller: r.controller, timeline: r.timeline));
    await _drag(tester, const Offset(100, 0)); // half of 200px
    expect(r.timeline.progress.value, closeTo(0.5, 0.05));
    expect(_x(tester), closeTo(50, 6));
    await _drag(tester, const Offset(100, 0));
    expect(r.timeline.progress.value, closeTo(1.0, 0.05),
        reason: 'a second drag continues from the current progress');
  });

  testWidgets('progress clamps to 0..1', (tester) async {
    final r = _rig();
    addTearDown(r.timeline.dispose);
    addTearDown(r.controller.dispose);
    await tester
        .pumpWidget(_host(controller: r.controller, timeline: r.timeline));
    await _drag(tester, const Offset(-90, 0));
    expect(r.timeline.progress.value, 0.0);
    await _drag(tester, const Offset(90, 0));
    await _drag(tester, const Offset(90, 0));
    await _drag(tester, const Offset(90, 0));
    expect(r.timeline.progress.value, 1.0);
  });

  testWidgets('RTL inverts horizontal scrubbing by default', (tester) async {
    final r = _rig();
    addTearDown(r.timeline.dispose);
    addTearDown(r.controller.dispose);
    await tester.pumpWidget(_host(
        controller: r.controller,
        timeline: r.timeline,
        direction: TextDirection.rtl));
    r.timeline.seek(0.5);
    await _drag(tester, const Offset(50, 0)); // toward the end in LTR
    expect(r.timeline.progress.value, closeTo(0.25, 0.05),
        reason: 'in RTL dragging right goes backward');
    await _drag(tester, const Offset(-100, 0));
    expect(r.timeline.progress.value, closeTo(0.75, 0.05));
  });

  testWidgets('respectTextDirection: false ignores RTL', (tester) async {
    final r = _rig();
    addTearDown(r.timeline.dispose);
    addTearDown(r.controller.dispose);
    await tester.pumpWidget(_host(
        controller: r.controller,
        timeline: r.timeline,
        direction: TextDirection.rtl,
        respectTextDirection: false));
    await _drag(tester, const Offset(100, 0));
    expect(r.timeline.progress.value, closeTo(0.5, 0.05));
  });

  testWidgets('reverse flips the direction', (tester) async {
    final r = _rig();
    addTearDown(r.timeline.dispose);
    addTearDown(r.controller.dispose);
    await tester.pumpWidget(
        _host(controller: r.controller, timeline: r.timeline, reverse: true));
    r.timeline.seek(1.0);
    await _drag(tester, const Offset(100, 0));
    expect(r.timeline.progress.value, closeTo(0.5, 0.05));
  });

  testWidgets('vertical axis scrubs on vertical drags only', (tester) async {
    final r = _rig();
    addTearDown(r.timeline.dispose);
    addTearDown(r.controller.dispose);
    await tester.pumpWidget(_host(
        controller: r.controller, timeline: r.timeline, axis: Axis.vertical));
    await _drag(tester, const Offset(100, 0));
    expect(r.timeline.progress.value, 0.0, reason: 'horizontal ignored');
    await _drag(tester, const Offset(0, 100));
    expect(r.timeline.progress.value, closeTo(0.5, 0.05));
  });

  testWidgets('start/end callbacks fire once per scrub', (tester) async {
    final r = _rig();
    addTearDown(r.timeline.dispose);
    addTearDown(r.controller.dispose);
    var starts = 0, ends = 0;
    await tester.pumpWidget(_host(
        controller: r.controller,
        timeline: r.timeline,
        onStart: () => starts++,
        onEnd: () => ends++));
    await _drag(tester, const Offset(40, 0));
    expect((starts, ends), (1, 1));
  });

  testWidgets('scrubbing cancels a running play()', (tester) async {
    final r = _rig();
    addTearDown(r.timeline.dispose);
    addTearDown(r.controller.dispose);
    await tester
        .pumpWidget(_host(controller: r.controller, timeline: r.timeline));
    r.timeline.play();
    await tester.pump(const Duration(milliseconds: 100));
    await _drag(tester, const Offset(40, 0));
    final at = r.timeline.progress.value;
    await tester.pump(const Duration(seconds: 2));
    expect(r.timeline.progress.value, at);
  });
}

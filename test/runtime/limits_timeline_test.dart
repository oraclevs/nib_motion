import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

RenderNibMotion _render(WidgetTester tester) {
  RenderNibMotion? found;
  void visit(RenderObject o) {
    if (o is RenderNibMotion) found ??= o;
    o.visitChildren(visit);
  }

  tester.binding.rootElement!.renderObject!.visitChildren(visit);
  return found!;
}

void main() {
  testWidgets('drag scrubbing needs no `from:` and no `initial:` on the widget',
      (tester) async {
    final controller = NibMotionController();
    final timeline = NibTimeline([
      NibTimelineEntry(
        controller: controller,
        target: const NibAnim(opacity: 0, color: Color(0xFF0000FF)),
        at: Duration.zero,
        transition: const NibTransition(
            duration: Duration(milliseconds: 1000), curve: Curves.linear),
      ),
    ]);
    addTearDown(timeline.dispose);
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 200,
          height: 200,
          child: NibTimelineDragScrubber(
            timeline: timeline,
            extent: 200,
            child: NibMotion(
              controller: controller, // no initial, entry has no `from`
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    ));
    final g = await tester.startGesture(const Offset(10, 100));
    await g.moveBy(const Offset(40, 0));
    await g.moveBy(const Offset(60, 0)); // 100px of 200 => half
    await tester.pump();
    expect(timeline.progress.value, closeTo(0.5, 0.05));
    expect(_render(tester).opacity.value, closeTo(0.5, 0.06),
        reason: 'opacity lerps from identity (1.0), not stepping at the end');
    expect(_render(tester).color.value, isNotNull,
        reason: 'colour lerps from "no colour" toward the target');
    await g.up();
  });
}

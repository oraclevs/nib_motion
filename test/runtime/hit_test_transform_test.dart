import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _wrap(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: child),
    );

void main() {
  group('RenderNibMotion coordinate spaces', () {
    testWidgets('descendants receive taps at the painted (translated) position',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(
        NibMotion(
          initial: const NibAnim(x: 200),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: const SizedBox(width: 50, height: 50),
          ),
        ),
      ));

      // Painted at x 200..250, laid out at x 0..50.
      await tester.tapAt(const Offset(225, 25));
      expect(taps, 1, reason: 'tap on painted location must reach child');

      await tester.tapAt(const Offset(25, 25));
      expect(taps, 1,
          reason: 'layout location is empty; nothing painted there');
    });

    testWidgets('localToGlobal reflects the animated transform',
        (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(_wrap(
        NibMotion(
          initial: const NibAnim(x: 120, y: 30),
          child: SizedBox(key: key, width: 50, height: 50),
        ),
      ));
      final box = key.currentContext!.findRenderObject()! as RenderBox;
      expect(box.localToGlobal(Offset.zero), const Offset(120, 30));
    });

    testWidgets('a dragged element can be grabbed again where it was dropped',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const NibMotion(
          drag: NibDragConfig(releaseMode: NibDragReleaseMode.stay),
          child: SizedBox(width: 50, height: 50),
        ),
      ));

      final first = await tester.startGesture(const Offset(25, 25));
      await first.moveBy(const Offset(100, 0));
      await first.moveBy(const Offset(0, 0));
      await first.up();
      await tester.pump();

      // Element now painted at x 100..150. Grab it there and drag further.
      final second = await tester.startGesture(const Offset(125, 25));
      await second.moveBy(const Offset(60, 0));
      await second.moveBy(const Offset(0, 0));
      await second.up();
      await tester.pump();

      RenderNibMotion? render;
      void visit(RenderObject o) {
        if (o is RenderNibMotion) render = o;
        o.visitChildren(visit);
      }

      tester.binding.rootElement!.renderObject!.visitChildren(visit);
      expect(render!.translateX.value, closeTo(160, 1.0));
    });
  });

  group('NibDraggable / NibPinch coordinate spaces', () {
    testWidgets('NibDraggable can be grabbed again where it was dropped',
        (tester) async {
      final ends = <Offset>[];
      await tester.pumpWidget(_wrap(NibDraggable(
        snapBack: false,
        onDragEnd: (offset, _) => ends.add(offset),
        child: const SizedBox(width: 50, height: 50),
      )));
      final first = await tester.startGesture(const Offset(25, 25));
      await first.moveBy(const Offset(100, 0));
      await first.moveBy(const Offset(0, 0));
      await first.up();
      await tester.pump();
      final second = await tester.startGesture(const Offset(125, 25));
      await second.moveBy(const Offset(60, 0));
      await second.moveBy(const Offset(0, 0));
      await second.up();
      await tester.pump();
      expect(ends.length, 2);
      expect(ends.last.dx, closeTo(160, 1.0));
    });

    testWidgets('NibPinch child receives taps inside its scaled bounds',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(NibPinch(
        initialScale: 2.0,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => taps++,
          child: const SizedBox(width: 50, height: 50),
        ),
      )));
      await tester.pump();
      // Scaled 2x about its centre (25,25): painted 0-25 .. 75 → -25..75.
      await tester.tapAt(const Offset(70, 25));
      expect(taps, 1);
    });
  });
}

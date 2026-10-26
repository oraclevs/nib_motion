import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';
import 'package:nib_motion/src/gestures/drag_handler.dart';

Widget _wrap(Widget child) {
  return Directionality(
      textDirection: TextDirection.ltr, child: Center(child: child));
}

RenderNibMotion _findRenderNibMotion(WidgetTester tester) {
  RenderNibMotion? found;
  void visit(RenderObject object) {
    if (object is RenderNibMotion) {
      found = object;
      return;
    }
    object.visitChildren(visit);
  }

  tester.binding.rootElement!.renderObject!.visitChildren(visit);
  return found!;
}

void main() {
  group('DragHandler', () {
    testWidgets('release velocity uses the same local units as drag offset',
        (tester) async {
      Velocity? released;
      final handler = DragHandler(
        config: const NibDragConfig(),
        onUpdate: (_) {},
        onRelease: (_, velocity) => released = velocity,
      );

      handler.handlePanStart(DragStartDetails());
      for (var i = 1; i <= 5; i++) {
        handler.handlePanUpdate(DragUpdateDetails(
          sourceTimeStamp: Duration(milliseconds: i * 10),
          globalPosition: Offset(i * 20.0, 0),
          delta: const Offset(10, 0),
        ));
      }
      handler.handlePanEnd(DragEndDetails());

      expect(released, isNotNull);
      expect(released!.pixelsPerSecond.dx, closeTo(1000, 250));
    });

    testWidgets(
        'reports the raw drag offset, which a NibMotion writes to translateX',
        (tester) async {
      final translateX = MotionValue<double>(0.0);

      final handler = DragHandler(
        config: const NibDragConfig(),
        onUpdate: (offset) => translateX.value = offset.dx,
        onRelease: (_, __) {},
      );

      handler.handlePanStart(DragStartDetails());
      handler.handlePanUpdate(DragUpdateDetails(
          globalPosition: const Offset(100, 0), delta: const Offset(100, 0)));

      expect(translateX.value, 100.0);
    });

    testWidgets('axis-locked drag only updates the locked axis',
        (tester) async {
      Offset? lastOffset;
      final handler = DragHandler(
        config: const NibDragConfig(axis: Axis.vertical),
        onUpdate: (offset) => lastOffset = offset,
        onRelease: (_, __) {},
      );

      handler.handlePanStart(DragStartDetails());
      handler.handlePanUpdate(DragUpdateDetails(
          globalPosition: const Offset(50, 80), delta: const Offset(50, 80)));

      expect(lastOffset, const Offset(0, 80));
    });

    testWidgets('elastic constraint dampens movement past the bound',
        (tester) async {
      Offset? lastOffset;
      final handler = DragHandler(
        config: const NibDragConfig(
          constraints: Rect.fromLTRB(0, 0, 0, 0),
          elastic: true,
          elasticFactor: 0.2,
        ),
        onUpdate: (offset) => lastOffset = offset,
        onRelease: (_, __) {},
      );

      handler.handlePanStart(DragStartDetails());
      handler.handlePanUpdate(DragUpdateDetails(
          globalPosition: const Offset(100, 0), delta: const Offset(100, 0)));

      expect(lastOffset!.dx, greaterThan(0.0));
      expect(lastOffset!.dx, lessThan(100.0));
    });
  });

  group('NibMotion drag', () {
    testWidgets('dragging moves translateX toward the drag offset',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibMotion(
            drag: const NibDragConfig(releaseMode: NibDragReleaseMode.stay),
            child: const SizedBox(width: 50, height: 50),
          ),
        ),
      );

      await tester.drag(find.byType(SizedBox), const Offset(100, 0),
          touchSlopX: 0, touchSlopY: 0, warnIfMissed: false);
      await tester.pump();

      final renderObject = _findRenderNibMotion(tester);
      expect(renderObject.translateX.value, greaterThan(50.0));
      expect(renderObject.translateY.value, 0.0);
    });

    testWidgets('Axis.vertical drag keeps translateX at 0 and moves translateY',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibMotion(
            drag: const NibDragConfig(
                axis: Axis.vertical, releaseMode: NibDragReleaseMode.stay),
            child: const SizedBox(width: 50, height: 50),
          ),
        ),
      );

      await tester.drag(find.byType(SizedBox), const Offset(60, 80),
          touchSlopX: 0, touchSlopY: 0, warnIfMissed: false);
      await tester.pump();

      final renderObject = _findRenderNibMotion(tester);
      expect(renderObject.translateX.value, 0.0);
      expect(renderObject.translateY.value, greaterThan(0.0));
    });

    testWidgets('releasing with springBack returns translateX/Y to 0',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibMotion(
            drag: const NibDragConfig(),
            child: const SizedBox(width: 50, height: 50),
          ),
        ),
      );

      await tester.drag(find.byType(SizedBox), const Offset(100, 50),
          touchSlopX: 0, touchSlopY: 0, warnIfMissed: false);

      final renderObject = _findRenderNibMotion(tester);
      expect(renderObject.translateX.value, greaterThan(0.0));

      await tester.pumpAndSettle();

      expect(renderObject.translateX.value, closeTo(0.0, 0.5));
      expect(renderObject.translateY.value, closeTo(0.0, 0.5));
    });

    testWidgets(
        'releasing with inertia coasts past the release point before stopping',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibMotion(
            drag: const NibDragConfig(releaseMode: NibDragReleaseMode.inertia),
            child: const SizedBox(width: 50, height: 50),
          ),
        ),
      );

      await tester.fling(find.byType(SizedBox), const Offset(100, 0), 1000,
          warnIfMissed: false);

      final renderObject = _findRenderNibMotion(tester);
      final valueAtRelease = renderObject.translateX.value;
      expect(valueAtRelease, greaterThan(0.0));

      // The inertia ticker's start time is anchored on its first tick, so an
      // initial zero-duration pump is needed before a timed pump shows
      // elapsed time > 0.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(renderObject.translateX.value, greaterThan(valueAtRelease));

      await tester.pumpAndSettle();
      final settled = renderObject.translateX.value;
      await tester.pump(const Duration(milliseconds: 100));
      expect(renderObject.translateX.value, closeTo(settled, 0.001));
    });

    testWidgets('release near a snap point snaps to it instead of 0',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibMotion(
            drag:
                const NibDragConfig(snapPoints: [Offset(100, 0), Offset(0, 0)]),
            child: const SizedBox(width: 50, height: 50),
          ),
        ),
      );

      await tester.drag(find.byType(SizedBox), const Offset(90, 0),
          touchSlopX: 0, touchSlopY: 0, warnIfMissed: false);
      await tester.pumpAndSettle();

      final renderObject = _findRenderNibMotion(tester);
      expect(renderObject.translateX.value, closeTo(100.0, 0.5));
    });

    testWidgets('whileDrag is applied during the drag and reverted on release',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibMotion(
            initial: const NibAnim(scale: 1.0),
            drag: const NibDragConfig(),
            whileDrag: const NibAnim(scale: 1.1),
            transition:
                const NibTransition(duration: Duration(milliseconds: 50)),
            child: const SizedBox(width: 50, height: 50),
          ),
        ),
      );

      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(SizedBox)));
      await tester.pump();
      await gesture.moveBy(const Offset(20, 0));
      await tester.pumpAndSettle();

      final renderObject = _findRenderNibMotion(tester);
      expect(renderObject.scaleX.value, closeTo(1.1, 0.001));

      await gesture.up();
      await tester.pumpAndSettle();

      expect(renderObject.scaleX.value, closeTo(1.0, 0.001));
    });
  });
}

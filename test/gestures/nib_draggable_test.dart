import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/src/gestures/nib_draggable.dart';

Widget _wrap(Widget child) {
  return Directionality(textDirection: TextDirection.ltr, child: Center(child: child));
}

void main() {
  group('NibDraggable', () {
    testWidgets('dragging moves the widget by the drag delta', (tester) async {
      Offset? lastUpdate;
      await tester.pumpWidget(
        _wrap(
          NibDraggable(
            onDragUpdate: (offset) => lastUpdate = offset,
            child: const SizedBox(width: 50, height: 50, key: ValueKey('box')),
          ),
        ),
      );

      await tester.drag(find.byKey(const ValueKey('box')), const Offset(80, 30), touchSlopX: 0, touchSlopY: 0, warnIfMissed: false);
      await tester.pump();

      expect(lastUpdate, isNotNull);
      expect(lastUpdate!.dx, closeTo(80, 0.5));
      expect(lastUpdate!.dy, closeTo(30, 0.5));
    });

    testWidgets('onDragEnd reports the offset at release before snapping back', (tester) async {
      Offset? finalOffset;
      await tester.pumpWidget(
        _wrap(
          NibDraggable(
            snapBack: true,
            onDragEnd: (offset, velocity) => finalOffset = offset,
            child: const SizedBox(width: 50, height: 50, key: ValueKey('box')),
          ),
        ),
      );

      await tester.drag(find.byKey(const ValueKey('box')), const Offset(100, 0), touchSlopX: 0, touchSlopY: 0, warnIfMissed: false);
      expect(finalOffset, isNotNull);
      expect(finalOffset!.dx, greaterThan(0));
    });

    testWidgets('snapBack settles translation back near zero', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibDraggable(
            snapBack: true,
            child: const SizedBox(width: 50, height: 50, key: ValueKey('box')),
          ),
        ),
      );

      final boxFinderBefore = tester.getTopLeft(find.byKey(const ValueKey('box')));
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('box'))));
      await gesture.moveBy(const Offset(100, 50));
      await tester.pump();

      final duringDrag = tester.getTopLeft(find.byKey(const ValueKey('box')));
      expect(duringDrag.dx, greaterThan(boxFinderBefore.dx));

      await gesture.up();
      await tester.pumpAndSettle();

      final afterSettle = tester.getTopLeft(find.byKey(const ValueKey('box')));
      expect(afterSettle.dx, closeTo(boxFinderBefore.dx, 0.5));
      expect(afterSettle.dy, closeTo(boxFinderBefore.dy, 0.5));
    });

    testWidgets('axis lock constrains movement to one axis', (tester) async {
      Offset? lastUpdate;
      await tester.pumpWidget(
        _wrap(
          NibDraggable(
            axis: Axis.horizontal,
            onDragUpdate: (offset) => lastUpdate = offset,
            child: const SizedBox(width: 50, height: 50, key: ValueKey('box')),
          ),
        ),
      );

      await tester.drag(find.byKey(const ValueKey('box')), const Offset(40, 90), touchSlopX: 0, touchSlopY: 0, warnIfMissed: false);
      await tester.pump();

      expect(lastUpdate, isNotNull);
      expect(lastUpdate!.dy, 0.0);
      expect(lastUpdate!.dx, closeTo(40, 0.5));
    });

    testWidgets('bounds clamp the offset', (tester) async {
      Offset? lastUpdate;
      await tester.pumpWidget(
        _wrap(
          NibDraggable(
            bounds: const Rect.fromLTRB(0, 0, 20, 20),
            onDragUpdate: (offset) => lastUpdate = offset,
            child: const SizedBox(width: 50, height: 50, key: ValueKey('box')),
          ),
        ),
      );

      await tester.drag(find.byKey(const ValueKey('box')), const Offset(200, 200), touchSlopX: 0, touchSlopY: 0, warnIfMissed: false);
      await tester.pump();

      expect(lastUpdate, isNotNull);
      expect(lastUpdate!.dx, 20.0);
      expect(lastUpdate!.dy, 20.0);
    });
  });
}

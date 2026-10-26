import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/src/gestures/nib_draggable.dart';

Widget _wrap(Widget child) {
  return Directionality(
      textDirection: TextDirection.ltr, child: Center(child: child));
}

void main() {
  group('NibDraggable', () {
    testWidgets('nested rotation and nonuniform scale keep release units local',
        (tester) async {
      Offset? releasedOffset;
      Offset? releasedVelocity;
      await tester.pumpWidget(_wrap(
        Transform.rotate(
          angle: math.pi / 2,
          alignment: Alignment.topLeft,
          child: Transform.scale(
            scaleX: 2,
            scaleY: 0.5,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 200,
              height: 200,
              child: Align(
                alignment: Alignment.topLeft,
                child: NibDraggable(
                  snapBack: false,
                  onDragEnd: (offset, velocity) {
                    releasedOffset = offset;
                    releasedVelocity = velocity;
                  },
                  child: const SizedBox(
                    width: 50,
                    height: 50,
                    key: ValueKey('rotated-drag-box'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ));

      final box = find.byKey(const ValueKey('rotated-drag-box'));
      final before = tester.getCenter(box);
      final gesture = await tester.startGesture(before);
      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(
          const Offset(0, 20),
          timeStamp: Duration(milliseconds: (i + 1) * 10),
        );
      }
      await tester.pump();
      expect(tester.getCenter(box).dy, closeTo(before.dy + 100, 20),
          reason: 'the hit target follows the painted drag direction');
      await gesture.up();

      expect(releasedOffset, isNotNull);
      expect(releasedVelocity, isNotNull);
      expect(releasedOffset!.dx, closeTo(50, 10));
      expect(releasedOffset!.dy, closeTo(0, 1));
      expect(releasedVelocity!.dx, closeTo(1000, 300));
      expect(releasedVelocity!.dy, closeTo(0, 50));
    });

    testWidgets('scaled parent reports release velocity in drag-offset units',
        (tester) async {
      Offset? releasedOffset;
      Offset? releasedVelocity;
      await tester.pumpWidget(_wrap(
        Transform.scale(
          scale: 2,
          child: NibDraggable(
            snapBack: false,
            onDragEnd: (offset, velocity) {
              releasedOffset = offset;
              releasedVelocity = velocity;
            },
            child: const SizedBox(
                width: 50, height: 50, key: ValueKey('scaled-drag-box')),
          ),
        ),
      ));

      final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('scaled-drag-box'))));
      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(
          const Offset(20, 0),
          timeStamp: Duration(milliseconds: (i + 1) * 10),
        );
      }
      await gesture.up();

      expect(releasedOffset, isNotNull);
      expect(releasedVelocity, isNotNull);
      expect(releasedOffset!.dx, closeTo(50, 10));
      expect(releasedVelocity!.dx, closeTo(1000, 300));
    });

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

      await tester.drag(find.byKey(const ValueKey('box')), const Offset(80, 30),
          touchSlopX: 0, touchSlopY: 0, warnIfMissed: false);
      await tester.pump();

      expect(lastUpdate, isNotNull);
      expect(lastUpdate!.dx, closeTo(80, 0.5));
      expect(lastUpdate!.dy, closeTo(30, 0.5));
    });

    testWidgets('onDragEnd reports the offset at release before snapping back',
        (tester) async {
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

      await tester.drag(find.byKey(const ValueKey('box')), const Offset(100, 0),
          touchSlopX: 0, touchSlopY: 0, warnIfMissed: false);
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

      final boxFinderBefore =
          tester.getTopLeft(find.byKey(const ValueKey('box')));
      final gesture = await tester
          .startGesture(tester.getCenter(find.byKey(const ValueKey('box'))));
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

      await tester.drag(find.byKey(const ValueKey('box')), const Offset(40, 90),
          touchSlopX: 0, touchSlopY: 0, warnIfMissed: false);
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

      await tester.drag(
          find.byKey(const ValueKey('box')), const Offset(200, 200),
          touchSlopX: 0, touchSlopY: 0, warnIfMissed: false);
      await tester.pump();

      expect(lastUpdate, isNotNull);
      expect(lastUpdate!.dx, 20.0);
      expect(lastUpdate!.dy, 20.0);
    });
  });
}

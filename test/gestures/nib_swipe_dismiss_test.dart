import 'package:flutter/material.dart' hide DismissDirection;
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/src/gestures/nib_swipe_dismiss.dart';

Widget _wrap(Widget child) {
  return Directionality(
      textDirection: TextDirection.ltr, child: Center(child: child));
}

/// Locates [NibSwipeDismiss]'s internal render object (`_RenderNibSwipeDismiss`,
/// private to `nib_swipe_dismiss.dart`) by walking the render tree and
/// matching on `runtimeType`.
RenderObject _findRenderNibSwipeDismiss(WidgetTester tester) {
  RenderObject? found;
  void visit(RenderObject object) {
    if (object.runtimeType.toString() == '_RenderNibSwipeDismiss') {
      found = object;
      return;
    }
    object.visitChildren(visit);
  }

  tester.binding.rootElement!.renderObject!.visitChildren(visit);
  return found!;
}

double _readOffset(RenderObject renderNibSwipeDismiss) {
  final getter = (renderNibSwipeDismiss as dynamic).offset;
  return (getter as dynamic).value as double;
}

void main() {
  group('NibSwipeDismiss', () {
    testWidgets('swiping past dismissThreshold calls onDismissed',
        (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 200,
            height: 80,
            child: NibSwipeDismiss(
              onDismissed: () => dismissed = true,
              dismissThreshold: 0.4,
              child: Container(key: const ValueKey('box'), color: Colors.red),
            ),
          ),
        ),
      );

      await tester.fling(
          find.byKey(const ValueKey('box')), const Offset(150, 0), 1000,
          warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });

    testWidgets(
        'swiping below dismissThreshold springs back without dismissing',
        (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 200,
            height: 80,
            child: NibSwipeDismiss(
              onDismissed: () => dismissed = true,
              dismissThreshold: 0.6,
              child: Container(key: const ValueKey('box'), color: Colors.red),
            ),
          ),
        ),
      );

      final renderObject = _findRenderNibSwipeDismiss(tester);

      await tester.drag(find.byKey(const ValueKey('box')), const Offset(40, 0),
          touchSlopX: 0, touchSlopY: 0, warnIfMissed: false);
      await tester.pump();

      expect(_readOffset(renderObject), greaterThan(0.0));
      expect(dismissed, isFalse);

      await tester.pumpAndSettle();

      expect(dismissed, isFalse);
      expect(_readOffset(renderObject), closeTo(0.0, 0.5));
    });

    testWidgets('background is shown behind the child while swiping',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 200,
            height: 80,
            child: NibSwipeDismiss(
              onDismissed: () {},
              background:
                  Container(key: const ValueKey('bg'), color: Colors.green),
              child: Container(key: const ValueKey('box'), color: Colors.red),
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('bg')), findsOneWidget);
      expect(find.byKey(const ValueKey('box')), findsOneWidget);
    });

    testWidgets('vertical dismissDirection moves the offset vertically',
        (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 80,
            height: 200,
            child: NibSwipeDismiss(
              onDismissed: () => dismissed = true,
              dismissDirection: DismissDirection.vertical,
              dismissThreshold: 0.4,
              child: Container(key: const ValueKey('box'), color: Colors.red),
            ),
          ),
        ),
      );

      await tester.fling(
          find.byKey(const ValueKey('box')), const Offset(0, 150), 1000,
          warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });
  });
}

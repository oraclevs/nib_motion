import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/src/gestures/nib_pinch.dart';

Widget _wrap(Widget child) {
  return Directionality(
      textDirection: TextDirection.ltr, child: Center(child: child));
}

/// Locates [NibPinch]'s internal render object (named `_RenderNibPinch`,
/// private to `nib_pinch.dart`) by walking the render tree and matching on
/// `runtimeType` — the same approach `nib_drag_test.dart` uses for
/// `RenderNibMotion`, adapted for a type that isn't exported.
RenderObject _findRenderNibPinch(WidgetTester tester) {
  RenderObject? found;
  void visit(RenderObject object) {
    if (object.runtimeType.toString() == '_RenderNibPinch') {
      found = object;
      return;
    }
    object.visitChildren(visit);
  }

  tester.binding.rootElement!.renderObject!.visitChildren(visit);
  return found!;
}

/// Reads the uniform scale `_RenderNibPinch` currently applies, via the
/// X-axis scale entry (`[0]`) of the `Matrix4` it paints with.
double _readScale(RenderObject renderNibPinch) {
  final getter = (renderNibPinch as dynamic).scale;
  return (getter as dynamic).value as double;
}

/// Simulates a two-finger pinch by driving two synthetic pointers apart (or
/// together) so `GestureDetector.onScaleUpdate` receives a non-1.0 `scale`.
Future<void> _pinch(
    WidgetTester tester, Finder target, double scaleFactor) async {
  final center = tester.getCenter(target);
  const startSpread = 40.0;
  final endSpread = startSpread * scaleFactor;

  final pointer1 = TestPointer(1);
  final pointer2 = TestPointer(2);

  await tester.sendEventToBinding(
      pointer1.down(center + const Offset(-startSpread / 2, 0)));
  await tester.sendEventToBinding(
      pointer2.down(center + const Offset(startSpread / 2, 0)));
  await tester.pump(const Duration(milliseconds: 16));

  const steps = 5;
  for (var i = 1; i <= steps; i++) {
    final t = i / steps;
    final spread = startSpread + (endSpread - startSpread) * t;
    await tester
        .sendEventToBinding(pointer1.move(center + Offset(-spread / 2, 0)));
    await tester
        .sendEventToBinding(pointer2.move(center + Offset(spread / 2, 0)));
    await tester.pump(const Duration(milliseconds: 16));
  }

  await tester.sendEventToBinding(pointer1.up());
  await tester.sendEventToBinding(pointer2.up());
}

void main() {
  group('NibPinch', () {
    testWidgets('pinching out increases scale within bounds', (tester) async {
      double? lastScale;
      await tester.pumpWidget(
        _wrap(
          NibPinch(
            onScaleChanged: (scale) => lastScale = scale,
            child:
                const SizedBox(width: 100, height: 100, key: ValueKey('box')),
          ),
        ),
      );

      await _pinch(tester, find.byKey(const ValueKey('box')), 2.0);
      await tester.pump();

      expect(lastScale, isNotNull);
      expect(lastScale!, greaterThan(1.0));
      expect(lastScale!, lessThanOrEqualTo(4.0));
    });

    testWidgets('scale is clamped to maxScale', (tester) async {
      double? lastScale;
      await tester.pumpWidget(
        _wrap(
          NibPinch(
            maxScale: 1.5,
            onScaleChanged: (scale) => lastScale = scale,
            child:
                const SizedBox(width: 100, height: 100, key: ValueKey('box')),
          ),
        ),
      );

      await _pinch(tester, find.byKey(const ValueKey('box')), 10.0);
      await tester.pump();

      expect(lastScale, isNotNull);
      expect(lastScale!, lessThanOrEqualTo(1.5));
    });

    testWidgets('scale is clamped to minScale', (tester) async {
      double? lastScale;
      await tester.pumpWidget(
        _wrap(
          NibPinch(
            minScale: 0.8,
            onScaleChanged: (scale) => lastScale = scale,
            child:
                const SizedBox(width: 100, height: 100, key: ValueKey('box')),
          ),
        ),
      );

      await _pinch(tester, find.byKey(const ValueKey('box')), 0.1);
      await tester.pump();

      expect(lastScale, isNotNull);
      expect(lastScale!, greaterThanOrEqualTo(0.8));
    });

    testWidgets('onScaleChanged fires during the gesture', (tester) async {
      var callCount = 0;
      await tester.pumpWidget(
        _wrap(
          NibPinch(
            onScaleChanged: (scale) => callCount++,
            child:
                const SizedBox(width: 100, height: 100, key: ValueKey('box')),
          ),
        ),
      );

      await _pinch(tester, find.byKey(const ValueKey('box')), 2.0);

      expect(callCount, greaterThan(0));
    });

    testWidgets('snapBackOnRelease returns scale to initialScale',
        (tester) async {
      final scaleHistory = <double>[];
      await tester.pumpWidget(
        _wrap(
          NibPinch(
            initialScale: 1.0,
            snapBackOnRelease: true,
            onScaleChanged: scaleHistory.add,
            child:
                const SizedBox(width: 100, height: 100, key: ValueKey('box')),
          ),
        ),
      );

      await _pinch(tester, find.byKey(const ValueKey('box')), 2.0);
      expect(scaleHistory, isNotEmpty);
      expect(scaleHistory.last, greaterThan(1.0));

      final renderObject = _findRenderNibPinch(tester);
      expect(_readScale(renderObject), greaterThan(1.0));

      await tester.pumpAndSettle();
      expect(_readScale(renderObject), closeTo(1.0, 0.01));
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';
import 'package:nib_motion/src/layout/flip_recorder.dart';

Widget _wrap(Widget child) {
  return Directionality(textDirection: TextDirection.ltr, child: Center(child: child));
}

/// Walks up from the [RenderObject] of the widget with [key] to find its
/// nearest [RenderNibMotion] ancestor.
RenderNibMotion _findRenderNibMotionFor(WidgetTester tester, Key key) {
  RenderObject? object = find.byKey(key).evaluate().single.renderObject;
  while (object != null && object is! RenderNibMotion) {
    object = object.parent;
  }
  return object! as RenderNibMotion;
}

void main() {
  group('FlipRecorder', () {
    testWidgets('computeDelta returns null until a position has been recorded', (tester) async {
      final key = GlobalKey();
      final recorder = FlipRecorder();

      await tester.pumpWidget(_wrap(SizedBox(key: key, width: 50, height: 50)));

      expect(recorder.computeDelta(key), isNull);
    });

    testWidgets('forget stops tracking a key', (tester) async {
      final key = GlobalKey();
      final recorder = FlipRecorder();

      await tester.pumpWidget(_wrap(SizedBox(key: key, width: 50, height: 50)));
      recorder.record(key);
      expect(recorder.computeDelta(key), isNotNull);

      recorder.forget(key);
      expect(recorder.computeDelta(key), isNull);
    });

    testWidgets('computeDelta reflects the position shift caused by a size change', (tester) async {
      final key = GlobalKey();
      final recorder = FlipRecorder();

      await tester.pumpWidget(_wrap(SizedBox(key: key, width: 50, height: 50)));
      recorder.record(key);
      expect(recorder.rectFor(key)!.size, const Size(50, 50));

      // Growing while centered shifts the top edge up by half the growth.
      await tester.pumpWidget(_wrap(SizedBox(key: key, width: 50, height: 100)));
      final delta = recorder.computeDelta(key);

      expect(delta, isNotNull);
      expect(delta!.dy, closeTo(25.0, 0.5));
    });
  });

  group('NibLayoutGroup', () {
    testWidgets('a child that moves to a new position FLIPs back into place', (tester) async {
      Widget build(List<Widget> children) => _wrap(NibLayoutGroup(children: children));

      await tester.pumpWidget(
        build(const [
          SizedBox(key: ValueKey('a'), width: 50, height: 50),
          SizedBox(key: ValueKey('b'), width: 50, height: 50),
        ]),
      );
      await tester.pumpAndSettle();

      // Swap order: 'a' moves from the top slot to the bottom slot.
      await tester.pumpWidget(
        build(const [
          SizedBox(key: ValueKey('b'), width: 50, height: 50),
          SizedBox(key: ValueKey('a'), width: 50, height: 50),
        ]),
      );
      await tester.pump();

      final renderA = _findRenderNibMotionFor(tester, const ValueKey('a'));
      // Inverted immediately: 'a' visually stays at its old position.
      expect(renderA.translateY.value, lessThan(-1.0));

      await tester.pumpAndSettle();
      // Played back to its new position.
      expect(renderA.translateY.value, closeTo(0.0, 0.5));
    });

    testWidgets('a newly added child does not FLIP', (tester) async {
      Widget build(List<Widget> children) => _wrap(NibLayoutGroup(children: children));

      await tester.pumpWidget(
        build(const [SizedBox(key: ValueKey('a'), width: 50, height: 50)]),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        build(const [
          SizedBox(key: ValueKey('new'), width: 50, height: 50),
          SizedBox(key: ValueKey('a'), width: 50, height: 50),
        ]),
      );
      await tester.pump();

      final renderNew = _findRenderNibMotionFor(tester, const ValueKey('new'));
      expect(renderNew.translateY.value, 0.0);
    });

    testWidgets('a removed child is not tracked when re-added later', (tester) async {
      Widget build(List<Widget> children) => _wrap(NibLayoutGroup(children: children));

      await tester.pumpWidget(
        build(const [
          SizedBox(key: ValueKey('a'), width: 50, height: 50),
          SizedBox(key: ValueKey('b'), width: 50, height: 100),
        ]),
      );
      await tester.pumpAndSettle();

      // Remove 'a'.
      await tester.pumpWidget(
        build(const [SizedBox(key: ValueKey('b'), width: 50, height: 100)]),
      );
      await tester.pumpAndSettle();

      // Re-add 'a' below 'b' -- a fresh mount, not a FLIP from its old slot.
      await tester.pumpWidget(
        build(const [
          SizedBox(key: ValueKey('b'), width: 50, height: 100),
          SizedBox(key: ValueKey('a'), width: 50, height: 50),
        ]),
      );
      await tester.pump();

      final renderA = _findRenderNibMotionFor(tester, const ValueKey('a'));
      expect(renderA.translateY.value, 0.0);
    });
  });
}

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _box(String id) => SizedBox(key: ValueKey(id), width: 50, height: 50);

Widget _host(List<String> ids, {double scale = 1}) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topLeft,
          child: NibLayoutGroup(children: [for (final id in ids) _box(id)]),
        ),
      ),
    );

/// Global painted top-left of the child with [id] (includes NibMotion's own
/// in-flight FLIP transform because the SizedBox is a *child* of it).
Offset _painted(WidgetTester tester, String id) {
  final box = tester.renderObject<RenderBox>(find.byKey(ValueKey(id)));
  return box.localToGlobal(Offset.zero);
}

void main() {
  group('NibLayoutGroup interruption', () {
    testWidgets('re-ordering mid-flight does not visually jump',
        (tester) async {
      await tester.pumpWidget(_host(['a', 'b']));
      await tester.pumpAndSettle();

      await tester.pumpWidget(_host(['b', 'a']));
      await tester.pump(); // FLIP inverted, a painted at its old slot
      await tester.pump(const Duration(milliseconds: 60));
      final beforeA = _painted(tester, 'a');
      final beforeB = _painted(tester, 'b');
      // Sanity: genuinely mid-flight (between slots 0 and 50).
      expect(beforeA.dy, inExclusiveRange(1, 49));

      await tester.pumpWidget(_host(['a', 'b'])); // interrupt
      await tester.pump(); // post-frame FLIP measurement applied
      await tester.pump(); // painted with the new transform

      expect(_painted(tester, 'a').dy, closeTo(beforeA.dy, 0.75),
          reason: 'a must continue from where it was painted');
      expect(_painted(tester, 'b').dy, closeTo(beforeB.dy, 0.75));
      await tester.pumpAndSettle();
      expect(_painted(tester, 'a').dy, closeTo(0, 0.1));
      expect(_painted(tester, 'b').dy, closeTo(50, 0.1));
    });

    testWidgets('mid-flight interruption keeps momentum', (tester) async {
      await tester.pumpWidget(_host(['a', 'b']));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_host(['b', 'a']));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final y0 = _painted(tester, 'a').dy;
      await tester.pump(const Duration(milliseconds: 16));
      final moving = _painted(tester, 'a').dy - y0;
      expect(moving, greaterThan(0), reason: 'a travels down toward slot 1');

      await tester.pumpWidget(_host(['a', 'b'])); // target flips back up
      await tester.pump();
      final y1 = _painted(tester, 'a').dy;
      await tester.pump(const Duration(milliseconds: 4));
      await tester.pump(const Duration(milliseconds: 4));
      expect(_painted(tester, 'a').dy, greaterThan(y1),
          reason: 'downward momentum carries on briefly before turning back');
      await tester.pumpAndSettle();
    });
  });

  group('NibLayoutGroup coordinate spaces', () {
    testWidgets('scaled ancestor: FLIP inverts by the on-screen distance',
        (tester) async {
      await tester.pumpWidget(_host(['a', 'b'], scale: 2));
      await tester.pumpAndSettle();
      expect(_painted(tester, 'a').dy, closeTo(0, 0.01));
      expect(_painted(tester, 'b').dy, closeTo(100, 0.01)); // 50 * 2

      await tester.pumpWidget(_host(['b', 'a'], scale: 2));
      await tester.pump(); // inverted: a painted where it just was
      expect(_painted(tester, 'a').dy, closeTo(0, 0.5),
          reason: 'no jump under a transformed ancestor');
      expect(_painted(tester, 'b').dy, closeTo(100, 0.5));
      await tester.pumpAndSettle();
      expect(_painted(tester, 'a').dy, closeTo(100, 0.1));
      expect(_painted(tester, 'b').dy, closeTo(0, 0.1));
    });

    testWidgets('moving the whole group is not mistaken for child movement',
        (tester) async {
      Widget host(double inset) => Directionality(
            textDirection: TextDirection.ltr,
            child: Padding(
              padding: EdgeInsets.only(top: inset),
              child: NibLayoutGroup(children: [_box('a'), _box('b')]),
            ),
          );
      await tester.pumpWidget(host(0));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(80));
      await tester.pump();
      // The group moved as a unit; children keep their slots in the group.
      expect(tester.hasRunningAnimations, isFalse,
          reason: 'no FLIP should start when only the container moved');
      expect(_painted(tester, 'a').dy, closeTo(80, 0.01));
      expect(_painted(tester, 'b').dy, closeTo(130, 0.01));
    });
  });
}

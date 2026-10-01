import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _wrap(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: child),
    );

RenderNibMotion _renderFor(WidgetTester tester, Key key) {
  RenderObject? object = find.byKey(key).evaluate().single.renderObject;
  while (object != null && object is! RenderNibMotion) {
    object = object.parent;
  }
  return object! as RenderNibMotion;
}

Widget _col(List<String> ids, {NibLayoutChannelMode? mode}) => _wrap(
      NibLayoutScope(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final id in ids)
              NibMotion(
                key: ValueKey(id),
                layout: NibLayout.position,
                layoutChannelMode: mode ?? NibLayoutChannelMode.channels,
                child: const SizedBox(width: 50, height: 50),
              ),
          ],
        ),
      ),
    );

void main() {
  group('NibLayoutChannelMode.translate', () {
    testWidgets('the FLIP lives in the widget\'s own translate values',
        (tester) async {
      await tester
          .pumpWidget(_col(['a', 'b'], mode: NibLayoutChannelMode.translate));
      await tester.pumpAndSettle();
      await tester
          .pumpWidget(_col(['b', 'a'], mode: NibLayoutChannelMode.translate));
      await tester.pump();

      final a = _renderFor(tester, const ValueKey('a'));
      expect(a.translateY.value, lessThan(-1.0),
          reason: 'inverted into translateY');
      expect(a.layoutChannels!.y.value, 0.0,
          reason: 'separate channels stay untouched in translate mode');
      await tester.pumpAndSettle();
      expect(a.translateY.value, closeTo(0.0, 0.5));
    });

    testWidgets('default mode keeps using separate channels', (tester) async {
      await tester.pumpWidget(_col(['a', 'b']));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_col(['b', 'a']));
      await tester.pump();
      final a = _renderFor(tester, const ValueKey('a'));
      expect(a.translateY.value, 0.0);
      expect(a.layoutChannels!.y.value, lessThan(-1.0));
      await tester.pumpAndSettle();
    });

    testWidgets('painted position is continuous in translate mode',
        (tester) async {
      Offset painted(String id) {
        final box = tester.renderObject<RenderBox>(find.byKey(ValueKey(id)));
        return (box as RenderNibMotion).child!.localToGlobal(Offset.zero);
      }

      await tester
          .pumpWidget(_col(['a', 'b'], mode: NibLayoutChannelMode.translate));
      await tester.pumpAndSettle();
      await tester
          .pumpWidget(_col(['b', 'a'], mode: NibLayoutChannelMode.translate));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final mid = painted('a').dy;
      expect(mid, inExclusiveRange(1, 49));
      await tester
          .pumpWidget(_col(['a', 'b'], mode: NibLayoutChannelMode.translate));
      await tester.pump();
      await tester.pump();
      expect(painted('a').dy, closeTo(mid, 0.75));
      await tester.pumpAndSettle();
    });
  });

  group('NibLayoutGroup is built on the per-widget mechanism', () {
    testWidgets(
        'its children are layout-animated NibMotions without a '
        'controller', (tester) async {
      await tester.pumpWidget(_wrap(const NibLayoutGroup(children: [
        SizedBox(key: ValueKey('a'), width: 50, height: 50),
        SizedBox(key: ValueKey('b'), width: 50, height: 50),
      ])));
      final motions = tester.widgetList<NibMotion>(find.byType(NibMotion));
      expect(motions, hasLength(2));
      for (final m in motions) {
        expect(m.layout, NibLayout.position);
        expect(m.layoutChannelMode, NibLayoutChannelMode.translate);
        expect(m.controller, isNull);
      }
    });
  });
}

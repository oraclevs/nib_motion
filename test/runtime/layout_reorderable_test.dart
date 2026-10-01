import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _tile(String id, {double size = 50}) => SizedBox(
      key: ValueKey(id),
      width: size,
      height: size,
    );

class _Host extends StatefulWidget {
  const _Host({
    required this.ids,
    this.axis = Axis.vertical,
    this.apply = true,
    this.log,
    this.decorator,
  });
  final List<String> ids;
  final Axis axis;
  final bool apply;
  final List<(int, int)>? log;
  final NibReorderDecorator? decorator;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late List<String> ids = [...widget.ids];

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: NibReorderable(
            axis: widget.axis,
            dragDecorator: widget.decorator,
            onReorder: (o, n) {
              widget.log?.add((o, n));
              if (widget.apply) {
                setState(() => ids.insert(n, ids.removeAt(o)));
              }
            },
            children: [for (final id in ids) _tile(id)],
          ),
        ),
      );
}

Offset _origin(WidgetTester tester, String id) => tester
    .renderObject<RenderBox>(find.byKey(ValueKey(id)))
    .localToGlobal(Offset.zero);

Future<TestGesture> _grab(WidgetTester tester, Offset at) async {
  final g = await tester.startGesture(at);
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  return g;
}

void main() {
  group('NibReorderable', () {
    testWidgets('dragging an item follows the pointer and siblings make way',
        (tester) async {
      final log = <(int, int)>[];
      await tester.pumpWidget(_Host(ids: const ['a', 'b', 'c'], log: log));
      await tester.pumpAndSettle();
      final g = await _grab(tester, const Offset(25, 25)); // tile a
      await g.moveBy(const Offset(0, 40));
      await tester.pump();
      // a follows the finger 1:1 (grab offset preserved).
      expect(_origin(tester, 'a').dy, closeTo(40, 0.5));
      // a's centre (65) passed b's centre (75)? not yet.
      await g.moveBy(const Offset(0, 20)); // a centre now 85 > b centre 75
      await tester.pump();
      expect(_origin(tester, 'a').dy, closeTo(60, 0.5));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 60));
      // b is gliding up into slot 0.
      expect(_origin(tester, 'b').dy, lessThan(50));
      expect(_origin(tester, 'b').dy, greaterThan(0));
      await g.up();
      await tester.pumpAndSettle();
      expect(log, [(0, 1)]);
      expect(_origin(tester, 'b').dy, closeTo(0, 0.01));
      expect(_origin(tester, 'a').dy, closeTo(50, 0.01));
      expect(_origin(tester, 'c').dy, closeTo(100, 0.01));
    });

    testWidgets('dragging to the end reports the final index', (tester) async {
      final log = <(int, int)>[];
      await tester.pumpWidget(_Host(ids: const ['a', 'b', 'c'], log: log));
      await tester.pumpAndSettle();
      final g = await _grab(tester, const Offset(25, 25));
      for (var i = 0; i < 6; i++) {
        await g.moveBy(const Offset(0, 30));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pumpAndSettle();
      expect(log, [(0, 2)]);
      expect(_origin(tester, 'a').dy, closeTo(100, 0.01));
    });

    testWidgets('dragging up works too', (tester) async {
      final log = <(int, int)>[];
      await tester.pumpWidget(_Host(ids: const ['a', 'b', 'c'], log: log));
      await tester.pumpAndSettle();
      final g = await _grab(tester, const Offset(25, 125)); // tile c
      for (var i = 0; i < 6; i++) {
        await g.moveBy(const Offset(0, -30));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pumpAndSettle();
      expect(log, [(2, 0)]);
      expect(_origin(tester, 'c').dy, closeTo(0, 0.01));
    });

    testWidgets('a small drag that changes nothing does not call onReorder',
        (tester) async {
      final log = <(int, int)>[];
      await tester.pumpWidget(_Host(ids: const ['a', 'b'], log: log));
      await tester.pumpAndSettle();
      final g = await _grab(tester, const Offset(25, 25));
      await g.moveBy(const Offset(0, 10));
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();
      expect(log, isEmpty);
      expect(_origin(tester, 'a').dy, closeTo(0, 0.01));
    });

    testWidgets('a parent that ignores onReorder gets the items animated back',
        (tester) async {
      final log = <(int, int)>[];
      await tester
          .pumpWidget(_Host(ids: const ['a', 'b'], apply: false, log: log));
      await tester.pumpAndSettle();
      final g = await _grab(tester, const Offset(25, 25));
      for (var i = 0; i < 4; i++) {
        await g.moveBy(const Offset(0, 30));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pumpAndSettle();
      expect(log, [(0, 1)]);
      expect(_origin(tester, 'a').dy, closeTo(0, 0.01));
      expect(_origin(tester, 'b').dy, closeTo(50, 0.01));
    });

    testWidgets('horizontal axis', (tester) async {
      final log = <(int, int)>[];
      await tester.pumpWidget(
          _Host(ids: const ['a', 'b', 'c'], axis: Axis.horizontal, log: log));
      await tester.pumpAndSettle();
      final g = await _grab(tester, const Offset(25, 25));
      for (var i = 0; i < 6; i++) {
        await g.moveBy(const Offset(30, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pumpAndSettle();
      expect(log, [(0, 2)]);
      expect(_origin(tester, 'a').dx, closeTo(100, 0.01));
    });

    testWidgets('dragDecorator sees the dragging state', (tester) async {
      final states = <bool>[];
      await tester.pumpWidget(_Host(
        ids: const ['a', 'b'],
        decorator: (context, child, dragging) {
          if (child.key == const ValueKey('a')) states.add(dragging);
          return child;
        },
      ));
      await tester.pumpAndSettle();
      final g = await _grab(tester, const Offset(25, 25));
      await g.moveBy(const Offset(0, 5));
      await tester.pump();
      expect(states.last, isTrue);
      await g.up();
      await tester.pumpAndSettle();
      expect(states.last, isFalse);
    });

    testWidgets('disposing mid-drag is safe', (tester) async {
      await tester.pumpWidget(_Host(ids: const ['a', 'b', 'c']));
      await tester.pumpAndSettle();
      final g = await _grab(tester, const Offset(25, 25));
      await g.moveBy(const Offset(0, 60));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await g.up();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  });
}

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _tile(String id, {double size = 50}) =>
    SizedBox(key: ValueKey(id), width: size, height: size);

class _Host extends StatefulWidget {
  const _Host({
    required this.ids,
    this.axis = Axis.vertical,
    this.spacing = 0,
    this.controller,
    this.log,
  });
  final List<String> ids;
  final Axis axis;
  final double spacing;
  final ScrollController? controller;
  final List<(int, int)>? log;
  static const double viewport = 200;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late List<String> ids = [...widget.ids];

  @override
  Widget build(BuildContext context) {
    final list = NibReorderable(
      axis: widget.axis,
      spacing: widget.spacing,
      onReorder: (o, n) {
        widget.log?.add((o, n));
        setState(() => ids.insert(n, ids.removeAt(o)));
      },
      children: [for (final id in ids) _tile(id)],
    );
    final horizontal = widget.axis == Axis.horizontal;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: widget.controller == null
            ? list
            : SizedBox(
                width: horizontal ? _Host.viewport : 60,
                height: horizontal ? 60 : _Host.viewport,
                child: SingleChildScrollView(
                  controller: widget.controller,
                  scrollDirection: widget.axis,
                  child: list,
                ),
              ),
      ),
    );
  }
}

Offset _painted(WidgetTester tester, String id) => tester
    .renderObject<RenderBox>(find.byKey(ValueKey(id)))
    .localToGlobal(Offset.zero);

void main() {
  group('NibReorderable spacing', () {
    testWidgets('spaces items along the axis', (tester) async {
      await tester.pumpWidget(const _Host(ids: ['a', 'b', 'c'], spacing: 10));
      expect(_painted(tester, 'a').dy, 0);
      expect(_painted(tester, 'b').dy, 60);
      expect(_painted(tester, 'c').dy, 120);
    });

    testWidgets('horizontal spacing', (tester) async {
      await tester.pumpWidget(
          const _Host(ids: ['a', 'b', 'c'], spacing: 8, axis: Axis.horizontal));
      expect(_painted(tester, 'b').dx, 58);
      expect(_painted(tester, 'c').dx, 116);
    });

    testWidgets('reordering still works with spacing', (tester) async {
      final log = <(int, int)>[];
      await tester
          .pumpWidget(_Host(ids: const ['a', 'b', 'c'], spacing: 10, log: log));
      final g = await tester.startGesture(const Offset(25, 25));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await g.moveBy(const Offset(0, 70));
      await tester.pump();
      await g.moveBy(const Offset(0, 0));
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();
      expect(log, [(0, 1)]);
      expect(_painted(tester, 'b').dy, 0);
      expect(_painted(tester, 'a').dy, 60);
    });
  });

  group('NibReorderable auto-scroll', () {
    testWidgets('dragging near the bottom edge scrolls a vertical list',
        (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_Host(
          ids: [for (var i = 0; i < 10; i++) 'i$i'], controller: controller));
      final g = await tester.startGesture(const Offset(25, 25));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await g.moveTo(const Offset(25, 190)); // 10px from the bottom edge
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(controller.offset, greaterThan(30));
      await g.up();
      await tester.pumpAndSettle();
    });

    testWidgets('dragging near the top edge scrolls back up', (tester) async {
      final controller = ScrollController(initialScrollOffset: 200);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_Host(
          ids: [for (var i = 0; i < 10; i++) 'i$i'], controller: controller));
      final g = await tester.startGesture(const Offset(25, 100));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await g.moveTo(const Offset(25, 8));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(controller.offset, lessThan(170));
      await g.up();
      await tester.pumpAndSettle();
    });

    testWidgets('horizontal lists auto-scroll too', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_Host(
          ids: [for (var i = 0; i < 10; i++) 'i$i'],
          axis: Axis.horizontal,
          controller: controller));
      final g = await tester.startGesture(const Offset(25, 25));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await g.moveTo(const Offset(190, 25));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(controller.offset, greaterThan(30));
      await g.up();
      await tester.pumpAndSettle();
    });

    testWidgets('no scrolling when the pointer stays mid-viewport',
        (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_Host(
          ids: [for (var i = 0; i < 10; i++) 'i$i'], controller: controller));
      final g = await tester.startGesture(const Offset(25, 25));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await g.moveTo(const Offset(25, 100));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(controller.offset, 0);
      await g.up();
      await tester.pumpAndSettle();
    });

    testWidgets('the auto-scroll ticker stops when the drag ends',
        (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_Host(
          ids: [for (var i = 0; i < 10; i++) 'i$i'], controller: controller));
      final g = await tester.startGesture(const Offset(25, 25));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await g.moveTo(const Offset(25, 190));
      await tester.pump(const Duration(milliseconds: 100));
      await g.up();
      await tester.pumpAndSettle(); // would time out if a ticker kept running
      final at = controller.offset;
      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.offset, at);
    });
  });
}

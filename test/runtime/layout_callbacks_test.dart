import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _wrap(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: child),
    );

Widget _pItem(String id, {bool layout = true}) => NibMotion(
      key: ValueKey(id),
      layout: layout ? NibLayout.position : NibLayout.none,
      exit: const NibAnim(opacity: 0),
      transition: const NibTransition(duration: Duration(milliseconds: 100)),
      child: const SizedBox(width: 50, height: 50),
    );

String _k(Key k) => (k as ValueKey).value as String;

void main() {
  group('NibPresence lifecycle callbacks', () {
    Widget host(List<String> ids, List<String> log,
            {NibExitLayout exitLayout = NibExitLayout.pop}) =>
        _wrap(NibLayoutScope(
          child: NibPresence(
            exitLayout: exitLayout,
            layoutBuilder: (context, children) => Column(children: children),
            onChildEnter: (k) => log.add('enter:${_k(k)}'),
            onChildExit: (k) => log.add('exit:${_k(k)}'),
            onChildMove: (k) => log.add('move:${_k(k)}'),
            onAnimationStart: () => log.add('start'),
            onAnimationComplete: () => log.add('complete'),
            children: [for (final id in ids) _pItem(id)],
          ),
        ));

    testWidgets('initial children are not reported as entering',
        (tester) async {
      final log = <String>[];
      await tester.pumpWidget(host(['a', 'b'], log));
      await tester.pumpAndSettle();
      expect(log, isEmpty);
    });

    testWidgets('onChildEnter fires for children added later', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(host(['a'], log));
      await tester.pumpWidget(host(['a', 'b'], log));
      await tester.pumpAndSettle();
      expect(log, contains('enter:b'));
      expect(log.where((e) => e == 'enter:b'), hasLength(1));
      expect(log, isNot(contains('enter:a')));
    });

    testWidgets('onChildExit fires after the exit animation, not before',
        (tester) async {
      final log = <String>[];
      await tester.pumpWidget(host(['a', 'b'], log));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(['b'], log));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(log, isNot(contains('exit:a')), reason: 'still fading out');
      await tester.pumpAndSettle();
      expect(log, contains('exit:a'));
      expect(find.byKey(const ValueKey('a')), findsNothing);
    });

    testWidgets('onChildMove fires for siblings that reflow', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(host(['a', 'b', 'c'], log));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(['b', 'c'], log));
      await tester.pumpAndSettle();
      expect(log, containsAll(<String>['move:b', 'move:c']));
      expect(log, isNot(contains('move:a')));
    });

    testWidgets('aggregated start/complete fire once around all animations',
        (tester) async {
      final log = <String>[];
      await tester.pumpWidget(host(['a', 'b', 'c'], log));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(['b', 'c'], log));
      await tester.pumpAndSettle();
      expect(log.where((e) => e == 'start'), hasLength(1), reason: '$log');
      expect(log.where((e) => e == 'complete'), hasLength(1), reason: '$log');
      expect(log.indexOf('start'), lessThan(log.indexOf('complete')));
      expect(log.indexOf('complete'), greaterThan(log.indexOf('exit:a')));
      expect(log.indexOf('complete'), greaterThan(log.indexOf('move:c')));
    });

    testWidgets('a superseded move does not leave the aggregate hanging',
        (tester) async {
      final log = <String>[];
      await tester.pumpWidget(host(['a', 'b', 'c'], log));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(['c', 'b', 'a'], log));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pumpWidget(host(['a', 'b', 'c'], log)); // interrupt
      await tester.pumpAndSettle();
      final starts = log.where((e) => e == 'start').length;
      final completes = log.where((e) => e == 'complete').length;
      expect(starts, greaterThan(0));
      expect(completes, starts, reason: 'every start is matched: $log');
    });
  });

  group('NibLayoutGroup callbacks', () {
    Widget host(List<String> ids, List<String> log) => _wrap(NibLayoutGroup(
          onChildEnter: (k) => log.add('enter:${_k(k)}'),
          onChildExit: (k) => log.add('exit:${_k(k)}'),
          onChildMove: (k) => log.add('move:${_k(k)}'),
          onAnimationStart: () => log.add('start'),
          onAnimationComplete: () => log.add('complete'),
          children: [
            for (final id in ids)
              SizedBox(key: ValueKey(id), width: 50, height: 50),
          ],
        ));

    testWidgets('enter, exit and move are reported', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(host(['a', 'b'], log));
      await tester.pumpAndSettle();
      expect(log, isEmpty);

      await tester.pumpWidget(host(['b', 'a'], log));
      await tester.pumpAndSettle();
      expect(log, containsAll(<String>['move:a', 'move:b']));

      log.clear();
      await tester.pumpWidget(host(['b', 'a', 'c'], log));
      await tester.pumpAndSettle();
      expect(log, contains('enter:c'));

      log.clear();
      await tester.pumpWidget(host(['b', 'c'], log));
      await tester.pumpAndSettle();
      expect(log, contains('exit:a'));
    });

    testWidgets('aggregated start/complete fire once per batch',
        (tester) async {
      final log = <String>[];
      await tester.pumpWidget(host(['a', 'b'], log));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(['b', 'a'], log));
      await tester.pumpAndSettle();
      expect(log.where((e) => e == 'start'), hasLength(1), reason: '$log');
      expect(log.where((e) => e == 'complete'), hasLength(1), reason: '$log');
    });
  });

  group('NibPageProgress.tab', () {
    testWidgets('follows a TabController animation fractionally',
        (tester) async {
      final tab = TabController(length: 3, vsync: const TestVSync());
      addTearDown(tab.dispose);
      final progress = NibPageProgress.tab(tab);
      addTearDown(progress.dispose);
      expect(progress.page.value, 0);

      tab.animateTo(2, duration: const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(progress.page.value, inExclusiveRange(0.0, 2.0));
      await tester.pumpAndSettle();
      expect(progress.page.value, 2);
      expect(progress.closeness(2).value, 1);
    });

    testWidgets('follows a swipe (index offset) too', (tester) async {
      final tab = TabController(length: 3, vsync: const TestVSync());
      addTearDown(tab.dispose);
      final progress = NibPageProgress.tab(tab);
      addTearDown(progress.dispose);
      tab.offset = 0.5; // half way toward the next tab, as a swipe does
      expect(progress.page.value, closeTo(0.5, 1e-9));
    });
  });
}

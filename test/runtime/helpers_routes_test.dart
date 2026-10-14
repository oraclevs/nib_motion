import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

final _navKey = GlobalKey<NavigatorState>();

Widget _host({bool reduced = false}) => Directionality(
      textDirection: TextDirection.ltr,
      child: NibMotionConfig(
        reducedMotion: reduced,
        child: Navigator(
          key: _navKey,
          onGenerateRoute: (settings) => PageRouteBuilder<void>(
            settings: settings,
            pageBuilder: (_, __, ___) => const Text('home'),
          ),
        ),
      ),
    );

RenderNibMotion? _motionUnder(WidgetTester tester, Finder finder) {
  RenderNibMotion? found;
  final element = finder.evaluate().single;
  element.visitAncestorElements((e) {
    if (e.renderObject is RenderNibMotion) {
      found = e.renderObject! as RenderNibMotion;
      return false;
    }
    return true;
  });
  return found;
}

void main() {
  group('showNibDialog', () {
    testWidgets('pushes, animates in, returns a result on pop', (tester) async {
      await tester.pumpWidget(_host());
      final result = showNibDialog<int>(
        context: _navKey.currentContext!,
        builder: (_) =>
            const SizedBox(width: 100, height: 60, key: ValueKey('d')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 50));
      final mid = _motionUnder(tester, find.byKey(const ValueKey('d')))!;
      expect(mid.opacity.value, inExclusiveRange(0.0, 1.0));

      await tester.pumpAndSettle();
      expect(mid.opacity.value, 1.0);
      expect(mid.scaleX.value, closeTo(1.0, 1e-6));

      _navKey.currentState!.pop(42);
      await tester.pumpAndSettle();
      expect(await result, 42);
      expect(find.byKey(const ValueKey('d')), findsNothing);
    });

    testWidgets('barrier tap dismisses when barrierDismissible',
        (tester) async {
      await tester.pumpWidget(_host());
      final result = showNibDialog<int>(
        context: _navKey.currentContext!,
        builder: (_) =>
            const SizedBox(width: 50, height: 50, key: ValueKey('d')),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(await result, isNull);
      expect(find.byKey(const ValueKey('d')), findsNothing);
    });

    testWidgets('barrier tap does nothing when not dismissible',
        (tester) async {
      await tester.pumpWidget(_host());
      showNibDialog<void>(
        context: _navKey.currentContext!,
        barrierDismissible: false,
        builder: (_) =>
            const SizedBox(width: 50, height: 50, key: ValueKey('d')),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('d')), findsOneWidget);
    });

    testWidgets('rapid push/pop leaves a clean navigator', (tester) async {
      await tester.pumpWidget(_host());
      for (var i = 0; i < 12; i++) {
        showNibDialog<void>(
          context: _navKey.currentContext!,
          builder: (_) => SizedBox(width: 30, height: 30, key: ValueKey('d$i')),
        );
        await tester.pump(Duration(milliseconds: 10 + (i % 4) * 25));
        _navKey.currentState!.pop();
        await tester.pump(Duration(milliseconds: 15));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
          find.byType(SizedBox).evaluate().where((e) =>
              (e.widget.key as ValueKey?)?.value.toString().startsWith('d') ??
              false),
          isEmpty);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('reduced motion: content is at rest immediately, exit instant',
        (tester) async {
      await tester.pumpWidget(_host(reduced: true));
      showNibDialog<void>(
        context: _navKey.currentContext!,
        builder: (_) =>
            const SizedBox(width: 50, height: 50, key: ValueKey('d')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final motion = _motionUnder(tester, find.byKey(const ValueKey('d')))!;
      expect(motion.opacity.value, 1.0);
      expect(motion.scaleX.value, 1.0);
      _navKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('d')), findsNothing);
    });

    testWidgets('custom initial/animate/exit and transition are honoured',
        (tester) async {
      await tester.pumpWidget(_host());
      showNibDialog<void>(
        context: _navKey.currentContext!,
        initial: const NibAnim(y: 80, opacity: 0),
        animate: const NibAnim(y: 0, opacity: 1),
        exit: const NibAnim(y: -80, opacity: 0),
        transition: const NibTransition(duration: Duration(milliseconds: 100)),
        builder: (_) =>
            const SizedBox(width: 50, height: 50, key: ValueKey('d')),
      );
      await tester.pumpAndSettle();
      final motion = _motionUnder(tester, find.byKey(const ValueKey('d')))!;
      expect(motion.translateY.value, 0);
      _navKey.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(motion.translateY.value, lessThan(0), reason: 'exits upward');
      await tester.pumpAndSettle();
    });
  });

  group('interruption', () {
    testWidgets('a pop during the enter spring continues from where it was',
        (tester) async {
      await tester.pumpWidget(_host());
      showNibDialog<void>(
        context: _navKey.currentContext!,
        builder: (_) =>
            const SizedBox(width: 50, height: 50, key: ValueKey('d')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 60));
      final motion = _motionUnder(tester, find.byKey(const ValueKey('d')))!;
      final before = motion.opacity.value;
      expect(before, inExclusiveRange(0.05, 0.95));
      _navKey.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect((motion.opacity.value - before).abs(), lessThan(0.35),
          reason: 'no jump to fully visible or fully hidden');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('d')), findsNothing);
    });
  });

  group('NibPageRoute', () {
    testWidgets('pushes a full page that animates in and pops with a result',
        (tester) async {
      await tester.pumpWidget(_host());
      final result = _navKey.currentState!.push<String>(NibPageRoute<String>(
        builder: (_) =>
            const SizedBox(key: ValueKey('p'), width: 200, height: 200),
      ));
      await tester.pumpAndSettle();
      final motion = _motionUnder(tester, find.byKey(const ValueKey('p')))!;
      expect(motion.opacity.value, 1.0);
      expect(motion.translateY.value, closeTo(0, 1e-6));
      _navKey.currentState!.pop('done');
      await tester.pumpAndSettle();
      expect(await result, 'done');
      expect(find.byKey(const ValueKey('p')), findsNothing);
    });
  });
}

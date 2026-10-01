import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

const _child = SizedBox(key: ValueKey('child'), width: 40, height: 40);

Widget _host(
  bool visible, {
  bool reduced = false,
  Duration enterDelay = Duration.zero,
  Duration exitDelay = Duration.zero,
  NibTransition? transition,
}) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: NibMotionConfig(
        reducedMotion: reduced,
        entranceWarmup: Duration.zero,
        child: Align(
          alignment: Alignment.topLeft,
          child: NibVisibility(
            visible: visible,
            enterDelay: enterDelay,
            exitDelay: exitDelay,
            transition: transition ??
                const NibTransition(duration: Duration(milliseconds: 300)),
            child: _child,
          ),
        ),
      ),
    );

double _opacity(WidgetTester tester) {
  final element = tester.element(find.byKey(const ValueKey('child')));
  RenderObject? o = element.renderObject;
  while (o != null && o is! RenderNibMotion) {
    o = o.parent;
  }
  return (o! as RenderNibMotion).opacity.value;
}

void main() {
  testWidgets('hidden at first: nothing is built', (tester) async {
    await tester.pumpWidget(_host(false));
    expect(find.byKey(const ValueKey('child')), findsNothing);
  });

  testWidgets('showing animates in; hiding retains the child until exit ends',
      (tester) async {
    await tester.pumpWidget(_host(false));
    await tester.pumpWidget(_host(true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(_opacity(tester), inExclusiveRange(0.05, 0.95), reason: 'entering');
    await tester.pumpAndSettle();
    expect(_opacity(tester), 1);

    await tester.pumpWidget(_host(false));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byKey(const ValueKey('child')), findsOneWidget,
        reason: 'retained while fading out');
    expect(_opacity(tester), inExclusiveRange(0.05, 0.95));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('child')), findsNothing);
  });

  testWidgets('exiting child ignores pointers, semantics and focus',
      (tester) async {
    await tester.pumpWidget(_host(true));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_host(false));
    await tester.pump(const Duration(milliseconds: 100));
    final ancestors = find.ancestor(
        of: find.byKey(const ValueKey('child')),
        matching: find.byType(IgnorePointer));
    expect(tester.widgetList<IgnorePointer>(ancestors).any((w) => w.ignoring),
        isTrue);
    expect(
        tester
            .widgetList<ExcludeSemantics>(find.ancestor(
                of: find.byKey(const ValueKey('child')),
                matching: find.byType(ExcludeSemantics)))
            .any((w) => w.excluding),
        isTrue);
    expect(
        tester
            .widgetList<ExcludeFocus>(find.ancestor(
                of: find.byKey(const ValueKey('child')),
                matching: find.byType(ExcludeFocus)))
            .any((w) => w.excluding),
        isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('showing again mid-exit cancels the removal', (tester) async {
    await tester.pumpWidget(_host(true));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_host(false));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpWidget(_host(true));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('child')), findsOneWidget);
    expect(_opacity(tester), 1);
  });

  testWidgets('reduced motion removes immediately', (tester) async {
    await tester.pumpWidget(_host(true, reduced: true));
    await tester.pump();
    expect(_opacity(tester), 1);
    await tester.pumpWidget(_host(false, reduced: true));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('child')), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('exitDelay holds the child fully visible first', (tester) async {
    // Exit params are those of the widget built while visible.
    const delay = Duration(milliseconds: 400);
    await tester.pumpWidget(_host(true, exitDelay: delay));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_host(false, exitDelay: delay));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_opacity(tester), 1, reason: 'still waiting out the delay');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('child')), findsNothing);
  });

  testWidgets('enterDelay holds the child invisible first', (tester) async {
    await tester.pumpWidget(_host(false));
    await tester
        .pumpWidget(_host(true, enterDelay: const Duration(milliseconds: 400)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(_opacity(tester), 0, reason: 'still waiting out the delay');
    await tester.pump(const Duration(milliseconds: 300)); // delay elapses
    await tester.pumpAndSettle();
    expect(_opacity(tester), 1);
  });

  testWidgets('rapid toggling ends in the requested state', (tester) async {
    var visible = false;
    await tester.pumpWidget(_host(visible));
    for (var i = 0; i < 40; i++) {
      visible = !visible;
      await tester.pumpWidget(_host(visible));
      await tester.pump(Duration(milliseconds: 10 + (i % 4) * 40));
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('child')),
        visible ? findsOneWidget : findsNothing);
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('rows are live and show velocity', (tester) async {
    final v = MotionValue<double>(1);
    NibMotionRegistry.instance.register('demo.live', v);
    addTearDown(() => NibMotionRegistry.instance.unregister('demo.live'));
    await tester.pumpWidget(_host(const NibMotionDebugger(
      enabled: true,
      showFps: false,
      child: SizedBox.expand(),
    )));
    expect(find.textContaining('demo.live: 1.0'), findsOneWidget);
    expect(find.textContaining('v='), findsNothing,
        reason: 'no velocity shown at rest');

    v.update(5, velocity: 120);
    await tester.pump();
    expect(find.textContaining('demo.live: 5.0'), findsOneWidget);
    expect(find.textContaining('v=120.0/s'), findsOneWidget);

    v.value = 6; // jump: velocity resets
    await tester.pump();
    expect(find.textContaining('demo.live: 6.0'), findsOneWidget);
    expect(find.textContaining('v='), findsNothing);
  });

  testWidgets('reduced-motion toggle sets and clears the global override',
      (tester) async {
    addTearDown(() => NibMotionConfig.setReducedMotion(null));
    final controller = NibMotionController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(NibMotionDebugger(
      enabled: true,
      showFps: false,
      showMotionValues: false,
      child: SizedBox.expand(
        child: NibMotion(
          controller: controller,
          child: const SizedBox(width: 10, height: 10),
        ),
      ),
    )));
    RenderNibMotion? render;
    void visit(RenderObject o) {
      if (o is RenderNibMotion) render = o;
      o.visitChildren(visit);
    }

    tester.binding.rootElement!.renderObject!.visitChildren(visit);

    await tester.tap(find.byKey(const ValueKey('nib_debugger_reduced_motion')));
    await tester.pump();
    expect(find.byIcon(Icons.check_box), findsOneWidget,
        reason: 'checkbox toggled');
    controller.start(target: const NibAnim(x: 100));
    await tester.pump();
    expect(render!.translateX.value, 100, reason: 'jumped: reduced motion on');

    await tester.tap(find.byKey(const ValueKey('nib_debugger_reduced_motion')));
    await tester.pump();
    controller.start(target: const NibAnim(x: 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(render!.translateX.value, inExclusiveRange(0.1, 99.9),
        reason: 'animating again with the override cleared');
    await tester.pumpAndSettle();
  });

  testWidgets('removing the debugger clears a forced override', (tester) async {
    addTearDown(() => NibMotionConfig.setReducedMotion(null));
    final controller = NibMotionController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(const NibMotionDebugger(
        enabled: true,
        showFps: false,
        showMotionValues: false,
        child: SizedBox())));
    await tester.tap(find.byKey(const ValueKey('nib_debugger_reduced_motion')));
    await tester.pump();
    await tester.pumpWidget(_host(NibMotion(
      controller: controller,
      child: const SizedBox(width: 10, height: 10),
    )));
    controller.start(target: const NibAnim(x: 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    RenderNibMotion? render;
    void visit(RenderObject o) {
      if (o is RenderNibMotion) render = o;
      o.visitChildren(visit);
    }

    tester.binding.rootElement!.renderObject!.visitChildren(visit);
    expect(render!.translateX.value, lessThan(100),
        reason: 'override was cleared when the debugger unmounted');
    await tester.pumpAndSettle();
  });

  testWidgets('toggle can be hidden', (tester) async {
    await tester.pumpWidget(_host(const NibMotionDebugger(
      enabled: true,
      showFps: false,
      showReducedMotionToggle: false,
      child: SizedBox(),
    )));
    expect(find.byKey(const ValueKey('nib_debugger_reduced_motion')),
        findsNothing);
  });
}

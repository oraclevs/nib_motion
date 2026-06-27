import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/src/debug/motion_value_inspector.dart';
import 'package:nib_motion/src/debug/nib_motion_debugger.dart';
import 'package:nib_motion/src/values/motion_value.dart';

void main() {
  tearDown(() {
    for (final id in NibMotionRegistry.instance.values.keys.toList()) {
      NibMotionRegistry.instance.unregister(id);
    }
  });

  group('NibMotionDebugger', () {
    testWidgets(
      'enabled: false is a no-op passthrough — no Stack is inserted',
      (WidgetTester tester) async {
        const childKey = ValueKey('debugger-child');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NibMotionDebugger(
                enabled: false,
                child: const SizedBox(key: childKey),
              ),
            ),
          ),
        );

        // The child is present...
        expect(find.byKey(childKey), findsOneWidget);
        // ...and no debug panel/overlay was added.
        expect(
          find.byKey(const ValueKey('nib_motion_debugger_panel')),
          findsNothing,
        );
        // NibMotionDebugger itself must not have inserted a Stack: since
        // build() returns `child` directly when disabled, the
        // NibMotionDebugger element should have exactly one child in the
        // tree (the SizedBox), with no Stack in between. We verify this by
        // confirming the SizedBox is a direct child of NibMotionDebugger's
        // own element, i.e. NibMotionDebugger contributes no widget of its
        // own to the tree besides `child`.
        final debuggerElement = tester.element(find.byType(NibMotionDebugger));
        Element? builtChild;
        debuggerElement.visitChildren((element) => builtChild = element);
        expect(builtChild?.widget.key, childKey);
      },
    );

    testWidgets('enabled: true shows the debug overlay panel', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NibMotionDebugger(
              enabled: true,
              child: SizedBox(key: ValueKey('debugger-child')),
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('debugger-child')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('nib_motion_debugger_panel')),
        findsOneWidget,
      );
      expect(find.text('NibMotionDebugger'), findsOneWidget);
      expect(find.byType(Stack), findsWidgets);
    });

    testWidgets('enabled: true does not throw across several frames', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NibMotionDebugger(child: SizedBox()),
          ),
        ),
      );

      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('showMotionValues lists registered MotionValues', (
      WidgetTester tester,
    ) async {
      final value = MotionValue<double>(0.42);
      NibMotionRegistry.instance.register('demo.opacity', value);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NibMotionDebugger(
              enabled: true,
              showMotionValues: true,
              child: SizedBox(),
            ),
          ),
        ),
      );

      expect(find.textContaining('demo.opacity'), findsOneWidget);
    });

    testWidgets('showMotionValues: false hides the MotionValue list', (
      WidgetTester tester,
    ) async {
      NibMotionRegistry.instance.register(
        'demo.hidden',
        MotionValue<double>(1.0),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NibMotionDebugger(
              enabled: true,
              showMotionValues: false,
              child: SizedBox(),
            ),
          ),
        ),
      );

      expect(find.textContaining('demo.hidden'), findsNothing);
    });

    testWidgets('MotionValues list is height-capped and scrollable when it has many entries', (
      WidgetTester tester,
    ) async {
      // One NibMotion alone contributes 11 entries; a real app easily
      // registers dozens. Without a height cap + scroll, this list would
      // grow unbounded and run off the bottom of the screen.
      for (var i = 0; i < 40; i++) {
        NibMotionRegistry.instance.register('demo.value$i', MotionValue<double>(i.toDouble()));
      }

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NibMotionDebugger(
              enabled: true,
              showMotionValues: true,
              child: SizedBox(),
            ),
          ),
        ),
      );

      expect(find.byType(SingleChildScrollView), findsOneWidget);

      final scrollView = tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
      final constrainedBox = tester.widget<ConstrainedBox>(
        find.ancestor(of: find.byWidget(scrollView), matching: find.byType(ConstrainedBox)).first,
      );
      expect(constrainedBox.constraints.maxHeight, lessThan(300));

      // The panel itself must stay within that cap (plus title/FPS/padding)
      // rather than growing with the number of registered values.
      final panelHeight = tester.getSize(find.byKey(const ValueKey('nib_motion_debugger_panel'))).height;
      expect(panelHeight, lessThan(400));

      expect(tester.takeException(), isNull);
    });

    testWidgets('showFps: false hides the FPS overlay', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NibMotionDebugger(
              enabled: true,
              showFps: false,
              child: SizedBox(),
            ),
          ),
        ),
      );

      expect(find.textContaining('FPS:'), findsNothing);
    });
  });
}

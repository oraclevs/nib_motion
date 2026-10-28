import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _host({
  bool flipped = false,
  bool enabled = true,
  Duration duration = const Duration(milliseconds: 600),
  Widget front = const Text('Front face'),
  Widget back = const Text('Back face'),
}) =>
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: TickerMode(
            enabled: enabled,
            child: NibFlip(
              isFlipped: flipped,
              duration: duration,
              front: SizedBox(width: 160, height: 160, child: front),
              back: SizedBox(width: 160, height: 160, child: back),
            ),
          ),
        ),
      ),
    );

// Read the progress used by the actual painter without adding a public API.
double _progress(WidgetTester tester) {
  final face = find
      .byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_NibFlipFace',
      )
      .first;
  final dynamic renderFace = tester.renderObject(face);
  return (renderFace.progress as MotionValue<double>).value;
}

bool _hasSemanticsLabel(String label) {
  bool visit(SemanticsNode node) {
    var found = node.label == label;
    node.visitChildren((child) {
      if (visit(child)) found = true;
      return true;
    });
    return found;
  }

  return visit(RendererBinding
      .instance.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
}

void main() {
  testWidgets('TickerMode pauses painted progress without counting hidden time',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpWidget(_host(flipped: true));
    await tester.pump(const Duration(milliseconds: 180));
    final paused = _progress(tester);
    expect(paused, closeTo(Curves.easeInOut.transform(.3), 1e-6));

    await tester.pumpWidget(_host(flipped: true, enabled: false));
    await tester.pump(const Duration(seconds: 5));
    expect(_progress(tester), paused);
    await tester.pumpWidget(_host(flipped: true));
    expect(_progress(tester), paused);
    await tester.pump(const Duration(milliseconds: 60));
    expect(_progress(tester), closeTo(Curves.easeInOut.transform(.4), 1e-6));
    await tester.pump(const Duration(milliseconds: 360));
    expect(_progress(tester), 1);
  });

  testWidgets('a target changed while paused starts from the paused position',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpWidget(_host(flipped: true));
    await tester.pump(const Duration(milliseconds: 360));
    final paused = _progress(tester);
    await tester.pumpWidget(_host(flipped: true, enabled: false));
    await tester.pumpWidget(_host(enabled: false));
    await tester.pump(const Duration(seconds: 4));
    expect(_progress(tester), paused);
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 120));
    expect(_progress(tester),
        closeTo(paused * (1 - Curves.easeInOut.transform(.2)), 1e-6));
    await tester.pumpAndSettle();
    expect(_progress(tester), 0);
  });

  testWidgets('retiming preserves position and scales the remaining time',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpWidget(_host(flipped: true));
    await tester.pump(const Duration(milliseconds: 150));
    final before = _progress(tester);
    expect(before, closeTo(Curves.easeInOut.transform(.25), 1e-6));
    await tester.pumpWidget(_host(
      flipped: true,
      duration: const Duration(milliseconds: 1200),
    ));
    expect(_progress(tester), before);
    await tester.pump(const Duration(milliseconds: 120));
    expect(_progress(tester), closeTo(Curves.easeInOut.transform(.35), 1e-6));
    // 75% of the new 1200ms duration remained when it was changed.
    await tester.pump(const Duration(milliseconds: 779));
    expect(_progress(tester), lessThan(1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(_progress(tester), 1);
  });

  testWidgets('shorter and zero durations keep continuity and finish correctly',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpWidget(_host(flipped: true));
    await tester.pump(const Duration(milliseconds: 150));
    final before = _progress(tester);
    await tester.pumpWidget(_host(
      flipped: true,
      duration: const Duration(milliseconds: 300),
    ));
    expect(_progress(tester), before);
    await tester.pump(const Duration(milliseconds: 75));
    expect(_progress(tester), closeTo(Curves.easeInOut.transform(.5), 1e-6));
    await tester.pumpWidget(_host(flipped: true, duration: Duration.zero));
    expect(_progress(tester), 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('semantics follows the visible face through interruption',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host());
    expect(_hasSemanticsLabel('Front face'), isTrue);
    expect(_hasSemanticsLabel('Back face'), isFalse);
    await tester.pumpWidget(_host(flipped: true));
    await tester.pump(const Duration(milliseconds: 240));
    expect(_hasSemanticsLabel('Front face'), isTrue);
    expect(_hasSemanticsLabel('Back face'), isFalse);
    await tester.pump(const Duration(milliseconds: 120));
    expect(_hasSemanticsLabel('Front face'), isFalse);
    expect(_hasSemanticsLabel('Back face'), isTrue);
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 120));
    expect(_hasSemanticsLabel('Back face'), isTrue);
    await tester.pump(const Duration(milliseconds: 120));
    expect(_hasSemanticsLabel('Back face'), isFalse);
    expect(_hasSemanticsLabel('Front face'), isTrue);
    await tester.pumpAndSettle();
    handle.dispose();
  });

  testWidgets('focus wrappers rebuild only when the visible face changes',
      (tester) async {
    final box = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_NibFlipBox',
    );
    await tester.pumpWidget(_host());
    await tester.pumpWidget(_host(flipped: true));
    final frontWidgets = tester.widget(box);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 60));
      expect(identical(tester.widget(box), frontWidgets), isTrue,
          reason:
              'Progress must repaint without rebuilding widgets per frame.');
    }
    await tester.pump(const Duration(milliseconds: 120));
    final backWidgets = tester.widget(box);
    expect(identical(backWidgets, frontWidgets), isFalse);
    await tester.pump(const Duration(milliseconds: 60));
    expect(identical(tester.widget(box), backWidgets), isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('keyboard focus and activation exclude the hidden face',
      (tester) async {
    final frontFocus = FocusNode();
    final backFocus = FocusNode();
    var frontPresses = 0;
    var backPresses = 0;
    Widget host(bool flipped) => _host(
          flipped: flipped,
          front: TextButton(
            focusNode: frontFocus,
            onPressed: () => frontPresses++,
            child: const Text('Front action'),
          ),
          back: TextButton(
            focusNode: backFocus,
            onPressed: () => backPresses++,
            child: const Text('Back action'),
          ),
        );
    await tester.pumpWidget(host(false));
    frontFocus.requestFocus();
    await tester.pump();
    expect(frontFocus.hasFocus, isTrue);
    backFocus.requestFocus();
    await tester.pump();
    expect(backFocus.hasFocus, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(frontPresses, 1);
    expect(backPresses, 0);

    await tester.pumpWidget(host(true));
    await tester.pump(const Duration(milliseconds: 240));
    expect(frontFocus.hasFocus, isTrue);
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump();
    expect(frontFocus.hasFocus, isFalse);
    expect(frontFocus.canRequestFocus, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(backFocus.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(frontPresses, 1);
    expect(backPresses, 1);
    await tester.pumpWidget(const SizedBox());
    frontFocus.dispose();
    backFocus.dispose();
    expect(tester.takeException(), isNull);
  });
}

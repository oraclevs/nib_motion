import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

RenderNibMotion _render(WidgetTester tester) {
  RenderNibMotion? found;
  void visit(RenderObject o) {
    if (o is RenderNibMotion) found ??= o;
    o.visitChildren(visit);
  }

  tester.binding.rootElement!.renderObject!.visitChildren(visit);
  return found!;
}

/// `reassembleApplication` waits for a frame, which a fake-async test only
/// gets when it pumps one.
Future<void> _reassemble(WidgetTester tester) async {
  final done = tester.binding.reassembleApplication();
  await tester.pump();
  await done;
}

Widget _app({bool enabled = true}) => Directionality(
      textDirection: TextDirection.ltr,
      child: NibMotionConfig(
        entranceWarmup: Duration.zero,
        child: NibHotReloadReplay(
          enabled: enabled,
          child: const NibMotion(
            initial: NibAnim(opacity: 0),
            animate: NibAnim(opacity: 1),
            transition: NibTransition(duration: Duration(milliseconds: 400)),
            child: SizedBox(width: 20, height: 20),
          ),
        ),
      ),
    );

void main() {
  testWidgets('reassemble replays the entrance animation', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(_render(tester).opacity.value, 1.0);

    await _reassemble(tester);
    expect(_render(tester).opacity.value, lessThan(1.0),
        reason: 'reset to initial, replaying');
    await tester.pump(const Duration(milliseconds: 100));
    final mid = _render(tester).opacity.value;
    expect(mid, inExclusiveRange(0.0, 1.0));
    await tester.pumpAndSettle();
    expect(_render(tester).opacity.value, 1.0);
  });

  testWidgets('enabled: false does not replay', (tester) async {
    await tester.pumpWidget(_app(enabled: false));
    await tester.pumpAndSettle();
    await _reassemble(tester);
    expect(_render(tester).opacity.value, 1.0);
  });

  testWidgets('replays again on every reassemble and disposes cleanly',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await _reassemble(tester);
      expect(_render(tester).opacity.value, lessThan(1.0));
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}

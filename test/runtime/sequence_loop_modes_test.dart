import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

const _t = NibTransition(duration: Duration(milliseconds: 20));

Future<(NibMotionController, List<double>)> _setup(WidgetTester tester) async {
  final controller = NibMotionController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: NibMotion(
      controller: controller,
      child: const SizedBox(width: 10, height: 10),
    ),
  ));
  RenderNibMotion? render;
  void visit(RenderObject o) {
    if (o is RenderNibMotion) render = o;
    o.visitChildren(visit);
  }

  tester.binding.rootElement!.renderObject!.visitChildren(visit);
  final seen = <double>[];
  render!.translateX.addListener(() => seen.add(render!.translateX.value));
  return (controller, seen);
}

/// The distinct plateau values the x-position settled on, in order.
List<double> _plateaus(List<double> trace, List<double> targets) {
  final out = <double>[];
  for (final v in trace) {
    for (final t in targets) {
      if ((v - t).abs() < 1e-9 && (out.isEmpty || out.last != t)) out.add(t);
    }
  }
  return out;
}

Future<void> _run(WidgetTester tester, [int frames = 60]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets('restart: replays from the first step each pass', (tester) async {
    final (c, seen) = await _setup(tester);
    var passes = 0;
    final s = NibAnimationSequence(c)
        .animate(const NibAnim(x: 10), transition: _t)
        .animate(const NibAnim(x: 20), transition: _t)
        .call(() => passes++)
        .loop(2);
    addTearDown(s.dispose);
    s.play();
    await _run(tester);
    expect(passes, 2);
    expect(_plateaus(seen, [10, 20]), [10, 20, 10, 20]);
  });

  testWidgets('pingPong: alternates forward and backward through targets',
      (tester) async {
    final (c, seen) = await _setup(tester);
    var calls = 0;
    final s = NibAnimationSequence(c)
        .animate(const NibAnim(x: 10), transition: _t)
        .animate(const NibAnim(x: 20), transition: _t)
        .animate(const NibAnim(x: 30), transition: _t)
        .call(() => calls++)
        .loop(2, NibLoopMode.pingPong);
    addTearDown(s.dispose);
    s.play();
    await _run(tester, 100);
    // pass 0: 10 → 20 → 30 ; pass 1 (reversed): 20 → 10.
    expect(_plateaus(seen, [10, 20, 30]), [10, 20, 30, 20, 10]);
    expect(calls, 2, reason: 'call steps run in both directions');
  });

  testWidgets('pingPong with 3 passes goes forward again', (tester) async {
    final (c, seen) = await _setup(tester);
    final s = NibAnimationSequence(c)
        .animate(const NibAnim(x: 10), transition: _t)
        .animate(const NibAnim(x: 20), transition: _t)
        .loop(3, NibLoopMode.pingPong);
    addTearDown(s.dispose);
    s.play();
    await _run(tester, 100);
    // forward 10,20 · backward 10 · forward 10 (no change),20.
    expect(_plateaus(seen, [10, 20]), [10, 20, 10, 20]);
  });

  testWidgets('seamless skips a first step that equals the last on repeats',
      (tester) async {
    final (c, seen) = await _setup(tester);
    var starts = 0;
    final s = NibAnimationSequence(c)
        .animate(const NibAnim(x: 10), transition: _t)
        .call(() => starts++)
        .animate(const NibAnim(x: 20), transition: _t)
        .animate(const NibAnim(x: 10), transition: _t)
        .loop(3, NibLoopMode.seamless);
    addTearDown(s.dispose);
    s.play();
    await _run(tester, 200);
    // pass 0: 10,20,10 ; passes 1-2 skip the leading 10 (already there):
    // 20,10 each. So the value never pauses at 10 twice in a row.
    expect(_plateaus(seen, [10, 20]), [10, 20, 10, 20, 10, 20, 10]);
    expect(starts, 3);
  });

  testWidgets('seamless falls back to restart when first != last',
      (tester) async {
    final (c, seen) = await _setup(tester);
    final s = NibAnimationSequence(c)
        .animate(const NibAnim(x: 10), transition: _t)
        .animate(const NibAnim(x: 20), transition: _t)
        .loop(2, NibLoopMode.seamless);
    addTearDown(s.dispose);
    s.play();
    await _run(tester, 100);
    expect(_plateaus(seen, [10, 20]), [10, 20, 10, 20]);
  });

  testWidgets('stop() during a ping-pong loop halts it', (tester) async {
    final (c, seen) = await _setup(tester);
    final s = NibAnimationSequence(c)
        .animate(const NibAnim(x: 10), transition: _t)
        .animate(const NibAnim(x: 20), transition: _t)
        .loop(null, NibLoopMode.pingPong);
    addTearDown(s.dispose);
    s.play();
    await _run(tester, 10);
    s.stop();
    final n = seen.length;
    await _run(tester, 30);
    expect(seen.length, n);
  });
}

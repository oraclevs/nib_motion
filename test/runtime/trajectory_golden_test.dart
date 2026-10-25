// Numeric "animation sheet" goldens.
//
// Pixel goldens of motion are platform- and SDK-sensitive; the physics here
// is pure math, so we snapshot the per-frame trajectory (position, velocity)
// of key interruption scenarios and compare with a tolerance. Regenerate
// deliberately with: UPDATE_GOLDENS=1 flutter test test/runtime/trajectory_golden_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

const _frame = Duration(milliseconds: 16);

Future<List<List<double>>> _sample(
  WidgetTester tester,
  MotionValue<double> value,
  int frames,
  void Function(int frame)? onFrame,
) async {
  final rows = <List<double>>[];
  await tester.pump();
  for (var f = 1; f <= frames; f++) {
    onFrame?.call(f);
    await tester.pump(_frame);
    rows.add([value.value, value.velocity]);
  }
  return rows;
}

void _matchGolden(String name, List<List<double>> rows) {
  final file = File('test/runtime/goldens/$name.json');
  if (Platform.environment['UPDATE_GOLDENS'] == '1') {
    file.writeAsStringSync(
        '${const JsonEncoder.withIndent(' ').convert(rows.map((r) => r.map((v) => double.parse(v.toStringAsFixed(4))).toList()).toList())}\n');
    return;
  }
  final expected = (jsonDecode(file.readAsStringSync()) as List)
      .map((r) => (r as List).cast<num>().map((n) => n.toDouble()).toList())
      .toList();
  expect(rows.length, expected.length);
  for (var i = 0; i < rows.length; i++) {
    expect(rows[i][0], closeTo(expected[i][0], 1e-2),
        reason: '$name frame ${i + 1} position');
    expect(rows[i][1], closeTo(expected[i][1], 0.5),
        reason: '$name frame ${i + 1} velocity');
  }
}

void main() {
  testWidgets('spring A→B interrupted by B→C keeps position and velocity',
      (tester) async {
    final value = MotionValue<double>(0);
    final solver = SpringSolver(
        vsync: const TestVSync(),
        value: value,
        spring: NibSpringDescription.gentle);
    solver.animateTo(target: 300);
    final rows = await _sample(tester, value, 70, (f) {
      if (f == 15) solver.animateTo(target: 0);
    });
    _matchGolden('spring_retarget', rows);
    solver.dispose();
  });

  testWidgets('tween interrupted by spring hands over its velocity',
      (tester) async {
    final controller = NibMotionController();
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
    final value = render!.translateX;
    controller.start(
        target: const NibAnim(x: 100),
        transition: const NibTransition(
            duration: Duration(seconds: 1), curve: Curves.linear));
    final rows = await _sample(tester, value, 60, (f) {
      if (f == 30) {
        controller.start(
            target: const NibAnim(x: 0),
            transition: NibTransition.springSnappy);
      }
    });
    _matchGolden('tween_to_spring', rows);
  });

  testWidgets('inertia with elastic max bound', (tester) async {
    final value = MotionValue<double>(0);
    final solver = InertiaSolver(vsync: const TestVSync(), value: value);
    solver.animateTo(velocity: 3000, max: 100);
    final rows = await _sample(tester, value, 90, null);
    _matchGolden('inertia_bounded', rows);
    solver.dispose();
  });
}

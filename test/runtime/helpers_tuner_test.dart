import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _host({
  ValueChanged<NibSpringDescription>? onChanged,
  NibSpringTunerMode mode = NibSpringTunerMode.durationBounce,
  bool reduced = false,
}) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: NibMotionConfig(
        reducedMotion: reduced,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 420,
            child: NibSpringTuner(mode: mode, onChanged: onChanged),
          ),
        ),
      ),
    );

String _snippet(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('nib-tuner-snippet'))).data!;

Future<void> _tapSlider(
    WidgetTester tester, String key, double fraction) async {
  final finder = find.byKey(ValueKey(key));
  final rect = tester.getRect(finder);
  // Track starts after the 110px label.
  final trackLeft = rect.left + 110;
  final trackWidth = rect.width - 110;
  await tester.tapAt(Offset(trackLeft + trackWidth * fraction, rect.center.dy));
  await tester.pump();
}

void main() {
  testWidgets('shows sliders, curve, preview and a snippet', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.byKey(const ValueKey('nib-tuner-duration')), findsOneWidget);
    expect(find.byKey(const ValueKey('nib-tuner-bounce')), findsOneWidget);
    expect(find.byKey(const ValueKey('nib-tuner-curve')), findsOneWidget);
    expect(find.byKey(const ValueKey('nib-tuner-preview')), findsOneWidget);
    expect(_snippet(tester), startsWith('NibSpringDescription.fromDuration('));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'moving a slider reports the tuned spring and updates the snippet',
      (tester) async {
    final seen = <NibSpringDescription>[];
    await tester.pumpWidget(_host(onChanged: seen.add));
    await tester.pumpAndSettle();
    final before = _snippet(tester);
    await _tapSlider(tester, 'nib-tuner-bounce', 0.95);
    expect(seen, isNotEmpty);
    expect(_snippet(tester), isNot(before));
    // Bouncier spring => less damping than the critically damped default.
    final bouncy = seen.last;
    await _tapSlider(tester, 'nib-tuner-bounce', 0.05);
    expect(seen.last.damping / (2 * 1.0 * seen.last.stiffness.abs()),
        greaterThan(bouncy.damping / (2 * 1.0 * bouncy.stiffness.abs())));
    await tester.pumpAndSettle();
  });

  testWidgets('physical mode edits mass / stiffness / damping', (tester) async {
    NibSpringDescription? last;
    await tester.pumpWidget(
        _host(mode: NibSpringTunerMode.physical, onChanged: (s) => last = s));
    expect(find.byKey(const ValueKey('nib-tuner-stiffness')), findsOneWidget);
    await _tapSlider(tester, 'nib-tuner-stiffness', 0.995);
    expect(last!.stiffness, closeTo(800, 10));
    expect(_snippet(tester), contains('stiffness: 79'));
    await tester.pumpAndSettle();
  });

  testWidgets('switching mode swaps the slider set', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.byKey(const ValueKey('nib-tuner-mode-physical')));
    await tester.pump();
    expect(find.byKey(const ValueKey('nib-tuner-mass')), findsOneWidget);
    expect(find.byKey(const ValueKey('nib-tuner-duration')), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('preview runs a real spring from 0 to 1 and replays',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
    await tester.tap(find.byKey(const ValueKey('nib-tuner-replay')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('reduced motion: preview jumps, no ticker', (tester) async {
    await tester.pumpWidget(_host(reduced: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('copy puts the snippet on the clipboard', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nib-tuner-copy')));
    await tester.pump();
    expect(copied, _snippet(tester));
  });

  testWidgets('disposes mid-animation without errors', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}

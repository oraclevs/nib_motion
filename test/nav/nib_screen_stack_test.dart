import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

/// Hosts a [NibScreenStack] and exposes a way to change [currentIndex] the
/// same way [NibScaffold] does (a `setState` in a parent, not a new widget
/// instance), so `didUpdateWidget`'s transition logic actually runs.
class _Host extends StatefulWidget {
  const _Host({required this.screens});

  final List<NibNavScreen> screens;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int index = 0;

  void switchTo(int newIndex) => setState(() => index = newIndex);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: NibScreenStack(screens: widget.screens, currentIndex: index),
    );
  }
}

void main() {
  testWidgets(
      'incoming screen accepts taps immediately after a tab switch, '
      'without waiting for the enter spring to fully settle', (tester) async {
    var tapsOnB = 0;

    await tester.pumpWidget(_Host(screens: [
      const NibNavScreen(child: ColoredBox(color: Colors.red)),
      NibNavScreen(
        child: Center(
          child: ElevatedButton(
            onPressed: () => tapsOnB++,
            child: const Text('B'),
          ),
        ),
      ),
    ]));

    tester.state<_HostState>(find.byType(_Host)).switchTo(1);
    await tester.pump();

    // A single frame in: the incoming screen is already on top and visually
    // present (default transition is a fade), but its spring hasn't
    // mathematically settled to Flutter's tolerance yet — that takes ~1s for
    // the default `gentle` spring. A real user's first tap lands well before
    // that.
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('B'));
    await tester.pump();

    expect(tapsOnB, 1,
        reason: 'tap on the incoming screen should not be swallowed while '
            'the enter transition is still playing out its settle tail');

    // Let the transition fully finish so the test doesn't leave a pending
    // timer/ticker behind.
    await tester.pump(const Duration(seconds: 2));
  });
}

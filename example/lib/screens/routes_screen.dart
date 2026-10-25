import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

import 'demo_scaffold.dart';

/// Dialogs, modals and pages whose content moves with NibMotion physics.
class RoutesScreen extends StatefulWidget {
  /// Creates the screen.
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  final GlobalKey _card = GlobalKey();
  String _result = 'none yet';

  Future<void> _dialog() async {
    final ok = await showNibDialog<bool>(
      context: context,
      builder: (context) => _Sheet(
        title: 'Delete item?',
        body: 'Tap outside or pop while it is still arriving: the exit '
            'continues from the current position and velocity.',
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (mounted) setState(() => _result = 'dialog returned $ok');
  }

  Future<void> _bottomSheet() async {
    final ok = await Navigator.of(context).push<bool>(NibModalRoute<bool>(
      initial: const NibAnim(y: 420, opacity: 0),
      alignment: Alignment.bottomCenter,
      transition: NibSpring.spatialDefault.transition,
      builder: (context) => _Sheet(
        title: 'Bottom modal',
        body: 'A NibModalRoute with its own initial pose (slides up).',
        actions: [
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Done')),
        ],
      ),
    ));
    if (mounted) setState(() => _result = 'modal returned $ok');
  }

  Future<void> _shared() async {
    await showNibDialog<void>(
      context: context,
      sharedFrom: _card,
      builder: (context) => _Sheet(
        title: 'Grew out of the card',
        body: 'This dialog started at the card\'s position and size, and '
            'shrinks back into it when you close it.',
        actions: [
          FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close')),
        ],
      ),
    );
  }

  void _page({bool backSwipe = false, GlobalKey? sharedFrom}) {
    Navigator.of(context).push(NibPageRoute<void>(
      backSwipe: backSwipe,
      sharedFrom: sharedFrom,
      builder: (context) => _DetailPage(backSwipe: backSwipe),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Routes',
      blurb: 'Route content is a NibMotion, so it keeps velocity when '
          'interrupted and honours reduced motion. Try each button; on the page '
          'with back-swipe, drag from the left edge.',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            key: _card,
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.indigo,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text('Source card (sharedFrom)',
                style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton(
                onPressed: _dialog, child: const Text('showNibDialog')),
            FilledButton(
                onPressed: _bottomSheet,
                child: const Text('NibModalRoute (bottom)')),
            FilledButton(
                onPressed: _shared,
                child: const Text('Dialog sharedFrom card')),
            FilledButton(
                onPressed: () => _page(), child: const Text('NibPageRoute')),
            FilledButton(
                onPressed: () => _page(backSwipe: true),
                child: const Text('Page + backSwipe')),
            FilledButton(
                onPressed: () => _page(sharedFrom: _card),
                child: const Text('Page sharedFrom card')),
          ]),
          const SizedBox(height: 16),
          Text('Last result: $_result'),
        ],
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet(
      {required this.title, required this.body, required this.actions});

  final String title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(body),
                const SizedBox(height: 16),
                Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailPage extends StatelessWidget {
  const _DetailPage({required this.backSwipe});

  final bool backSwipe;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail page')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            backSwipe
                ? 'Drag from the left edge to pop. Release past 40% (or fling) '
                    'and the release velocity carries into the exit spring.'
                : 'Pushed with NibPageRoute. Use the back button.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

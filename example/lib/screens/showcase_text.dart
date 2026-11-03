import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

import 'demo_scaffold.dart';

/// Word, character, typewriter and mask-reveal text examples.
class ShowcaseTextScreen extends StatefulWidget {
  /// Creates the text showcase.
  const ShowcaseTextScreen({super.key});

  @override
  State<ShowcaseTextScreen> createState() => _ShowcaseTextScreenState();
}

class _ShowcaseTextScreenState extends State<ShowcaseTextScreen> {
  int _mode = 0;
  int _replay = 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.headlineLarge!.copyWith(
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: colors.onPrimaryContainer,
        );
    const phrase = 'Small details. Strong impressions.';
    final Widget text;
    if (_mode == 2) {
      text = NibTypewriter(phrase,
          cursor: null, speed: const Duration(milliseconds: 45), style: style);
    } else if (_mode == 3) {
      text = NibTextReveal(
        direction: NibTextRevealDirection.up,
        duration: const Duration(milliseconds: 900),
        child: Text(phrase, style: style),
      );
    } else {
      text = NibText(
        phrase,
        style: style,
        config: NibTextConfig(
          unit: _mode == 0 ? NibTextUnit.word : NibTextUnit.character,
          initial: const NibAnim(opacity: 0, y: 20),
          animate: const NibAnim(opacity: 1, y: 0),
          staggerDelay: Duration(milliseconds: _mode == 0 ? 130 : 25),
          transition: NibTransition.springSnappy,
        ),
      );
    }
    return DemoScaffold(
      title: 'Text in motion',
      blurb: 'Choose a reveal, then replay it. The same sentence takes on a '
          'different rhythm with each treatment.',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final (i, label) in [
                      'Words',
                      'Characters',
                      'Typewriter',
                      'Wipe'
                    ].indexed)
                      ChoiceChip(
                        label: Text(label),
                        selected: _mode == i,
                        onSelected: (_) => setState(() {
                          _mode = i;
                          _replay++;
                        }),
                      ),
                  ]),
                  const SizedBox(height: 20),
                  Container(
                    constraints: const BoxConstraints(minHeight: 280),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('A LITTLE EXPRESSION',
                            style: TextStyle(
                                color: colors.onPrimaryContainer,
                                letterSpacing: 1.8,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 24),
                        KeyedSubtree(key: ValueKey(_replay), child: text),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: () => setState(() => _replay++),
                      icon: const Icon(Icons.replay),
                      label: const Text('Replay text'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Words and characters use staggered motion. Typewriter '
                    'changes the visible text; wipe reveals a single text block. '
                    'Reduced motion shows the complete sentence.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

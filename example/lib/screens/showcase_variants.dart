import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

import 'demo_scaffold.dart';

/// Named states shared by a group, plus small reusable motion presets.
class ShowcaseVariantsScreen extends StatefulWidget {
  /// Creates the variants showcase.
  const ShowcaseVariantsScreen({super.key});

  @override
  State<ShowcaseVariantsScreen> createState() => _ShowcaseVariantsScreenState();
}

class _ShowcaseVariantsScreenState extends State<ShowcaseVariantsScreen> {
  bool _expanded = true;
  bool _presetsPlaying = false;
  int _replay = 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DemoScaffold(
      title: 'Coordinated states',
      blurb: 'One named state reaches every card. Switch the group, replay the '
          'staggered entrance, then try the motion presets.',
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(spacing: 12, runSpacing: 8, children: [
                  FilledButton.icon(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(_expanded ? Icons.compress : Icons.expand),
                    label:
                        Text(_expanded ? 'Rest the group' : 'Lift the group'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _expanded = true;
                      _replay++;
                    }),
                    icon: const Icon(Icons.replay),
                    label: const Text('Replay stagger'),
                  ),
                ]),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: NibMotion(
                    key: ValueKey(_replay),
                    animate: _expanded ? 'lifted' : 'rest',
                    variants: const {
                      'lifted': NibAnim(),
                      'rest': NibAnim(),
                    },
                    transition: const NibTransition(
                        staggerChildren: Duration(milliseconds: 120)),
                    child: Column(children: [
                      for (final (i, label) in [
                        'Make space',
                        'Find a rhythm',
                        'Keep moving'
                      ].indexed)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: NibMotion(
                            initial: const NibAnim(opacity: 0, y: 20),
                            variants: const {
                              'lifted': NibAnim(opacity: 1, y: -5, scale: 1),
                              'rest': NibAnim(opacity: 1, y: 0, scale: 0.94),
                            },
                            transition: NibTransition.springSnappy,
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: colors.surface,
                                borderRadius: BorderRadius.circular(18),
                                border:
                                    Border.all(color: colors.outlineVariant),
                              ),
                              child: Row(children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: colors.primaryContainer,
                                  foregroundColor: colors.onPrimaryContainer,
                                  child: Text('0${i + 1}'),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                ),
                              ]),
                            ),
                          ),
                        ),
                    ]),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Small motions, ready to use',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('Pulse and float repeat while enabled. Bounce is '
                    'a single entrance. Reduced motion keeps them still.'),
                const SizedBox(height: 20),
                TickerMode(
                  enabled: _presetsPlaying,
                  child: Wrap(spacing: 20, runSpacing: 24, children: [
                    NibPulse(
                      child: _PresetTile(
                          icon: Icons.favorite_outline,
                          label: 'Pulse',
                          color: colors.primaryContainer,
                          foreground: colors.onPrimaryContainer),
                    ),
                    NibFloat(
                      distance: 8,
                      child: _PresetTile(
                          icon: Icons.cloud_outlined,
                          label: 'Float',
                          color: colors.tertiaryContainer,
                          foreground: colors.onTertiaryContainer),
                    ),
                    NibBounce(
                      key: ValueKey(_presetsPlaying),
                      child: _PresetTile(
                          icon: Icons.bolt_outlined,
                          label: 'Bounce',
                          color: colors.secondaryContainer,
                          foreground: colors.onSecondaryContainer),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Play presets'),
                  value: _presetsPlaying,
                  onChanged: (value) => setState(() => _presetsPlaying = value),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 94,
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: foreground, size: 30),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: foreground)),
      ]),
    );
  }
}

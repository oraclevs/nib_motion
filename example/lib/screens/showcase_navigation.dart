import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

import 'demo_scaffold.dart';

/// Animated tabs with a spring indicator and coordinated screen transitions.
class ShowcaseNavigationScreen extends StatefulWidget {
  /// Creates the navigation showcase.
  const ShowcaseNavigationScreen({super.key});

  @override
  State<ShowcaseNavigationScreen> createState() =>
      _ShowcaseNavigationScreenState();
}

class _ShowcaseNavigationScreenState extends State<ShowcaseNavigationScreen> {
  int _index = 0;
  NibNavTransitionType _transition = NibNavTransitionType.sharedAxis;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DemoScaffold(
      title: 'Navigation flow',
      blurb: 'Switch destinations and watch the indicator catch up. Choose '
          'a transition to change how the screens hand over.',
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final (kind, label) in [
                    (NibNavTransitionType.sharedAxis, 'Shared axis'),
                    (NibNavTransitionType.fade, 'Fade'),
                    (NibNavTransitionType.slideHorizontal, 'Slide'),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _transition == kind,
                      onSelected: (_) => setState(() => _transition = kind),
                    ),
                ]),
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    height: 440,
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      border: Border.all(color: colors.outlineVariant),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(children: [
                      Expanded(
                        child: NibScreenStack(
                          currentIndex: _index,
                          screenTransition: NibNavScreenTransition(
                            type: _transition,
                            spring: NibSpringDescription.snappy,
                          ),
                          screens: [
                            NibNavScreen(
                              child: _Destination(
                                icon: Icons.wb_sunny_outlined,
                                eyebrow: 'FOCUS',
                                title: 'Room to think.',
                                description:
                                    'Give one good idea your attention.',
                                color: colors.primaryContainer,
                                foreground: colors.onPrimaryContainer,
                              ),
                            ),
                            NibNavScreen(
                              child: _Destination(
                                icon: Icons.bookmarks_outlined,
                                eyebrow: 'LIBRARY',
                                title: 'Keep what matters.',
                                description: 'A quiet home for your next idea.',
                                color: colors.tertiaryContainer,
                                foreground: colors.onTertiaryContainer,
                              ),
                            ),
                            NibNavScreen(
                              child: _Destination(
                                icon: Icons.insights_outlined,
                                eyebrow: 'PROGRESS',
                                title: 'A little, every day.',
                                description:
                                    'Small steps make a visible difference.',
                                color: colors.secondaryContainer,
                                foreground: colors.onSecondaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                      NibNavBar(
                        currentIndex: _index,
                        onIndexChanged: (index) =>
                            setState(() => _index = index),
                        style: NibNavBarStyle(
                          height: 80,
                          backgroundColor: colors.surface,
                          activeColor: colors.primary,
                          inactiveColor: colors.onSurfaceVariant,
                        ),
                        indicator: NibNavIndicatorStyle(
                          type: NibNavIndicatorType.pill,
                          color: colors.primaryContainer,
                          width: 70,
                        ),
                        items: const [
                          NibNavItem(
                              icon: Icon(Icons.wb_sunny_outlined),
                              label: 'Focus',
                              tooltip: 'Open Focus'),
                          NibNavItem(
                              icon: Icon(Icons.bookmarks_outlined),
                              label: 'Library',
                              tooltip: 'Open Library'),
                          NibNavItem(
                              icon: Icon(Icons.insights_outlined),
                              label: 'Progress',
                              tooltip: 'Open Progress'),
                        ],
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () => setState(() => _index = (_index + 1) % 3),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Next destination'),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('NibNavBar moves the selected indicator with a '
                    'spring. NibScreenStack keeps these destinations mounted '
                    'and coordinates their entrances and exits. Reduced '
                    'motion switches directly to the new destination.'),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.color,
    required this.foreground,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String description;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground, size: 52),
          const SizedBox(height: 24),
          Text(eyebrow,
              style: TextStyle(
                  color: foreground,
                  fontSize: 11,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium!
                  .copyWith(color: foreground, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(description, style: TextStyle(color: foreground, height: 1.4)),
        ],
      ),
    );
  }
}

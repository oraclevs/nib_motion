import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

import 'demo_scaffold.dart';

/// Bundled visual effects with their actual shader availability reported.
class ShowcaseEffectsScreen extends StatefulWidget {
  /// Creates the shader showcase.
  const ShowcaseEffectsScreen({super.key});

  @override
  State<ShowcaseEffectsScreen> createState() => _ShowcaseEffectsScreenState();
}

class _ShowcaseEffectsScreenState extends State<ShowcaseEffectsScreen> {
  int _effect = 0;
  int _replay = 0;
  bool _shimmer = true;
  bool? _dissolveAvailable;
  bool? _shimmerAvailable;
  bool? _glassAvailable;

  @override
  void initState() {
    super.initState();
    _checkShaders();
  }

  Future<void> _checkShaders() async {
    final dissolve = await NibShaderLoader.dissolve()
        .then((_) => true, onError: (Object _) => false);
    final shimmer = await NibShaderLoader.shimmer()
        .then((_) => true, onError: (Object _) => false);
    final glass = await NibGlass.debugShaderPathAvailable();
    if (!mounted) return;
    setState(() {
      _dissolveAvailable = dissolve;
      _shimmerAvailable = shimmer;
      _glassAvailable = glass;
    });
  }

  String get _status {
    final available =
        [_dissolveAvailable, _shimmerAvailable, _glassAvailable][_effect];
    if (available == null) return 'Checking this renderer…';
    if (_effect == 0) {
      return available ? 'Dissolve shader loaded' : 'Opacity fallback active';
    }
    if (_effect == 1) {
      return available
          ? 'Shimmer shader loaded'
          : 'Plain child fallback active';
    }
    return available
        ? 'Glass refraction supported'
        : 'Frosted blur fallback active';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final card = Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primaryContainer, colors.tertiaryContainer],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, size: 40, color: colors.onPrimaryContainer),
          const SizedBox(height: 24),
          Text('Find your flow.',
              style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.onPrimaryContainer)),
          const SizedBox(height: 8),
          Text('A surface with a little more character.',
              style: TextStyle(color: colors.onPrimaryContainer)),
        ],
      ),
    );
    final Widget effect;
    if (_effect == 0) {
      effect = NibDissolve(
        key: ValueKey(_replay),
        direction: NibDissolveDirection.inward,
        duration: const Duration(milliseconds: 1500),
        child: card,
      );
    } else if (_effect == 1) {
      effect = NibShimmer(
        enabled: _shimmer,
        speed: 0.6,
        baseColor: colors.primaryContainer,
        shimmerColor: colors.surface,
        child: card,
      );
    } else {
      effect = ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: colors.tertiaryContainer),
            Positioned(
              left: -40,
              top: -60,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: colors.primary),
              ),
            ),
            Positioned(
              right: -35,
              bottom: -70,
              child: Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: colors.tertiary),
              ),
            ),
            Center(
              child: NibGlass(
                blurSigma: 5,
                tint: colors.surface.withValues(alpha: 0.75),
                child: SizedBox(
                  width: 220,
                  height: 180,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.blur_on, size: 36, color: colors.onSurface),
                      const SizedBox(height: 12),
                      Text('Through the glass',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: colors.onSurface)),
                      const SizedBox(height: 6),
                      Text('A bounded backdrop surface',
                          style: TextStyle(color: colors.onSurface)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return DemoScaffold(
      title: 'Shader studio',
      blurb: 'Try a textured entrance, a shimmer sweep, and a glass surface. '
          'The status below identifies shader support and fallbacks.',
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final (i, label)
                      in ['Dissolve', 'Shimmer', 'Glass'].indexed)
                    ChoiceChip(
                      label: Text(label),
                      selected: _effect == i,
                      onSelected: (_) => setState(() {
                        _effect = i;
                        _replay++;
                      }),
                    ),
                ]),
                const SizedBox(height: 20),
                SizedBox(height: 300, child: effect),
                const SizedBox(height: 20),
                if (_effect == 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: () => setState(() => _replay++),
                      icon: const Icon(Icons.replay),
                      label: const Text('Replay dissolve'),
                    ),
                  ),
                if (_effect == 1)
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Animate shimmer'),
                    value: _shimmer,
                    onChanged: (value) => setState(() => _shimmer = value),
                  ),
                const SizedBox(height: 12),
                Semantics(liveRegion: true, child: Text(_status)),
                const SizedBox(height: 12),
                const Text('Glass uses refraction on supported Impeller '
                    'renderers and frosted blur elsewhere. A loaded shader '
                    'does not guarantee identical output on every GPU. '
                    'Reduced motion stops the decorative sweep and skips '
                    'the dissolve entrance.'),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

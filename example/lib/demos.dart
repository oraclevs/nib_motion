// A menu of small screens, each dogfooding one part of nib_motion.
//
// Run: flutter run -t lib/demos.dart
import 'package:flutter/material.dart';

import 'screens/drag_screen.dart';
import 'screens/fx_screen.dart';
import 'screens/interruption_screen.dart';
import 'screens/layout_screen.dart';
import 'screens/multi_axis_screen.dart';
import 'screens/presence_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/reduced_motion_screen.dart';
import 'screens/timeline_screen.dart';
import 'screens/hot_reload_screen.dart';
import 'screens/layout_modes_screen.dart';
import 'screens/pages_screen.dart';
import 'screens/presence_layout_screen.dart';
import 'screens/routes_screen.dart';
import 'screens/simulation_screen.dart';
import 'screens/sliver_screen.dart';
import 'screens/timeline_scrub_screen.dart';
import 'screens/transitions_screen.dart';
import 'screens/tuner_screen.dart';
import 'screens/value_builder_screen.dart';
import 'screens/velocity_screen.dart';

void main() => runApp(const DemosApp());

/// The demo menu app.
class DemosApp extends StatelessWidget {
  /// Creates the app.
  const DemosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'nib_motion demos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const DemoMenu(),
    );
  }
}

/// Every demo screen: title, description and builder.
final List<DemoEntry> demoEntries = [
  DemoEntry('Interruption', 'Retarget springs mid-flight, velocity kept',
      () => const InterruptionScreen()),
  DemoEntry('Drag, inertia, snap', 'Bounded inertia + snapProjection',
      () => const DragScreen()),
  DemoEntry(
      'Presence', 'Re-entry, stagger, pop exit', () => const PresenceScreen()),
  DemoEntry('Layout (FLIP)', 'Wrap, size, layoutId, reorder',
      () => const LayoutScreen()),
  DemoEntry('Reduced motion', 'One policy for every widget',
      () => const ReducedMotionScreen()),
  DemoEntry('Effects & tokens', '3D flip, blur, tint, NibSpring',
      () => const FxScreen()),
  DemoEntry('Timeline', 'Labels, relative timing, scrubber',
      () => const TimelineScreen()),
  DemoEntry('Multi-axis values', 'Per-axis springs, NibValueBuilder',
      () => const MultiAxisScreen()),
  DemoEntry('Viewport progress', 'Scroll-linked parallax',
      () => const ProgressScreen()),
  DemoEntry('Routes', 'showNibDialog, NibPageRoute, backSwipe, sharedFrom',
      () => const RoutesScreen()),
  DemoEntry('Sliver header + list FLIP', 'NibSliverHeaderDelegate, reflow',
      () => const SliverScreen()),
  DemoEntry('Timeline drag-scrub', 'Auto-derived from:, labels',
      () => const TimelineScrubScreen()),
  DemoEntry('Spring tuner', 'Live NibSpringTuner', () => const TunerScreen()),
  DemoEntry('Velocity + Offset adapter', 'velocityOf, NibMotionValues(offset:)',
      () => const VelocityScreen()),
  DemoEntry('NibPresence.layout', 'Column / row / wrap, pop exit',
      () => const PresenceLayoutScreen()),
  DemoEntry('Layout size modes', 'scale vs clip, delay, RepaintBoundary',
      () => const LayoutModesScreen()),
  DemoEntry('NibValueBuilder', 'Spring vs tween, withChild',
      () => const ValueBuilderScreen()),
  DemoEntry('Page, tab, viewport progress', 'PageView, TabController, reversed',
      () => const PagesScreen()),
  DemoEntry(
      'Directional transitions',
      'reverse/exit transitions, loops, spring keyframes',
      () => const TransitionsScreen()),
  DemoEntry(
      'Hot reload replay', 'NibHotReloadReplay', () => const HotReloadScreen()),
  DemoEntry('Custom Simulation', 'NibSimulationDriver gravity bounce',
      () => const SimulationScreen()),
];

/// One row of the menu.
class DemoEntry {
  /// Creates an entry.
  const DemoEntry(this.title, this.subtitle, this.builder);

  /// Row title.
  final String title;

  /// Row subtitle.
  final String subtitle;

  /// Builds the screen.
  final Widget Function() builder;
}

/// The list of demos.
class DemoMenu extends StatelessWidget {
  /// Creates the menu.
  const DemoMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('nib_motion demos')),
      body: ListView(children: [
        for (final e in demoEntries)
          ListTile(
            title: Text(e.title),
            subtitle: Text(e.subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => e.builder())),
          ),
      ]),
    );
  }
}

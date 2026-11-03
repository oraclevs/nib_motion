import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

import '../screens/showcase_text.dart';
import '../screens/showcase_effects.dart';
import '../screens/showcase_paths.dart';
import '../screens/showcase_variants.dart';
import '../screens/showcase_navigation.dart';

import '../main.dart' show DailyFocusApp;
import '../readme/retarget.dart' show SpringDemo;
import '../screens/drag_screen.dart';
import '../screens/fx_screen.dart';
import '../screens/interruption_screen.dart';
import '../screens/layout_screen.dart';
import '../screens/multi_axis_screen.dart';
import '../screens/presence_screen.dart';
import '../screens/progress_screen.dart';
import '../screens/reduced_motion_screen.dart';
import '../screens/timeline_screen.dart';
import '../screens/hot_reload_screen.dart';
import '../screens/layout_modes_screen.dart';
import '../screens/pages_screen.dart';
import '../screens/presence_layout_screen.dart';
import '../screens/routes_screen.dart';
import '../screens/simulation_screen.dart';
import '../screens/sliver_screen.dart';
import '../screens/timeline_scrub_screen.dart';
import '../screens/transitions_screen.dart';
import '../screens/tuner_screen.dart';
import '../screens/value_builder_screen.dart';
import '../screens/velocity_screen.dart';

/// Metadata for one interactive example. Slugs remain stable for shared links.
class DemoEntry {
  /// Creates a gallery entry.
  const DemoEntry(
    this.title,
    this.subtitle,
    this.builder, {
    required this.slug,
    required this.category,
    required this.source,
    required this.instructions,
    this.notice,
  });

  /// Display title retained from the original example registry.
  final String title;

  /// Short explanation of the capability.
  final String subtitle;

  /// Builds this example only while it is selected.
  final Widget Function() builder;

  /// Stable URL segment.
  final String slug;

  /// Functional group in the gallery.
  final String category;

  /// Repository-relative implementation path.
  final String source;

  /// What the visitor should try.
  final String instructions;

  /// Renderer or experimental limitation, when applicable.
  final String? notice;

  /// Reviewable source URL for the current feature branch.
  String get sourceUrl => 'https://github.com/oraclevs/nib_motion/blob/'
      'feat/interactive-showcase-0.3.6/$source';
}

/// All 21 original demos, in their original order.
final List<DemoEntry> demoEntries = [
  DemoEntry(
      'Interruption',
      'Retarget springs mid-flight while preserving velocity.',
      () => const InterruptionScreen(),
      slug: 'interruption',
      category: 'Physics & gestures',
      source: 'example/lib/screens/interruption_screen.dart',
      instructions:
          'Tap a track, then tap its other end before the square settles.'),
  DemoEntry(
      'Drag, inertia, snap',
      'Coast within bounds and snap toward the projected destination.',
      () => const DragScreen(),
      slug: 'drag',
      category: 'Physics & gestures',
      source: 'example/lib/screens/drag_screen.dart',
      instructions:
          'Drag or flick either square. Switch projection on and compare its landing.'),
  DemoEntry(
      'Presence',
      'Animate a child entering, leaving, and returning during its exit.',
      () => const PresenceScreen(),
      slug: 'presence',
      category: 'Layout & presence',
      source: 'example/lib/screens/presence_screen.dart',
      instructions:
          'Toggle the content, including while an entrance or exit is playing.'),
  DemoEntry(
      'Layout (FLIP)',
      'Animate reordering and changes to size and shared layout.',
      () => const LayoutScreen(),
      slug: 'layout',
      category: 'Layout & presence',
      source: 'example/lib/screens/layout_screen.dart',
      instructions:
          'Reorder the items and change the layout while they are moving.'),
  DemoEntry(
      'Reduced motion',
      'Apply a motion preference across multiple animation types.',
      () => const ReducedMotionScreen(),
      slug: 'reduced-motion',
      category: 'Accessibility',
      source: 'example/lib/screens/reduced_motion_screen.dart',
      instructions:
          'Use the local Reduce motion switch, then change state and drag the square.',
      notice:
          'Known issue: rapidly switching the local motion preference off, on, then off can trigger a gradient-text ticker assertion in debug. Reload the browser if this occurs; export review notes first. Runtime fix is tracked separately.'),
  DemoEntry(
      'Effects & tokens',
      'Compare spring tokens, perspective rotation, blur, and tint.',
      () => const FxScreen(),
      slug: 'effects',
      category: 'Effects & shaders',
      source: 'example/lib/screens/fx_screen.dart',
      instructions:
          'Flip the cards, apply blur and tint, then compare the moving spring tokens.'),
  DemoEntry(
      'Timeline',
      'Sequence values using labels, relative timing, and seeking.',
      () => const TimelineScreen(),
      slug: 'timeline',
      category: 'Timelines & orchestration',
      source: 'example/lib/screens/timeline_screen.dart',
      instructions:
          'Play the sequence, then move the progress control to inspect a moment.'),
  DemoEntry(
      'Multi-axis values',
      'Animate independent values with a spring for each axis.',
      () => const MultiAxisScreen(),
      slug: 'multi-axis',
      category: 'Core motion',
      source: 'example/lib/screens/multi_axis_screen.dart',
      instructions: 'Change the target and compare how the axes settle.'),
  DemoEntry(
      'Viewport progress',
      'Map scroll position to values for a parallax composition.',
      () => const ProgressScreen(),
      slug: 'viewport',
      category: 'Scroll & navigation',
      source: 'example/lib/screens/progress_screen.dart',
      instructions:
          'Scroll within the panel and watch how position changes the motion.'),
  DemoEntry(
      'Routes',
      'Use animated dialogs, page routes, back-swipe, and shared origins.',
      () => const RoutesScreen(),
      slug: 'routes',
      category: 'Scroll & navigation',
      source: 'example/lib/screens/routes_screen.dart',
      instructions:
          'Open a dialog or detail page. Close it or swipe back from the left edge.'),
  DemoEntry(
      'Sliver header + list FLIP',
      'Combine a changing sliver header with animated list reflow.',
      () => const SliverScreen(),
      slug: 'slivers',
      category: 'Scroll & navigation',
      source: 'example/lib/screens/sliver_screen.dart',
      instructions:
          'Insert a row, then scroll the list to collapse its header.'),
  DemoEntry(
      'Timeline drag-scrub',
      'Seek a timeline using a pointer and labeled positions.',
      () => const TimelineScrubScreen(),
      slug: 'timeline-scrub',
      category: 'Timelines & orchestration',
      source: 'example/lib/screens/timeline_scrub_screen.dart',
      instructions:
          'Drag the scrub control to move through the sequence in either direction.'),
  DemoEntry(
      'Spring tuner',
      'Adjust spring parameters and see their effect on a moving subject.',
      () => const TunerScreen(),
      slug: 'spring-tuner',
      category: 'Developer tools',
      source: 'example/lib/screens/tuner_screen.dart',
      instructions:
          'Change a spring parameter, then trigger the movement to compare.'),
  DemoEntry(
      'Velocity + Offset adapter',
      'Read gesture velocity and connect an Offset value to a transform.',
      () => const VelocityScreen(),
      slug: 'velocity',
      category: 'Physics & gestures',
      source: 'example/lib/screens/velocity_screen.dart',
      instructions: 'Fling the square and watch its live velocity readout.'),
  DemoEntry(
      'NibPresence.layout',
      'Combine entry, exit, and sibling reflow in one layout.',
      () => const PresenceLayoutScreen(),
      slug: 'presence-layout',
      category: 'Layout & presence',
      source: 'example/lib/screens/presence_layout_screen.dart',
      instructions:
          'Add or remove an item and change between row, column, and wrap.'),
  DemoEntry(
      'Layout size modes',
      'Compare scaling and clipping as a layout changes size.',
      () => const LayoutModesScreen(),
      slug: 'layout-modes',
      category: 'Layout & presence',
      source: 'example/lib/screens/layout_modes_screen.dart',
      instructions: 'Toggle the size, then compare the scale and clip modes.'),
  DemoEntry(
      'NibValueBuilder',
      'Drive a widget value using a spring or a tween.',
      () => const ValueBuilderScreen(),
      slug: 'value-builder',
      category: 'Core motion',
      source: 'example/lib/screens/value_builder_screen.dart',
      instructions: 'Change the target and switch transition types.'),
  DemoEntry(
      'Page, tab, viewport progress',
      'Connect page, tab, and viewport progress to motion values.',
      () => const PagesScreen(),
      slug: 'pages',
      category: 'Scroll & navigation',
      source: 'example/lib/screens/pages_screen.dart',
      instructions:
          'Swipe the pages, select a tab, and scroll to inspect viewport progress.'),
  DemoEntry(
      'Directional transitions',
      'Use different transitions for forward, reverse, exit, and looping motion.',
      () => const TransitionsScreen(),
      slug: 'transitions',
      category: 'Timelines & orchestration',
      source: 'example/lib/screens/transitions_screen.dart',
      instructions: 'Toggle the state repeatedly and compare each direction.'),
  DemoEntry(
      'Hot reload replay',
      'Replay entrances while developing with Flutter hot reload.',
      () => const HotReloadScreen(),
      slug: 'hot-reload',
      category: 'Developer tools',
      source: 'example/lib/screens/hot_reload_screen.dart',
      instructions:
          'Use replay here. To test hot reload, run this source in a Flutter development session.'),
  DemoEntry(
      'Custom Simulation',
      'Drive a value with a custom gravity-and-bounce simulation.',
      () => const SimulationScreen(),
      slug: 'simulation',
      category: 'Physics & gestures',
      source: 'example/lib/screens/simulation_screen.dart',
      instructions:
          'Press Drop and watch the bounce count. Drop again to restart.'),
];

/// Existing runnable applications and README examples.
final List<DemoEntry> companionEntries = [
  DemoEntry(
      'Daily Focus',
      'A complete application built from motion primitives.',
      () => const DailyFocusApp(embedded: true),
      slug: 'daily-focus',
      category: 'Applications',
      source: 'example/lib/main.dart',
      instructions:
          'Complete a task, reorder the list, switch the ring, and scroll.',
      notice: 'This app keeps its original light palette.'),
  DemoEntry(
      'Your first entrance',
      'The complete declarative README quick start.',
      () => const Center(
              child: NibMotion(
            initial: NibAnim(opacity: 0, y: 24),
            animate: NibAnim(opacity: 1, y: 0),
            transition: NibTransition.springSnappy,
            child: Text('Hello, NibMotion', style: TextStyle(fontSize: 28)),
          )),
      slug: 'readme-entrance',
      category: 'Core motion',
      source: 'example/lib/readme/entrance.dart',
      instructions: 'Press Replay to see the entrance again.'),
  DemoEntry('A spring that follows state',
      'The interactive README quick start.', () => const SpringDemo(),
      slug: 'readme-spring',
      category: 'Core motion',
      source: 'example/lib/readme/retarget.dart',
      instructions: 'Tap to lift, then tap again while the button is moving.'),
];

/// Dedicated demonstrations of public APIs beyond the original test gallery.
final List<DemoEntry> featureEntries = [
  DemoEntry(
      'Text in motion',
      'Animate words, characters, and a typewriter reveal.',
      () => const ShowcaseTextScreen(),
      slug: 'text',
      category: 'Effects & shaders',
      source: 'example/lib/screens/showcase_text.dart',
      instructions:
          'Choose a text treatment, then replay to compare its timing.'),
  DemoEntry(
      'Shader studio',
      'Explore dissolve, shimmer, and liquid glass rendering.',
      () => const ShowcaseEffectsScreen(),
      slug: 'shader-studio',
      category: 'Effects & shaders',
      source: 'example/lib/screens/showcase_effects.dart',
      instructions:
          'Choose an effect and use its controls. The panel reports shader availability.',
      notice:
          'Liquid glass uses its frosted-glass fallback on Flutter web. This is not a refraction shader demonstration.'),
  DemoEntry('Follow a path', 'Move a subject along a path and draw its stroke.',
      () => const ShowcasePathsScreen(),
      slug: 'paths',
      category: 'Core motion',
      source: 'example/lib/screens/showcase_paths.dart',
      instructions:
          'Replay the marker and stroke, or pause to inspect their progress.'),
  DemoEntry(
      'Coordinated states',
      'Use shared variants, staggered children, and presets.',
      () => const ShowcaseVariantsScreen(),
      slug: 'variants',
      category: 'Timelines & orchestration',
      source: 'example/lib/screens/showcase_variants.dart',
      instructions:
          'Lift the group, replay the stagger, then trigger a preset.'),
  DemoEntry(
      'Navigation flow',
      'Coordinate destination changes with animated navigation.',
      () => const ShowcaseNavigationScreen(),
      slug: 'navigation',
      category: 'Scroll & navigation',
      source: 'example/lib/screens/showcase_navigation.dart',
      instructions:
          'Change destinations and compare fade, shared axis, and slide transitions.'),
];

/// Complete public navigation, with the original registry kept intact.
final List<DemoEntry> galleryEntries = [
  ...demoEntries,
  ...companionEntries,
  ...featureEntries
];

/// Returns a registered example, or null for an unknown URL.
DemoEntry? entryForSlug(String slug) {
  for (final entry in galleryEntries) {
    if (entry.slug == slug) return entry;
  }
  return null;
}

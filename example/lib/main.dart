// Daily Focus — a single-file Flutter demo built entirely with nib_motion.
//
// To run: copy this file's contents into the `lib/main.dart` of an app that
// depends on `nib_motion` (see this package's pubspec for the dependency),
// then `flutter run`.
//
// This screen exercises nearly every primitive nib_motion offers:
//  - NibKeyframe entrance sequences (header, FAB)
//  - NibTransition spring presets (gentle / snappy / wobbly)
//  - whileTap / whileHover / whileFocus gesture reactions
//  - whileDrag with NibDragConfig (streak badge)
//  - NibVariants for a percent <-> streak ring crossfade
//  - NibMotionList for staggered rows
//  - NibLayoutGroup (FLIP) for reordering the task list
//  - NibPresence for an enter/exit toast
//  - whileInView + NibInViewConfig for scroll-triggered task cards
//  - ScrollMotionBridge + MotionValue.mapRange for a scroll-linked
//    "scroll to top" button
//  - NibMotionController + NibMotionSequenceStep for a pulse sequence

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

void main() => runApp(const DailyFocusApp());

/// A slower, more perceptible transition for primary interactions (toggles,
/// selection, navigation) so the motion is easy to see rather than instant.
const _kSmoothTransition = NibTransition(
  spring: NibSpringDescription(mass: 1.0, stiffness: 80, damping: 14),
  duration: Duration(milliseconds: 450),
  curve: Curves.easeOutCubic,
);

/// ---------------------------------------------------------------------
/// Palette
/// ---------------------------------------------------------------------
abstract class _Palette {
  static const bg = Color(0xFFF6F1E7);
  static const ink = Color(0xFF1F1A17);
  static const inkSoft = Color(0xFF6F665F);
  static const card = Color(0xFF24211F);
  static const line = Color(0xFFE6DDCE);
  static const coral = Color(0xFFFF6B4A);
  static const mint = Color(0xFF3DDC97);
  static const lavender = Color(0xFFB9A9FF);
  static const sun = Color(0xFFFFC857);
}

/// ---------------------------------------------------------------------
/// Data model
/// ---------------------------------------------------------------------
enum _Category { health, work, study, personal }

extension on _Category {
  Color get color {
    switch (this) {
      case _Category.health:
        return _Palette.mint;
      case _Category.work:
        return _Palette.coral;
      case _Category.study:
        return _Palette.lavender;
      case _Category.personal:
        return _Palette.sun;
    }
  }

  IconData get icon {
    switch (this) {
      case _Category.health:
        return Icons.favorite_rounded;
      case _Category.work:
        return Icons.work_rounded;
      case _Category.study:
        return Icons.menu_book_rounded;
      case _Category.personal:
        return Icons.self_improvement_rounded;
    }
  }
}

class _Task {
  _Task({
    required this.id,
    required this.title,
    required this.time,
    required this.category,
    this.done = false,
  });

  final String id;
  final String title;
  final String time;
  final _Category category;
  bool done;
}

/// ---------------------------------------------------------------------
/// App shell
/// ---------------------------------------------------------------------
class DailyFocusApp extends StatelessWidget {
  const DailyFocusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily Focus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _Palette.bg,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: _Palette.coral,
          brightness: Brightness.light,
        ),
      ),
      home: const _HomeScreen(),
    );
  }
}

/// ---------------------------------------------------------------------
/// App shell — NibScaffold-based tab navigation
/// ---------------------------------------------------------------------
class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  static const _navItems = [
    NibNavItem(icon: Icon(Icons.home_rounded), tooltip: 'Home', label: 'Home'),
    NibNavItem(
        icon: Icon(Icons.calendar_today_rounded),
        tooltip: 'Calendar',
        label: 'Calendar'),
    NibNavItem(
        icon: Icon(Icons.bar_chart_rounded), tooltip: 'Stats', label: 'Stats'),
    NibNavItem(
        icon: Icon(Icons.person_rounded), tooltip: 'Profile', label: 'Profile'),
  ];

  static const _navBarStyle = NibNavBarStyle(
    backgroundColor: _Palette.card,
    activeColor: Colors.white,
    inactiveColor: Color(0x73FFFFFF), // Colors.white.withValues(alpha: 0.45)
    height: 64,
    borderRadius: BorderRadius.only(
        topRight: Radius.circular(6), topLeft: Radius.circular(6)),
  );

  static const _navIndicatorStyle = NibNavIndicatorStyle(
    type: NibNavIndicatorType.pill,
    color: Color(0x1AFFFFFF), // Colors.white.withValues(alpha: 0.1)
    borderRadius: BorderRadius.all(Radius.circular(18)),
  );

  @override
  Widget build(BuildContext context) {
    return NibScaffold(
      backgroundColor: _Palette.bg,
      screens: const [
        NibNavScreen(child: _DashboardScreen()),
        NibNavScreen(
            child: _PlaceholderScreen(
                icon: Icons.calendar_today_rounded,
                title: 'Calendar',
                subtitle: 'Your schedule will show up here.')),
        NibNavScreen(
            child: _PlaceholderScreen(
                icon: Icons.bar_chart_rounded,
                title: 'Stats',
                subtitle: 'Track your focus trends over time.')),
        NibNavScreen(
            child: _PlaceholderScreen(
                icon: Icons.person_rounded,
                title: 'Profile',
                subtitle: 'Manage your account and preferences.')),
      ],
      navItems: _navItems,
      navBarStyle: _navBarStyle,
      navIndicator: _navIndicatorStyle,
      screenTransition:
          const NibNavScreenTransition(type: NibNavTransitionType.sharedAxis),
    );
  }
}

/// ---------------------------------------------------------------------
/// Placeholder tabs — Calendar / Stats / Profile
/// ---------------------------------------------------------------------
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen(
      {required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: NibMotion(
          initial: const NibAnim(opacity: 0, y: 18, scale: 0.96),
          animate: const NibAnim(opacity: 1, y: 0, scale: 1.0),
          transition: const NibTransition(
              duration: Duration(milliseconds: 450),
              curve: Curves.easeOutCubic),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _Palette.card,
                    borderRadius: const BorderRadius.all(Radius.circular(24)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: Colors.white, size: 30),
                ),
                const SizedBox(height: 20),
                Text(title,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _Palette.ink)),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: _Palette.inkSoft),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------
/// Home / dashboard tab
/// ---------------------------------------------------------------------
class _DashboardScreen extends StatefulWidget {
  const _DashboardScreen();

  @override
  State<_DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<_DashboardScreen> {
  // ---- Day selector -----------------------------------------------------
  final List<String> _days = const [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun'
  ];
  int _selectedDay = 2; // Wednesday

  // ---- Progress ring view toggle ------------------------------------------
  String _ringView = 'percent'; // 'percent' | 'streak'
  late final NibMotionController _ringController;

  // ---- Tasks ---------------------------------------------------------------
  late List<_Task> _activeTasks;
  late List<_Task> _doneTasks;

  // ---- Toast (NibPresence) --------------------------------------------------
  String? _toastMessage;
  int _toastId = 0;
  Key? _toastKey;

  // ---- Scroll-linked scroll-to-top button -----------------------------------
  final ScrollController _scrollController = ScrollController();
  late final ScrollMotionBridge _scrollBridge;
  late final DerivedMotionValue<double, double> _scrollOpacity;
  late final DerivedMotionValue<double, double> _scrollScale;

  @override
  void initState() {
    super.initState();

    _ringController = NibMotionController();

    _activeTasks = [
      _Task(
          id: 'a1',
          title: 'Morning run — 5km',
          time: '07:00',
          category: _Category.health),
      _Task(
          id: 'a2',
          title: 'Design review meeting',
          time: '09:30',
          category: _Category.work),
      _Task(
          id: 'a3',
          title: 'Read "Atomic Habits" — ch. 4',
          time: '13:00',
          category: _Category.study),
      _Task(
          id: 'a4',
          title: 'Call mom',
          time: '18:00',
          category: _Category.personal),
    ];
    _doneTasks = [
      _Task(
          id: 'd1',
          title: 'Drink a glass of water',
          time: '06:30',
          category: _Category.health,
          done: true),
    ];

    _scrollBridge = ScrollMotionBridge(controller: _scrollController);
    _scrollOpacity = _scrollBridge.scrollY.mapRange([80, 200], [0.0, 1.0]);
    _scrollScale = _scrollBridge.scrollY.mapRange([80, 200], [0.6, 1.0]);
  }

  @override
  void dispose() {
    _ringController.dispose();
    _scrollOpacity.dispose();
    _scrollScale.dispose();
    _scrollBridge.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  void _toggleTask(_Task task) {
    setState(() {
      task.done = !task.done;
      if (task.done) {
        _activeTasks.removeWhere((t) => t.id == task.id);
        _doneTasks.insert(0, task);
        _showToast('Nice work — "${task.title}" complete!');
      } else {
        _doneTasks.removeWhere((t) => t.id == task.id);
        _activeTasks.add(task);
      }
    });

    // Pulse the progress ring whenever completion state changes.
    _ringController.sequence([
      NibMotionSequenceStep(
          target: const NibAnim(scale: 1.2),
          transition: NibTransition.springWobbly),
      NibMotionSequenceStep(
          target: const NibAnim(scale: 1.0), transition: _kSmoothTransition),
    ]);
  }

  void _showToast(String message) {
    _toastId++;
    final id = _toastId;
    setState(() {
      _toastMessage = message;
      _toastKey = ValueKey('toast-$id');
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted || _toastId != id) return;
      setState(() => _toastMessage = null);
    });
  }

  void _addQuickTask() {
    final id = 'a${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      _activeTasks.add(
        _Task(
            id: id,
            title: 'New focus task',
            time: 'Anytime',
            category: _Category.personal),
      );
    });
    _showToast('Task added to your list');
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final totalTasks = _activeTasks.length + _doneTasks.length;
    final progress = totalTasks == 0 ? 0.0 : _doneTasks.length / totalTasks;

    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: NotificationListener<ScrollNotification>(
            onNotification: (_) => false,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 22),
                  _buildDaySelector(),
                  const SizedBox(height: 20),
                  _buildProgressCard(progress),
                  const SizedBox(height: 24),
                  _buildQuickStats(),
                  const SizedBox(height: 28),
                  _buildSectionHeader(
                      'Today\'s Focus', '${_activeTasks.length} left'),
                  const SizedBox(height: 12),
                  _buildTaskList(),
                  if (_doneTasks.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    _buildSectionHeader(
                        'Completed', '${_doneTasks.length} done'),
                    const SizedBox(height: 12),
                    _buildCompletedList(),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Scroll-to-top button, driven entirely by scroll position.
        _buildScrollToTop(),

        // Toast notification.
        Positioned(
          left: 20,
          right: 20,
          bottom: 24,
          child: _buildToast(),
        ),

        // Floating action button.
        Positioned(
          right: 20,
          bottom: 24,
          child: _buildFab(),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Header — NibKeyframe entrance
  // -------------------------------------------------------------------------
  Widget _buildHeader() {
    return NibMotion(
      keyframes: const [
        NibKeyframe(at: 0.0, value: NibAnim(opacity: 0, y: -24)),
        NibKeyframe(at: 1.0, value: NibAnim(opacity: 1, y: 0)),
      ],
      transition: const NibTransition(
          duration: Duration(milliseconds: 700), curve: Curves.easeOutCubic),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good morning,',
                  style: TextStyle(
                      fontSize: 15,
                      color: _Palette.inkSoft,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  'Alex Carter',
                  style: TextStyle(
                      fontSize: 26,
                      color: _Palette.ink,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5),
                ),
              ],
            ),
          ),
          NibMotion(
            whileTap: const NibAnim(scale: 0.88),
            whileHover: const NibAnim(scale: 1.1),
            transition: _kSmoothTransition,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _Palette.card,
                borderRadius: BorderRadius.all(Radius.circular(18)),
              ),
              alignment: Alignment.center,
              child: const Text('AC',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Day selector — manually staggered entrance + spring selection
  // -------------------------------------------------------------------------
  Widget _buildDaySelector() {
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final selected = index == _selectedDay;
          return NibMotion(
            initial: const NibAnim(opacity: 0, y: 24),
            animate: const NibAnim(opacity: 1, y: 0),
            transition: NibTransition(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              delay: Duration(milliseconds: 70 * index),
            ),
            child: NibMotion(
              initial: selected
                  ? const NibAnim(
                      scale: 1.0,
                      color: _Palette.card,
                      borderRadius: BorderRadius.all(Radius.circular(18)))
                  : const NibAnim(
                      scale: 1.0,
                      color: _Palette.bg,
                      borderRadius: BorderRadius.all(Radius.circular(18))),
              animate: selected
                  ? const NibAnim(
                      scale: 1.0,
                      color: _Palette.card,
                      borderRadius: BorderRadius.all(Radius.circular(18)))
                  : const NibAnim(
                      scale: 1.0,
                      color: _Palette.bg,
                      borderRadius: BorderRadius.all(Radius.circular(18))),
              whileTap: const NibAnim(scale: 0.9),
              transition: _kSmoothTransition,
              child: GestureDetector(
                onTap: () => setState(() => _selectedDay = index),
                child: Container(
                  width: 54,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: selected ? Colors.transparent : _Palette.line),
                    borderRadius: BorderRadius.all(Radius.circular(18)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _days[index],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white70 : _Palette.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${12 + index}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : _Palette.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Progress card — entrance, hover/tap, drag, variant crossfade ring
  // -------------------------------------------------------------------------
  Widget _buildProgressCard(double progress) {
    return NibMotion(
      initial: const NibAnim(opacity: 0, y: 28, scale: 0.96),
      animate: const NibAnim(opacity: 1, y: 0, scale: 1.0),
      transition: const NibTransition(
          duration: Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
          delay: Duration(milliseconds: 150)),
      child: NibMotion(
        whileHover: const NibAnim(scale: 1.02),
        whileTap: const NibAnim(scale: 0.97),
        transition: _kSmoothTransition,
        controller: _ringController,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _Palette.card,
            borderRadius: BorderRadius.all(Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                  color: _Palette.ink.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 12)),
            ],
          ),
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Daily Progress',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_doneTasks.length} of ${_activeTasks.length + _doneTasks.length} tasks done',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13),
                        ),
                        const SizedBox(height: 18),
                        NibMotion(
                          whileTap: const NibAnim(scale: 0.9),
                          transition: NibTransition.springSnappy,
                          child: GestureDetector(
                            onTap: () => setState(() => _ringView =
                                _ringView == 'percent' ? 'streak' : 'percent'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius:
                                    BorderRadius.all(Radius.circular(14)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.swap_horiz_rounded,
                                      color:
                                          Colors.white.withValues(alpha: 0.8),
                                      size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    _ringView == 'percent'
                                        ? 'View streak'
                                        : 'View progress',
                                    style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.8),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  _buildProgressRing(progress),
                ],
              ),
              Positioned(top: -6, right: 86, child: _buildStreakBadge()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressRing(double progress) {
    const ringPercentVariants = <String, NibAnim>{
      'percent': NibAnim(opacity: 1, scale: 1.0),
      'streak': NibAnim(opacity: 0, scale: 0.7),
    };
    const ringStreakVariants = <String, NibAnim>{
      'percent': NibAnim(opacity: 0, scale: 0.7),
      'streak': NibAnim(opacity: 1, scale: 1.0),
    };

    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return CustomPaint(
                size: const Size(96, 96),
                painter: _RingPainter(
                    progress: value,
                    color: _Palette.mint,
                    track: Colors.white.withValues(alpha: 0.1)),
              );
            },
          ),
          NibMotion(
            initial: 'percent',
            animate: _ringView,
            variants: ringPercentVariants,
            transition: _kSmoothTransition,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${(progress * 100).round()}%',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('today',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11)),
              ],
            ),
          ),
          NibMotion(
            initial: 'percent',
            animate: _ringView,
            variants: ringStreakVariants,
            transition: _kSmoothTransition,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_fire_department_rounded,
                    color: _Palette.sun, size: 22),
                const SizedBox(height: 2),
                Text('12 days',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakBadge() {
    return NibMotion(
      initial: const NibAnim(opacity: 0, scale: 0.5),
      animate: const NibAnim(opacity: 1, scale: 1.0),
      transition: const NibTransition(
          spring: NibSpringDescription.wobbly,
          delay: Duration(milliseconds: 400)),
      child: NibMotion(
        whileDrag: const NibAnim(scale: 1.15),
        drag: const NibDragConfig(
          elastic: true,
          elasticFactor: 0.5,
          releaseMode: NibDragReleaseMode.springBack,
        ),
        transition: NibTransition.springWobbly,
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: _Palette.sun,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.bolt_rounded, color: _Palette.ink, size: 18),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Quick stats — NibMotionList staggered row
  // -------------------------------------------------------------------------
  Widget _buildQuickStats() {
    final stats = [
      ('Focus time', '3h 20m', Icons.timer_rounded, _Palette.coral),
      (
        'Tasks left',
        '${_activeTasks.length}',
        Icons.checklist_rounded,
        _Palette.lavender
      ),
      ('Streak', '12 days', Icons.local_fire_department_rounded, _Palette.sun),
    ];

    return Row(
      children: List.generate(stats.length, (index) {
        final (label, value, icon, color) = stats[index];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == stats.length - 1 ? 0 : 10),
            child: NibMotion(
              initial: const NibAnim(opacity: 0, y: 18, scale: 0.95),
              animate: const NibAnim(opacity: 1, y: 0, scale: 1.0),
              transition: NibTransition(
                duration: const Duration(milliseconds: 480),
                curve: Curves.easeOutCubic,
                delay: Duration(milliseconds: 90 * index),
              ),
              child: NibMotion(
                whileHover: const NibAnim(y: -6),
                whileTap: const NibAnim(scale: 0.96),
                transition: _kSmoothTransition,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                    border: Border.all(color: _Palette.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.16),
                            borderRadius:
                                BorderRadius.all(Radius.circular(10))),
                        alignment: Alignment.center,
                        child: Icon(icon, color: color, size: 17),
                      ),
                      const SizedBox(height: 12),
                      Text(value,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _Palette.ink)),
                      const SizedBox(height: 2),
                      Text(label,
                          style: TextStyle(
                              fontSize: 11,
                              color: _Palette.inkSoft,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // -------------------------------------------------------------------------
  // Section header
  // -------------------------------------------------------------------------
  Widget _buildSectionHeader(String title, String trailing) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _Palette.ink)),
        Text(trailing,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _Palette.inkSoft)),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Task list — NibLayoutGroup (FLIP) + whileInView entrance per card
  // -------------------------------------------------------------------------
  Widget _buildTaskList() {
    if (_activeTasks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('All clear! Add a new task with the + button.',
              style: TextStyle(color: _Palette.inkSoft, fontSize: 13)),
        ),
      );
    }

    return NibLayoutGroup(
      transition: _kSmoothTransition,
      children: [
        for (final task in _activeTasks)
          Padding(
            key: ValueKey(task.id),
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildTaskCard(task),
          ),
      ],
    );
  }

  Widget _buildCompletedList() {
    return NibLayoutGroup(
      transition: _kSmoothTransition,
      children: [
        for (final task in _doneTasks)
          Padding(
            key: ValueKey(task.id),
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildTaskCard(task),
          ),
      ],
    );
  }

  Widget _buildTaskCard(_Task task) {
    return NibMotion(
      whileInView: const NibAnim(opacity: 1, x: 0),
      initial: const NibAnim(opacity: 0, x: 28),
      viewport: const NibInViewConfig(amount: 0.2, once: true),
      transition: const NibTransition(
          duration: Duration(milliseconds: 420), curve: Curves.easeOutCubic),
      child: NibMotion(
        initial: task.done
            ? const NibAnim(
                color: _Palette.bg,
                boxShadow: [],
                borderRadius: BorderRadius.all(Radius.circular(20)))
            : NibAnim(
                color: Colors.white,
                borderRadius: const BorderRadius.all(Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                      color: _Palette.ink.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ],
              ),
        animate: task.done
            ? const NibAnim(
                color: _Palette.bg,
                boxShadow: [],
                borderRadius: BorderRadius.all(Radius.circular(20)),
              )
            : NibAnim(
                color: Colors.white,
                borderRadius: const BorderRadius.all(Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                      color: _Palette.ink.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ],
              ),
        transition: _kSmoothTransition,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(20)),
            border: Border.all(color: _Palette.line),
          ),
          child: Row(
            children: [
              _buildCheckbox(task),
              const SizedBox(width: 12),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: task.category.color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.all(Radius.circular(12))),
                alignment: Alignment.center,
                child: Icon(task.category.icon,
                    color: task.category.color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: task.done ? _Palette.inkSoft : _Palette.ink,
                        decoration: task.done
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(task.time,
                        style:
                            TextStyle(fontSize: 12, color: _Palette.inkSoft)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox(_Task task) {
    // NOTE: the tappable GestureDetector must be the innermost widget (a
    // descendant of the whileTap-driving NibMotion), not its ancestor —
    // otherwise NibMotion's own internal tap recognizer wins the gesture
    // arena and this GestureDetector's onTap never fires.
    return NibMotion(
      whileTap: const NibAnim(scale: 0.8),
      initial: task.done
          ? const NibAnim(
              color: _Palette.mint,
              scale: 1.0,
              borderRadius: BorderRadius.all(Radius.circular(15)))
          : const NibAnim(
              color: Colors.white,
              scale: 1.0,
              borderRadius: BorderRadius.all(Radius.circular(15))),
      animate: task.done
          ? const NibAnim(
              color: _Palette.mint,
              scale: 1.0,
              borderRadius: BorderRadius.all(Radius.circular(15)))
          : const NibAnim(
              color: Colors.white,
              scale: 1.0,
              borderRadius: BorderRadius.all(Radius.circular(15))),
      transition: _kSmoothTransition,
      child: GestureDetector(
        onTap: () => _toggleTask(task),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: task.done ? Colors.transparent : _Palette.line,
                width: 2),
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale:
                  CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: task.done
                ? const Icon(Icons.check_rounded,
                    color: Colors.white, size: 18, key: ValueKey('checked'))
                : const SizedBox.shrink(key: ValueKey('unchecked')),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // FAB — keyframe entrance + tap/hover/focus
  // -------------------------------------------------------------------------
  Widget _buildFab() {
    return NibMotion(
      keyframes: const [
        NibKeyframe(
            at: 0.0, value: NibAnim(opacity: 0, scale: 0.4, rotate: -0.5)),
        NibKeyframe(
            at: 0.7, value: NibAnim(opacity: 1, scale: 1.1, rotate: 0.05)),
        NibKeyframe(at: 1.0, value: NibAnim(opacity: 1, scale: 1.0, rotate: 0)),
      ],
      transition: const NibTransition(
          duration: Duration(milliseconds: 800),
          curve: Curves.easeOutBack,
          delay: Duration(milliseconds: 350)),
      child: NibMotion(
        whileTap: const NibAnim(scale: 0.85),
        whileHover: const NibAnim(scale: 1.15, y: -4),
        whileFocus: NibAnim(
          borderRadius: const BorderRadius.all(Radius.circular(29)),
          boxShadow: [
            BoxShadow(
                color: _Palette.coral.withValues(alpha: 0.5),
                blurRadius: 0,
                spreadRadius: 4)
          ],
        ),
        transition: _kSmoothTransition,
        child: GestureDetector(
          onTap: _addQuickTask,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _Palette.coral,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: _Palette.coral.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 8))
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Scroll-to-top — externally driven motionValues from ScrollMotionBridge
  // -------------------------------------------------------------------------
  Widget _buildScrollToTop() {
    return Positioned(
      right: 20,
      bottom: 160,
      child: NibMotion(
        motionValues: NibMotionValues(
          opacity: _scrollOpacity,
          scaleX: _scrollScale,
          scaleY: _scrollScale,
        ),
        child: NibMotion(
          whileTap: const NibAnim(y: 2),
          whileHover: const NibAnim(y: -2),
          transition: NibTransition.springSnappy,
          child: GestureDetector(
            onTap: () => _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
            ),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _Palette.card,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: _Palette.ink.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 6))
                ],
              ),
              child: const Icon(Icons.arrow_upward_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Toast — NibPresence enter/exit
  // -------------------------------------------------------------------------
  Widget _buildToast() {
    return NibPresence(
      children: [
        if (_toastMessage != null)
          NibMotion(
            key: _toastKey,
            initial: const NibAnim(opacity: 0, y: 24, scale: 0.95),
            animate: const NibAnim(opacity: 1, y: 0, scale: 1.0),
            exit: const NibAnim(opacity: 0, y: 24, scale: 0.95),
            transition: NibTransition.springGentle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: _Palette.card,
                borderRadius: BorderRadius.all(Radius.circular(18)),
                boxShadow: [
                  BoxShadow(
                      color: _Palette.ink.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 8))
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: _Palette.mint, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _toastMessage!,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------
/// Progress ring painter
/// ---------------------------------------------------------------------
class _RingPainter extends CustomPainter {
  _RingPainter(
      {required this.progress, required this.color, required this.track});

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.track != track;
  }
}

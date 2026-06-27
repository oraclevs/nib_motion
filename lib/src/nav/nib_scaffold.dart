import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter/widgets.dart';

import 'nib_nav_bar.dart';
import 'nib_nav_item.dart';
import 'nib_nav_style.dart';
import 'nib_nav_transition.dart';
import 'nib_screen_stack.dart';

/// The edge of a [NibScaffold] that its [NibNavBar] is docked to.
enum NibNavBarPosition {
  /// The nav bar is docked to the bottom edge (the default).
  bottom,

  /// The nav bar is docked to the top edge.
  top,
}

/// A top-level, tab-based app shell that composes [NibScreenStack] and
/// [NibNavBar].
///
/// `NibScaffold` owns the active tab index: tapping a [NibNavBar] item calls
/// [_NibScaffoldState._onIndexChanged], which is the only `setState` in the
/// whole `NibBottomNav` system — everything else (the indicator, per-item
/// scales, and screen transitions) is driven by [MotionValue]s and
/// [NibMotionController]s.
class NibScaffold extends StatefulWidget {
  /// Creates a scaffold.
  ///
  /// [screens] and [navItems] must have the same length.
  const NibScaffold({
    super.key,
    required this.screens,
    required this.navItems,
    this.initialIndex = 0,
    this.onIndexChanged,
    this.navBarStyle,
    this.navIndicator,
    this.itemAnimation,
    this.screenTransition = const NibNavScreenTransition(),
    this.floatingActionButton,
    this.navBarPosition = NibNavBarPosition.bottom,
    this.extendBodyBehindNavBar = false,
    this.backgroundColor,
    this.useMaterialScaffold = false,
  }) : assert(
          screens.length == navItems.length,
          'NibScaffold: screens and navItems must have the same length.',
        );

  /// The screens managed by the underlying [NibScreenStack], one per
  /// [navItems] entry.
  final List<NibNavScreen> screens;

  /// The tabs shown in the [NibNavBar], one per [screens] entry.
  final List<NibNavItem> navItems;

  /// The initially active tab index.
  final int initialIndex;

  /// Called whenever the active tab changes, with the new index.
  final ValueChanged<int>? onIndexChanged;

  /// The visual style of the [NibNavBar]. Defaults to [NibNavBarStyle.standard].
  final NibNavBarStyle? navBarStyle;

  /// The visual style of the [NibNavBar]'s active-item indicator.
  final NibNavIndicatorStyle? navIndicator;

  /// Per-item tap/active animation configuration for the [NibNavBar].
  final NibNavItemAnimation? itemAnimation;

  /// The transition played by [NibScreenStack] when the active tab changes.
  final NibNavScreenTransition screenTransition;

  /// An optional floating action button overlaid on top of the screens.
  final Widget? floatingActionButton;

  /// Which edge the [NibNavBar] is docked to.
  final NibNavBarPosition navBarPosition;

  /// Whether [NibScreenStack] extends full-bleed under/behind the [NibNavBar].
  ///
  /// `false` (the default): the screen content is inset by the nav bar's
  /// height (plus [NibNavBarStyle.margin]) — the same "reserved space" layout
  /// as a non-floating bar. The reserved area is painted by
  /// [backgroundColor] (or left transparent if null).
  ///
  /// `true`: the content has no inset and extends behind the floating
  /// [NibNavBar]. Combined with a [NibNavBarStyle.backgroundColor] with
  /// `alpha < 255`, this produces a "glass" bar that the content scrolls
  /// behind.
  final bool extendBodyBehindNavBar;

  /// The background color behind the screens.
  final Color? backgroundColor;

  /// Whether to wrap the layout in a Material [Scaffold], for its keyboard
  /// avoidance, [floatingActionButton] placement, and other Material
  /// behaviors. Defaults to `false`.
  final bool useMaterialScaffold;

  @override
  State<NibScaffold> createState() => _NibScaffoldState();
}

class _NibScaffoldState extends State<NibScaffold> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onIndexChanged(int index) {
    if (index != _currentIndex) {
      setState(() => _currentIndex = index);
    }
    widget.onIndexChanged?.call(index);
  }

  Widget _buildNavBar() {
    return NibNavBar(
      items: widget.navItems,
      currentIndex: _currentIndex,
      onIndexChanged: _onIndexChanged,
      style: widget.navBarStyle ?? NibNavBarStyle.standard,
      indicator: widget.navIndicator ?? const NibNavIndicatorStyle(),
      itemAnimation: widget.itemAnimation ?? const NibNavItemAnimation(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navBarStyle = widget.navBarStyle ?? NibNavBarStyle.standard;
    final isBottom = widget.navBarPosition == NibNavBarPosition.bottom;
    final navBarHeight = navBarStyle.height + navBarStyle.margin.vertical;

    final contentInset = widget.extendBodyBehindNavBar
        ? EdgeInsets.zero
        : EdgeInsets.only(
            top: isBottom ? 0 : navBarHeight,
            bottom: isBottom ? navBarHeight : 0,
          );

    final stack = Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: contentInset,
            child: NibScreenStack(
              screens: widget.screens,
              currentIndex: _currentIndex,
              screenTransition: widget.screenTransition,
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: isBottom ? null : 0,
          bottom: isBottom ? 0 : null,
          child: _buildNavBar(),
        ),
      ],
    );

    if (widget.useMaterialScaffold) {
      return Scaffold(
        backgroundColor: widget.backgroundColor,
        floatingActionButton: widget.floatingActionButton,
        body: stack,
      );
    }

    final backgroundColor = widget.backgroundColor;
    final background = backgroundColor == null
        ? stack
        : ColoredBox(color: backgroundColor, child: stack);

    final fab = widget.floatingActionButton;
    if (fab == null) return background;

    return Stack(
      children: [
        background,
        Positioned(
          right: 16,
          bottom: isBottom ? navBarHeight + 16 : 16,
          child: fab,
        ),
      ],
    );
  }
}

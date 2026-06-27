import 'package:flutter/widgets.dart';

/// One tab in a `NibNavBar` or `NibScaffold`.
@immutable
class NibNavItem {
  /// Creates a navigation item.
  const NibNavItem({
    required this.icon,
    this.activeIcon,
    this.label,
    this.badge,
    this.tooltip,
  });

  /// Icon shown when this item is inactive.
  final Widget icon;

  /// Icon shown when this item is active. Falls back to [icon] when null.
  final Widget? activeIcon;

  /// Label shown below the icon.
  final String? label;

  /// Optional badge overlaid on the icon.
  final NibNavBadge? badge;

  /// Accessibility tooltip for this item.
  final String? tooltip;

  /// Returns a copy of this item with the given fields replaced.
  NibNavItem copyWith({
    Widget? icon,
    Widget? activeIcon,
    String? label,
    NibNavBadge? badge,
    String? tooltip,
  }) {
    return NibNavItem(
      icon: icon ?? this.icon,
      activeIcon: activeIcon ?? this.activeIcon,
      label: label ?? this.label,
      badge: badge ?? this.badge,
      tooltip: tooltip ?? this.tooltip,
    );
  }
}

/// Optional badge overlay on a [NibNavItem].
@immutable
class NibNavBadge {
  /// Creates a badge.
  ///
  /// [count] of `null` renders a dot badge, `0` hides the badge entirely,
  /// and a positive value renders a numeric badge (capped at `"99+"`).
  const NibNavBadge({this.count, this.color, this.textColor});

  /// The badge count. `null` renders a dot badge, `0` hides the badge, and
  /// `N` shows the count (capped at `"99+"`).
  final int? count;

  /// Badge background color. Defaults to red when null.
  final Color? color;

  /// Badge text color. Defaults to white when null.
  final Color? textColor;

  /// Returns a copy of this badge with the given fields replaced.
  NibNavBadge copyWith({int? count, Color? color, Color? textColor}) {
    return NibNavBadge(
      count: count ?? this.count,
      color: color ?? this.color,
      textColor: textColor ?? this.textColor,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NibNavBadge &&
        other.count == count &&
        other.color == color &&
        other.textColor == textColor;
  }

  @override
  int get hashCode => Object.hash(count, color, textColor);
}

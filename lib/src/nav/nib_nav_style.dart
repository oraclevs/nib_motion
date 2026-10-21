import 'package:flutter/widgets.dart';

import '../core/nib_anim.dart';
import '../core/nib_transition.dart';
import '../physics/spring_description.dart';

/// Visual appearance of a `NibNavBar`'s container.
@immutable
class NibNavBarStyle {
  /// Creates a navigation bar style.
  const NibNavBarStyle({
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.activeColor = const Color(0xFF02569B),
    this.inactiveColor = const Color(0xFF64748B),
    this.height = 64,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.elevation = 0,
    this.borderRadius,
    this.border,
    this.iconSize = 24,
    this.labelStyle,
    this.glass = false,
    this.glassTint,
    this.glassBlur = 8,
    this.glassHighlight = 0.7,
  });

  /// The standard light-mode style used when no style is supplied.
  static const NibNavBarStyle standard = NibNavBarStyle();

  /// Background color of the navigation bar.
  final Color backgroundColor;

  /// Icon and label color when an item is active.
  final Color activeColor;

  /// Icon and label color when an item is inactive.
  final Color inactiveColor;

  /// Total height of the bar, including [padding].
  final double height;

  /// Padding applied around the bar's content.
  final EdgeInsets padding;

  /// Space reserved outside the bar — e.g. to float it above the screen
  /// edge or inset it from the sides. Defaults to [EdgeInsets.zero] (the bar
  /// spans the full width/height given to it, as before).
  final EdgeInsets margin;

  /// Shadow elevation drawn above the bar.
  final double elevation;

  /// Corner radius applied to the bar, typically the top corners for a
  /// floating style.
  final BorderRadius? borderRadius;

  /// Border drawn around the bar, typically a top border line.
  final Border? border;

  /// Size of each item's icon.
  final double iconSize;

  /// Text style applied to each item's label.
  final TextStyle? labelStyle;

  /// Whether the bar's background is rendered as a `NibGlass` liquid-glass
  /// surface (the content scrolls behind it, refracted) instead of a flat
  /// [backgroundColor] fill. Pair with `extendBodyBehindNavBar: true` on a
  /// `NibScaffold` so there is something to refract.
  final bool glass;

  /// Tint of the glass surface when [glass] is `true`. Defaults to a light
  /// white sheen.
  final Color? glassTint;

  /// Backdrop blur of the glass surface when [glass] is `true`.
  final double glassBlur;

  /// Specular highlight intensity of the glass surface when [glass] is `true`.
  final double glassHighlight;

  /// Returns a copy of this style with the given fields replaced.
  NibNavBarStyle copyWith({
    Color? backgroundColor,
    Color? activeColor,
    Color? inactiveColor,
    double? height,
    EdgeInsets? padding,
    EdgeInsets? margin,
    double? elevation,
    BorderRadius? borderRadius,
    Border? border,
    double? iconSize,
    TextStyle? labelStyle,
    bool? glass,
    Color? glassTint,
    double? glassBlur,
    double? glassHighlight,
  }) {
    return NibNavBarStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      activeColor: activeColor ?? this.activeColor,
      inactiveColor: inactiveColor ?? this.inactiveColor,
      height: height ?? this.height,
      padding: padding ?? this.padding,
      margin: margin ?? this.margin,
      elevation: elevation ?? this.elevation,
      borderRadius: borderRadius ?? this.borderRadius,
      border: border ?? this.border,
      iconSize: iconSize ?? this.iconSize,
      labelStyle: labelStyle ?? this.labelStyle,
      glass: glass ?? this.glass,
      glassTint: glassTint ?? this.glassTint,
      glassBlur: glassBlur ?? this.glassBlur,
      glassHighlight: glassHighlight ?? this.glassHighlight,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NibNavBarStyle &&
        other.backgroundColor == backgroundColor &&
        other.activeColor == activeColor &&
        other.inactiveColor == inactiveColor &&
        other.height == height &&
        other.padding == padding &&
        other.margin == margin &&
        other.elevation == elevation &&
        other.borderRadius == borderRadius &&
        other.border == border &&
        other.iconSize == iconSize &&
        other.labelStyle == labelStyle &&
        other.glass == glass &&
        other.glassTint == glassTint &&
        other.glassBlur == glassBlur &&
        other.glassHighlight == glassHighlight;
  }

  @override
  int get hashCode => Object.hash(
        backgroundColor,
        activeColor,
        inactiveColor,
        height,
        padding,
        margin,
        elevation,
        borderRadius,
        border,
        iconSize,
        labelStyle,
        glass,
        glassTint,
        glassBlur,
        glassHighlight,
      );
}

/// The visual style of the active-item indicator drawn by a `NibNavBar`.
enum NibNavIndicatorType {
  /// A flowing water lens with a trailing lobe, ripples and specular light.
  /// Uses a fragment shader where available and a gradient lens otherwise.
  /// Motion stops at rest and respects the reduced-motion preference.
  liquid,

  /// A rounded-rect "pill" drawn behind the active item's icon/label.
  pill,

  /// A small dot drawn below the active item.
  dot,

  /// A thin line drawn along the top edge of the active item.
  line,

  /// A full-height highlight rect drawn behind the active item.
  highlight,

  /// No indicator is drawn.
  none,
}

/// The visual indicator that moves between active items in a `NibNavBar`.
@immutable
class NibNavIndicatorStyle {
  /// Creates an indicator style.
  const NibNavIndicatorStyle({
    this.type = NibNavIndicatorType.pill,
    this.color,
    this.height,
    this.width,
    this.borderRadius,
    this.spring = NibSpringDescription.snappy,
  });

  /// An indicator style that draws nothing.
  static const NibNavIndicatorStyle none = NibNavIndicatorStyle(
    type: NibNavIndicatorType.none,
  );

  /// The shape of the indicator.
  final NibNavIndicatorType type;

  /// The indicator's color. Defaults to a tinted [NibNavBarStyle.activeColor]
  /// when null.
  final Color? color;

  /// The indicator's height, for [NibNavIndicatorType.pill],
  /// [NibNavIndicatorType.highlight], and [NibNavIndicatorType.line].
  final double? height;

  /// The indicator's width, for [NibNavIndicatorType.pill] and
  /// [NibNavIndicatorType.highlight]. When null, the width is proportional
  /// to the active item's width.
  final double? width;

  /// Corner radius applied to the indicator shape.
  final BorderRadius? borderRadius;

  /// The spring physics used to animate the indicator between items.
  final NibSpringDescription spring;

  /// Returns a copy of this style with the given fields replaced.
  NibNavIndicatorStyle copyWith({
    NibNavIndicatorType? type,
    Color? color,
    double? height,
    double? width,
    BorderRadius? borderRadius,
    NibSpringDescription? spring,
  }) {
    return NibNavIndicatorStyle(
      type: type ?? this.type,
      color: color ?? this.color,
      height: height ?? this.height,
      width: width ?? this.width,
      borderRadius: borderRadius ?? this.borderRadius,
      spring: spring ?? this.spring,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NibNavIndicatorStyle &&
        other.type == type &&
        other.color == color &&
        other.height == height &&
        other.width == width &&
        other.borderRadius == borderRadius &&
        other.spring == spring;
  }

  @override
  int get hashCode =>
      Object.hash(type, color, height, width, borderRadius, spring);
}

/// Per-item animation configuration for a `NibNavBar`.
@immutable
class NibNavItemAnimation {
  /// Creates a per-item animation configuration.
  const NibNavItemAnimation({
    this.whileTap = const NibAnim(scale: 0.85),
    this.whileActive = const NibAnim(scale: 1.1),
    this.tapTransition = NibTransition.springSnappy,
  });

  /// No per-item animations.
  static const NibNavItemAnimation none = NibNavItemAnimation(
    whileTap: null,
    whileActive: null,
  );

  /// Animation applied to an item while the user presses it.
  final NibAnim? whileTap;

  /// Animation applied to the active item's icon.
  final NibAnim? whileActive;

  /// The transition used for [whileTap] and [whileActive] animations.
  final NibTransition tapTransition;

  /// Returns a copy of this configuration with the given fields replaced.
  NibNavItemAnimation copyWith({
    NibAnim? whileTap,
    NibAnim? whileActive,
    NibTransition? tapTransition,
  }) {
    return NibNavItemAnimation(
      whileTap: whileTap ?? this.whileTap,
      whileActive: whileActive ?? this.whileActive,
      tapTransition: tapTransition ?? this.tapTransition,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NibNavItemAnimation &&
        other.whileTap == whileTap &&
        other.whileActive == whileActive &&
        other.tapTransition == tapTransition;
  }

  @override
  int get hashCode => Object.hash(whileTap, whileActive, tapTransition);
}

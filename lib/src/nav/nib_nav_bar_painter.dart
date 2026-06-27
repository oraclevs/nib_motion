import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';

import '../values/motion_value.dart';
import 'nib_nav_item.dart';
import 'nib_nav_style.dart';

/// Paints the background, active-item indicator, and item labels of a
/// `NibNavBar`. Icons are rendered as real widgets (see `NibNavBar.build`),
/// not by this painter — see that class's doc comment for why.
///
/// Repaint is driven entirely by the [MotionValue]s passed to
/// `super(repaint: ...)` — since [MotionValue] extends `ChangeNotifier`
/// (which implements `Listenable`), changes to the indicator position or
/// per-item scale call `markNeedsPaint()` directly with no widget rebuild or
/// `AnimatedBuilder` involved.
class NibNavBarPainter extends CustomPainter {
  /// Creates a navigation bar painter.
  NibNavBarPainter({
    required this.items,
    required this.currentIndex,
    required this.style,
    required this.indicator,
    required this.indicatorX,
    required this.indicatorWidth,
    required this.indicatorHeight,
    required this.indicatorOpacity,
    required this.itemScales,
    required this.itemOpacities,
  }) : super(
         repaint: Listenable.merge(<Listenable>[
           indicatorX,
           indicatorWidth,
           indicatorHeight,
           indicatorOpacity,
           ...itemScales,
           ...itemOpacities,
         ]),
       );

  /// The tabs to draw.
  final List<NibNavItem> items;

  /// The index of the currently active tab.
  final int currentIndex;

  /// The visual style of the bar's container.
  final NibNavBarStyle style;

  /// The visual style of the active-item indicator.
  final NibNavIndicatorStyle indicator;

  /// Left edge of the indicator, in pixels.
  final MotionValue<double> indicatorX;

  /// Current width of the indicator, in pixels.
  final MotionValue<double> indicatorWidth;

  /// Current height of the indicator, in pixels.
  final MotionValue<double> indicatorHeight;

  /// Current opacity of the indicator, from `0.0` to `1.0`.
  final MotionValue<double> indicatorOpacity;

  /// Per-item icon scale, one entry per item in [items].
  final List<MotionValue<double>> itemScales;

  /// Per-item "active tint" opacity, one entry per item in [items].
  final List<MotionValue<double>> itemOpacities;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _backgroundPath(size);
    _paintBackground(canvas, size, path);

    canvas.save();
    canvas.clipPath(path);
    _paintIndicator(canvas, size);
    _paintItems(canvas, size);
    _paintBadges(canvas, size);
    canvas.restore();
  }

  /// The bar's outline — a rounded rect when [NibNavBarStyle.borderRadius]
  /// is set, otherwise the full [size] rect. Used both to fill the
  /// background and to clip the indicator/items/badges so they respect the
  /// bar's corners.
  Path _backgroundPath(Size size) {
    final rect = Offset.zero & size;
    final path = Path();
    if (style.borderRadius != null) {
      path.addRRect(RRect.fromRectAndCorners(
        rect,
        topLeft: style.borderRadius!.topLeft,
        topRight: style.borderRadius!.topRight,
        bottomLeft: style.borderRadius!.bottomLeft,
        bottomRight: style.borderRadius!.bottomRight,
      ));
    } else {
      path.addRect(rect);
    }
    return path;
  }

  void _paintBackground(Canvas canvas, Size size, Path path) {
    if (style.elevation > 0) {
      canvas.drawShadow(path, const Color(0xFF000000), style.elevation, false);
    }

    canvas.drawPath(path, Paint()..color = style.backgroundColor);

    final border = style.border;
    if (border != null && border.top.width > 0) {
      final paint = Paint()
        ..color = border.top.color
        ..strokeWidth = border.top.width
        ..style = PaintingStyle.stroke;
      final y = border.top.width / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _paintIndicator(Canvas canvas, Size size) {
    switch (indicator.type) {
      case NibNavIndicatorType.none:
        return;

      case NibNavIndicatorType.pill:
      case NibNavIndicatorType.highlight:
        final baseColor =
            indicator.color ?? _withAlpha(style.activeColor, 0.12);
        final paint = Paint()
          ..color = _scaleAlpha(baseColor, indicatorOpacity.value.clamp(0.0, 1.0));
        final height = indicatorHeight.value;
        final yCenter = size.height / 2;
        final rect = Rect.fromLTWH(
          indicatorX.value,
          yCenter - height / 2,
          indicatorWidth.value,
          height,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect,
            indicator.borderRadius?.topLeft ?? const Radius.circular(100),
          ),
          paint,
        );

      case NibNavIndicatorType.line:
        final baseColor = indicator.color ?? style.activeColor;
        final paint = Paint()
          ..color = _scaleAlpha(baseColor, indicatorOpacity.value.clamp(0.0, 1.0));
        final thickness = indicatorHeight.value > 0
            ? indicatorHeight.value
            : 3.0;
        canvas.drawRect(
          Rect.fromLTWH(indicatorX.value, 0, indicatorWidth.value, thickness),
          paint,
        );

      case NibNavIndicatorType.dot:
        final baseColor = indicator.color ?? style.activeColor;
        final paint = Paint()
          ..color = _scaleAlpha(baseColor, indicatorOpacity.value.clamp(0.0, 1.0));
        final radius = indicatorHeight.value > 0 ? indicatorHeight.value : 4.0;
        canvas.drawCircle(
          Offset(
            indicatorX.value + indicatorWidth.value / 2,
            size.height - radius - 4,
          ),
          radius,
          paint,
        );
    }
  }

  /// The painting area for items/labels/indicator, after deflating [size] by
  /// [NibNavBarStyle.padding]. The background/border/clip path
  /// (`_backgroundPath`/`_paintBackground`) continue to use the full [size]
  /// — padding insets content, not the bar's outer shape.
  Rect _contentRect(Size size) {
    final padding = style.padding;
    return Rect.fromLTWH(
      padding.left,
      padding.top,
      (size.width - padding.horizontal).clamp(0.0, size.width),
      (size.height - padding.vertical).clamp(0.0, size.height),
    );
  }

  void _paintItems(Canvas canvas, Size size) {
    if (items.isEmpty) return;

    final contentRect = _contentRect(size);
    final itemWidth = contentRect.width / items.length;
    final hasLabels = items.any((item) => item.label != null);
    final iconCenterY = hasLabels
        ? contentRect.top + contentRect.height * 0.38
        : contentRect.top + contentRect.height / 2;

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final isActive = i == currentIndex;
      final color = isActive ? style.activeColor : style.inactiveColor;
      final itemCenterX = contentRect.left + itemWidth * i + itemWidth / 2;
      final scale = i < itemScales.length ? itemScales[i].value : 1.0;

      canvas.save();
      canvas.translate(itemCenterX, iconCenterY);
      canvas.scale(scale);
      canvas.translate(-itemCenterX, -iconCenterY);

      if (item.label != null) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: item.label,
            style: (style.labelStyle ?? const TextStyle(fontSize: 12))
                .copyWith(color: color),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: itemWidth - 4);

        // Clamp the label's vertical position so it always fits within the
        // content rect, even for compact custom heights or large padding —
        // otherwise it paints outside the CustomPaint's bounds and can be
        // clipped by an ancestor.
        final labelY = (contentRect.top + contentRect.height * 0.66).clamp(
          contentRect.top,
          (contentRect.bottom - textPainter.height).clamp(contentRect.top, contentRect.bottom),
        );

        textPainter.paint(
          canvas,
          Offset(itemCenterX - textPainter.width / 2, labelY),
        );
      }

      canvas.restore();
    }
  }

  /// The on-screen bounds of item [itemIndex]'s icon, unscaled by its
  /// `whileTap`/`whileActive` animation — used to anchor both the icon image
  /// in [_paintItems] and the badge in [_paintBadges].
  Rect _iconRect(Size size, int itemIndex) {
    final contentRect = _contentRect(size);
    final itemWidth = contentRect.width / items.length;
    final hasLabels = items.any((item) => item.label != null);
    final iconCenterY = hasLabels
        ? contentRect.top + contentRect.height * 0.38
        : contentRect.top + contentRect.height / 2;
    final itemCenterX = contentRect.left + itemWidth * itemIndex + itemWidth / 2;
    return Rect.fromCenter(
      center: Offset(itemCenterX, iconCenterY),
      width: style.iconSize,
      height: style.iconSize,
    );
  }

  /// Paints each item's [NibNavItem.badge], anchored to the top-right corner
  /// of its icon. Badges are static — they have no entrance animation and
  /// are repainted whenever [shouldRepaint] detects a change to [items].
  void _paintBadges(Canvas canvas, Size size) {
    for (var i = 0; i < items.length; i++) {
      final badge = items[i].badge;
      if (badge == null) continue;

      final count = badge.count;
      if (count == 0) continue;

      final iconRect = _iconRect(size, i);
      final badgeCenter = Offset(iconRect.right - 2, iconRect.top + 2);
      final color = badge.color ?? _defaultBadgeColor;
      final paint = Paint()..color = color;

      if (count == null) {
        canvas.drawCircle(badgeCenter, _dotBadgeRadius, paint);
        continue;
      }

      final label = count > 99 ? '99+' : count.toString();
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 10,
            height: 1.0,
            fontWeight: FontWeight.w600,
            color: badge.textColor ?? _defaultBadgeTextColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final pillWidth = (textPainter.width + _badgeHorizontalPadding * 2)
          .clamp(_badgePillHeight, double.infinity);
      final pillRect = Rect.fromCenter(
        center: badgeCenter,
        width: pillWidth,
        height: _badgePillHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(pillRect, Radius.circular(_badgePillHeight / 2)),
        paint,
      );

      textPainter.paint(
        canvas,
        Offset(
          badgeCenter.dx - textPainter.width / 2,
          badgeCenter.dy - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant NibNavBarPainter oldDelegate) {
    return oldDelegate.currentIndex != currentIndex ||
        oldDelegate.style != style ||
        oldDelegate.indicator != indicator ||
        !listEquals(oldDelegate.items, items);
    // MotionValue changes (indicator position, item scales/opacities)
    // trigger repaint via the Listenable.merge passed to `super(repaint:)`
    // above — they do not require shouldRepaint to return true.
  }
}

/// Default badge fill color when [NibNavBadge.color] is null — matches
/// Material's `Colors.red`.
const Color _defaultBadgeColor = Color(0xFFF44336);

/// Default badge text color when [NibNavBadge.textColor] is null — matches
/// Material's `Colors.white`.
const Color _defaultBadgeTextColor = Color(0xFFFFFFFF);

/// Radius of a dot badge (null [NibNavBadge.count]).
const double _dotBadgeRadius = 4.0;

/// Height of a numeric badge pill, and its corner radius's basis.
const double _badgePillHeight = 16.0;

/// Horizontal padding inside a numeric badge pill, either side of the text.
const double _badgeHorizontalPadding = 4.0;

/// Returns [color] with its alpha replaced by [opacity] (0.0–1.0).
Color _withAlpha(Color color, double opacity) {
  return color.withValues(alpha: opacity);
}

/// Returns [color] with its existing alpha scaled by [factor] (0.0–1.0).
Color _scaleAlpha(Color color, double factor) {
  return color.withValues(alpha: color.a * factor);
}

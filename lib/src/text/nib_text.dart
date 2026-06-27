import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/nib_anim.dart';
import '../core/nib_motion_controller.dart';
import '../core/nib_motion_widget.dart';
import '../core/nib_transition.dart';
import '../presence/nib_presence.dart';
import 'nib_text_config.dart';

/// Splits [text] into grapheme clusters (user-perceived characters).
///
/// This package has zero pub dependencies, so it cannot use `package:characters`.
/// Flutter's `dart:ui`/`widgets` libraries do not re-export grapheme-cluster
/// splitting either, so this performs a minimal, dependency-free
/// approximation: it keeps UTF-16 surrogate pairs together (so a single
/// 4-byte emoji isn't split into two invalid code units), and also keeps a
/// base code unit together with any immediately following variation
/// selectors, zero-width joiners, combining marks, or skin-tone modifiers, so
/// common multi-code-point emoji sequences (e.g. flags, ZWJ family emoji,
/// skin-tone-modified emoji) stay intact as a single visual unit.
///
/// This is not a full Unicode grapheme-cluster algorithm, but it is safe in
/// the sense that it never splits a surrogate pair, and it keeps the most
/// common multi-code-point sequences whole.
List<String> splitGraphemes(String text) {
  final units = <String>[];
  var index = 0;
  final length = text.length;

  while (index < length) {
    final start = index;
    index += _codeUnitSpan(text, index);

    // Greedily absorb trailing combining/joining code points into the same
    // visual unit (variation selectors, ZWJ + next unit, combining marks,
    // skin tone modifiers, regional indicators forming flag pairs).
    while (index < length) {
      final nextSpan = _codeUnitSpan(text, index);
      final codePoint = text.codePointAt(index);

      final isZwj = codePoint == 0x200D;
      final isVariationSelector = codePoint >= 0xFE00 && codePoint <= 0xFE0F;
      final isCombiningMark = codePoint >= 0x0300 && codePoint <= 0x036F;
      final isSkinToneModifier = codePoint >= 0x1F3FB && codePoint <= 0x1F3FF;

      if (isZwj) {
        // Zero-width joiner: absorb it, then absorb the unit that follows it
        // too (e.g. family emoji sequences), then keep scanning for further
        // joins.
        index += nextSpan;
        if (index < length) {
          index += _codeUnitSpan(text, index);
        }
        continue;
      }

      if (isVariationSelector || isCombiningMark || isSkinToneModifier) {
        index += nextSpan;
        continue;
      }

      break;
    }

    units.add(text.substring(start, index));
  }

  return units;
}

/// Returns the number of UTF-16 code units the code point starting at
/// [index] occupies (1, or 2 for a valid surrogate pair).
int _codeUnitSpan(String text, int index) {
  final unit = text.codeUnitAt(index);
  final isLeadSurrogate = unit >= 0xD800 && unit <= 0xDBFF;
  if (isLeadSurrogate && index + 1 < text.length) {
    final next = text.codeUnitAt(index + 1);
    final isTrailSurrogate = next >= 0xDC00 && next <= 0xDFFF;
    if (isTrailSurrogate) return 2;
  }
  return 1;
}

extension on String {
  int codePointAt(int index) {
    final unit = codeUnitAt(index);
    final isLeadSurrogate = unit >= 0xD800 && unit <= 0xDBFF;
    if (isLeadSurrogate && index + 1 < length) {
      final next = codeUnitAt(index + 1);
      final isTrailSurrogate = next >= 0xDC00 && next <= 0xDFFF;
      if (isTrailSurrogate) {
        return 0x10000 + (unit - 0xD800) * 0x400 + (next - 0xDC00);
      }
    }
    return unit;
  }
}

/// One renderable, independently animated piece of a [NibText]: either a
/// single grapheme cluster, a word, a line, or an unstyled whitespace run
/// preserved between words.
@immutable
class NibTextUnitData {
  /// Creates a text unit.
  const NibTextUnitData({required this.text, required this.isAnimated});

  /// The literal text this unit represents.
  final String text;

  /// Whether this unit is wrapped in its own animated `NibMotion`. Whitespace
  /// runs preserved between words in [NibTextUnit.word] mode are not
  /// animated.
  final bool isAnimated;
}

/// Splits [text] into [NibTextUnitData] according to [unit].
List<NibTextUnitData> splitTextIntoUnits(String text, NibTextUnit unit) {
  switch (unit) {
    case NibTextUnit.character:
      return splitGraphemes(text)
          .map((grapheme) => NibTextUnitData(text: grapheme, isAnimated: true))
          .toList(growable: false);
    case NibTextUnit.word:
      return _splitWords(text);
    case NibTextUnit.line:
      return text
          .split('\n')
          .map((line) => NibTextUnitData(text: line, isAnimated: true))
          .toList(growable: false);
  }
}

List<NibTextUnitData> _splitWords(String text) {
  final units = <NibTextUnitData>[];
  final pattern = RegExp(r'\s+|\S+');
  for (final match in pattern.allMatches(text)) {
    final token = match.group(0)!;
    final isWhitespace = token.trim().isEmpty;
    units.add(NibTextUnitData(text: token, isAnimated: !isWhitespace));
  }
  return units;
}

/// Computes the stagger delay for the unit at [index] out of [total] units,
/// given [staggerDelay] and [staggerFrom].
///
/// [random] supplies the seeded `Random` used for [NibTextStaggerFrom.random]
/// so callers (and tests) can get deterministic output.
Duration computeStaggerDelay({
  required int index,
  required int total,
  required Duration staggerDelay,
  required NibTextStaggerFrom staggerFrom,
  math.Random? random,
}) {
  if (total <= 0) return Duration.zero;

  switch (staggerFrom) {
    case NibTextStaggerFrom.start:
      return staggerDelay * index;
    case NibTextStaggerFrom.end:
      return staggerDelay * (total - 1 - index);
    case NibTextStaggerFrom.center:
      final center = (total - 1) / 2;
      final distance = (index - center).abs();
      return Duration(
          microseconds: (staggerDelay.inMicroseconds * distance).round());
    case NibTextStaggerFrom.random:
      final rand = random ?? math.Random(index * 7919 + total);
      final maxMicros = staggerDelay.inMicroseconds * total;
      if (maxMicros <= 0) return Duration.zero;
      return Duration(microseconds: rand.nextInt(maxMicros));
  }
}

/// Renders [text] (or [span]) split into independently animated character,
/// word, or line units (see [NibTextConfig.unit]), each staggered in by
/// [NibTextConfig.staggerDelay].
///
/// Each unit is wrapped in its own `NibMotion` driven by [config]'s
/// [NibTextConfig.initial]/[NibTextConfig.animate]/[NibTextConfig.exit], so
/// entrance, exit, and stagger all reuse the existing zero-setState
/// `NibMotion` animation engine — `NibText` itself never drives a per-frame
/// animation value.
class NibText extends StatelessWidget {
  /// Creates a `NibText` that animates [text] split according to
  /// `config.unit`.
  const NibText(
    this.text, {
    super.key,
    this.config = const NibTextConfig(),
    this.style,
    this.textAlign,
    this.overflow,
    this.controller,
  }) : span = null;

  /// Creates a `NibText` from a rich [InlineSpan] (e.g. a `TextSpan` with
  /// mixed styles) instead of a flat [String]. The span's `toPlainText()` is
  /// split into units; [style] is used as the base style for each unit and
  /// per-span styling within [span] is not currently preserved per-unit.
  const NibText.rich(
    this.span, {
    super.key,
    this.config = const NibTextConfig(),
    this.style,
    this.textAlign,
    this.overflow,
    this.controller,
  }) : text = null;

  /// The plain text to render and animate. Mutually exclusive with [span].
  final String? text;

  /// The rich span to render and animate. Mutually exclusive with [text].
  final InlineSpan? span;

  /// Configures how the text is split into units and how each unit animates.
  final NibTextConfig config;

  /// The base text style applied to every unit.
  final TextStyle? style;

  /// Text alignment for the laid-out units.
  final TextAlign? textAlign;

  /// How to visually overflow text that doesn't fit, applied to each unit's
  /// internal `Text`.
  final TextOverflow? overflow;

  /// Forwarded to every unit's `NibMotion.controller`, so a single
  /// `NibMotionController` can imperatively drive every unit at once.
  final NibMotionController? controller;

  String get _plainText => text ?? span!.toPlainText();

  @override
  Widget build(BuildContext context) {
    final resolvedText = _plainText;
    final units = splitTextIntoUnits(resolvedText, config.unit);
    final animatedCount = units.where((unit) => unit.isAnimated).length;

    final initial = config.initial ?? NibAnim.identity;
    final animate = config.animate;
    final exit = config.exit;
    final transition = config.transition ??
        const NibTransition(duration: Duration(milliseconds: 400));

    var animatedIndex = 0;
    final children = <Widget>[];

    for (var i = 0; i < units.length; i++) {
      final unitData = units[i];

      if (!unitData.isAnimated) {
        children.add(Text(unitData.text, style: style, overflow: overflow));
        continue;
      }

      final index = animatedIndex++;
      final delay = computeStaggerDelay(
        index: index,
        total: animatedCount,
        staggerDelay: config.staggerDelay,
        staggerFrom: config.staggerFrom,
      );

      final unitTransition = NibTransition(
        duration: transition.duration,
        curve: transition.curve,
        delay: delay,
        spring: transition.spring,
      );

      final key = ValueKey<String>('nib_text_unit_$i');

      Widget unit = NibMotion(
        key: exit != null ? key : null,
        initial: initial,
        animate: animate,
        exit: exit,
        transition: unitTransition,
        controller: controller,
        child: Text(unitData.text, style: style, overflow: overflow),
      );

      if (exit != null) {
        unit = NibPresence(children: [unit]);
      }

      children.add(unit);
    }

    final content = config.unit == NibTextUnit.line
        ? Column(
            crossAxisAlignment: switch (textAlign) {
              TextAlign.center => CrossAxisAlignment.center,
              TextAlign.right || TextAlign.end => CrossAxisAlignment.end,
              _ => CrossAxisAlignment.start,
            },
            mainAxisSize: MainAxisSize.min,
            children: children,
          )
        : Wrap(
            alignment: switch (textAlign) {
              TextAlign.center => WrapAlignment.center,
              TextAlign.right || TextAlign.end => WrapAlignment.end,
              _ => WrapAlignment.start,
            },
            crossAxisAlignment: WrapCrossAlignment.center,
            children: children,
          );

    return content;
  }
}

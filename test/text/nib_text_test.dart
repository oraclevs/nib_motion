import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';
import 'package:nib_motion/src/text/nib_text.dart';

Widget _wrap(Widget child) {
  return Directionality(
      textDirection: TextDirection.ltr, child: Center(child: child));
}

void main() {
  group('splitGraphemes', () {
    test('splits plain ASCII into one unit per character', () {
      expect(splitGraphemes('abc'), ['a', 'b', 'c']);
    });

    test('keeps a surrogate-pair emoji as a single unit', () {
      const emoji = '😀'; // U+1F600, a surrogate pair in UTF-16.
      final units = splitGraphemes('a${emoji}b');
      expect(units, ['a', emoji, 'b']);
    });

    test('keeps a ZWJ emoji sequence as a single unit', () {
      // Family emoji: man + ZWJ + woman + ZWJ + girl.
      const family = '\u{1F468}‍\u{1F469}‍\u{1F467}';
      final units = splitGraphemes('x${family}y');
      expect(units.length, 3);
      expect(units[1], family);
    });

    test('keeps a skin-tone modified emoji as a single unit', () {
      const wave = '\u{1F44B}\u{1F3FB}'; // waving hand + light skin tone.
      final units = splitGraphemes(wave);
      expect(units, [wave]);
    });
  });

  group('splitTextIntoUnits', () {
    test('character mode produces one unit per grapheme, all animated', () {
      final units = splitTextIntoUnits('abc', NibTextUnit.character);
      expect(units.map((u) => u.text), ['a', 'b', 'c']);
      expect(units.every((u) => u.isAnimated), isTrue);
    });

    test('word mode preserves whitespace runs as non-animated units', () {
      final units = splitTextIntoUnits('hello  world', NibTextUnit.word);
      expect(units.map((u) => u.text), ['hello', '  ', 'world']);
      expect(units[0].isAnimated, isTrue);
      expect(units[1].isAnimated, isFalse);
      expect(units[2].isAnimated, isTrue);
    });

    test('line mode splits on newlines', () {
      final units = splitTextIntoUnits('line1\nline2\nline3', NibTextUnit.line);
      expect(units.map((u) => u.text), ['line1', 'line2', 'line3']);
      expect(units.every((u) => u.isAnimated), isTrue);
    });
  });

  group('computeStaggerDelay', () {
    const staggerDelay = Duration(milliseconds: 30);

    test('start accumulates delay forward from index 0', () {
      expect(
        computeStaggerDelay(
          index: 0,
          total: 5,
          staggerDelay: staggerDelay,
          staggerFrom: NibTextStaggerFrom.start,
        ),
        Duration.zero,
      );
      expect(
        computeStaggerDelay(
          index: 3,
          total: 5,
          staggerDelay: staggerDelay,
          staggerFrom: NibTextStaggerFrom.start,
        ),
        staggerDelay * 3,
      );
    });

    test('end accumulates delay backward from the last index', () {
      expect(
        computeStaggerDelay(
          index: 0,
          total: 5,
          staggerDelay: staggerDelay,
          staggerFrom: NibTextStaggerFrom.end,
        ),
        staggerDelay * 4,
      );
      expect(
        computeStaggerDelay(
          index: 4,
          total: 5,
          staggerDelay: staggerDelay,
          staggerFrom: NibTextStaggerFrom.end,
        ),
        Duration.zero,
      );
    });

    test('center delays the middle unit the least and the ends the most', () {
      final centerDelay = computeStaggerDelay(
        index: 2,
        total: 5,
        staggerDelay: staggerDelay,
        staggerFrom: NibTextStaggerFrom.center,
      );
      final edgeDelay = computeStaggerDelay(
        index: 0,
        total: 5,
        staggerDelay: staggerDelay,
        staggerFrom: NibTextStaggerFrom.center,
      );
      expect(centerDelay, Duration.zero);
      expect(edgeDelay, greaterThan(centerDelay));
    });

    test(
        'random produces a deterministic value within [0, total*staggerDelay) for a fixed seed',
        () {
      final delay = computeStaggerDelay(
        index: 1,
        total: 5,
        staggerDelay: staggerDelay,
        staggerFrom: NibTextStaggerFrom.random,
        random: _FixedRandom(0.5),
      );
      expect(delay.inMicroseconds, greaterThanOrEqualTo(0));
      expect(delay.inMicroseconds, lessThan(staggerDelay.inMicroseconds * 5));
    });

    test('returns zero for an empty unit set', () {
      expect(
        computeStaggerDelay(
          index: 0,
          total: 0,
          staggerDelay: staggerDelay,
          staggerFrom: NibTextStaggerFrom.start,
        ),
        Duration.zero,
      );
    });
  });

  group('NibText widget', () {
    testWidgets('renders one Text widget per character unit by default',
        (tester) async {
      await tester.pumpWidget(_wrap(const NibText('abc')));
      await tester.pumpAndSettle();

      expect(find.text('a'), findsOneWidget);
      expect(find.text('b'), findsOneWidget);
      expect(find.text('c'), findsOneWidget);
    });

    testWidgets('renders one Text widget per word unit, preserving whitespace',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const NibText('hello world',
            config: NibTextConfig(unit: NibTextUnit.word))),
      );
      await tester.pumpAndSettle();

      expect(find.text('hello'), findsOneWidget);
      expect(find.text('world'), findsOneWidget);
    });

    testWidgets('renders a Column of lines in line mode', (tester) async {
      await tester.pumpWidget(
        _wrap(const NibText('line1\nline2',
            config: NibTextConfig(unit: NibTextUnit.line))),
      );
      await tester.pumpAndSettle();

      expect(find.text('line1'), findsOneWidget);
      expect(find.text('line2'), findsOneWidget);
      expect(find.byType(Column), findsOneWidget);
    });

    testWidgets('animates each unit from initial to animate', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibText(
            'ab',
            config: NibTextConfig(
              initial: const NibAnim(opacity: 0.0),
              animate: const NibAnim(opacity: 1.0),
              transition:
                  const NibTransition(duration: Duration(milliseconds: 50)),
            ),
          ),
        ),
      );

      final motions =
          tester.widgetList<NibMotion>(find.byType(NibMotion)).toList();
      expect(motions, isNotEmpty);

      await tester.pumpAndSettle();

      // No exception thrown and widgets settle to steady state.
      expect(tester.takeException(), isNull);
    });

    testWidgets('NibText.rich builds from an InlineSpan', (tester) async {
      await tester.pumpWidget(
        _wrap(const NibText.rich(TextSpan(text: 'hi'))),
      );
      await tester.pumpAndSettle();

      expect(find.text('h'), findsOneWidget);
      expect(find.text('i'), findsOneWidget);
    });
  });
}

class _FixedRandom implements Random {
  _FixedRandom(this._fraction);
  final double _fraction;

  @override
  int nextInt(int max) => (_fraction * max).floor();

  @override
  double nextDouble() => _fraction;

  @override
  bool nextBool() => _fraction >= 0.5;
}

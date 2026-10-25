import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/reduced_motion_mixin.dart';
import 'nib_text.dart';

/// Reveals [text] character by character at [speed], with an optional
/// blinking [cursor].
///
/// This is the one widget in the text-animation system that legitimately
/// uses `setState`: the number of revealed characters is a discrete,
/// content-level value (not a per-frame paint value driven by a
/// `MotionValue`), advanced by a `Timer.periodic` — exactly the case the
/// package's zero-setState rule carves out an exception for. There is no
/// continuous animation here to drive through `MotionValue`/`RenderProxyBox`.
class NibTypewriter extends StatefulWidget {
  /// Creates a typewriter effect that reveals [text] over time.
  const NibTypewriter(
    this.text, {
    super.key,
    this.speed = const Duration(milliseconds: 50),
    this.cursor = '|',
    this.cursorBlinkInterval = const Duration(milliseconds: 530),
    this.style,
    this.onComplete,
    this.repeat = false,
    this.deleteSpeed,
    this.delay = Duration.zero,
  });

  /// The full text to reveal.
  final String text;

  /// How long each newly revealed character stays before the next one
  /// appears.
  final Duration speed;

  /// The cursor string appended while typing (and, if [repeat], while
  /// deleting). `null` disables the cursor entirely.
  final String? cursor;

  /// How fast the cursor blinks once typing has paused (after completing, or
  /// before [delay] has elapsed). Ignored if [cursor] is `null`.
  final Duration cursorBlinkInterval;

  /// The text style applied to the revealed text and cursor.
  final TextStyle? style;

  /// Called once, when the full [text] has been revealed. Not called again
  /// on subsequent [repeat] cycles.
  final VoidCallback? onComplete;

  /// If `true`, after fully typing [text] the widget deletes it (at
  /// [deleteSpeed]) and types it again, forever.
  final bool repeat;

  /// How fast characters are deleted during a [repeat] cycle. Defaults to
  /// [speed] if `null`.
  final Duration? deleteSpeed;

  /// How long to wait before typing starts.
  final Duration delay;

  @override
  State<NibTypewriter> createState() => _NibTypewriterState();
}

enum _Phase { waiting, typing, pausedAtEnd, deleting }

class _NibTypewriterState extends State<NibTypewriter>
    with NibReducedMotionMixin {
  late List<String> _graphemes;
  int _revealedCount = 0;
  _Phase _phase = _Phase.waiting;
  bool _cursorVisible = true;
  bool _onCompleteCalled = false;

  Timer? _delayTimer;
  Timer? _typeTimer;
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    _graphemes = splitGraphemes(widget.text);
    if (reduceMotion) {
      _showAll(notify: false);
      return;
    }
    _scheduleStart();
    _startBlinking();
  }

  @override
  void onReducedMotionChanged(bool reduced) {
    if (reduced) _showAll(notify: true);
  }

  /// Reduced motion: show the whole text at once, keep the cursor solid, and
  /// still report completion.
  void _showAll({required bool notify}) {
    _delayTimer?.cancel();
    _typeTimer?.cancel();
    _blinkTimer?.cancel();
    _revealedCount = _graphemes.length;
    _phase = _Phase.pausedAtEnd;
    _cursorVisible = true;
    if (notify) setState(() {});
    if (!_onCompleteCalled) {
      _onCompleteCalled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onComplete?.call();
      });
    }
  }

  @override
  void didUpdateWidget(NibTypewriter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _graphemes = splitGraphemes(widget.text);
      _revealedCount = _revealedCount.clamp(0, _graphemes.length);
    }
  }

  void _scheduleStart() {
    if (widget.delay > Duration.zero) {
      _delayTimer = Timer(widget.delay, _startTyping);
    } else {
      _startTyping();
    }
  }

  void _startTyping() {
    _phase = _Phase.typing;
    _typeTimer?.cancel();
    _typeTimer = Timer.periodic(widget.speed, (_) => _onTypeTick());
  }

  void _onTypeTick() {
    if (!mounted) return;
    if (_revealedCount >= _graphemes.length) {
      _typeTimer?.cancel();
      setState(() => _phase = _Phase.pausedAtEnd);
      if (!_onCompleteCalled) {
        _onCompleteCalled = true;
        widget.onComplete?.call();
      }
      if (widget.repeat) {
        _typeTimer = Timer(widget.speed, _startDeleting);
      }
      return;
    }
    setState(() => _revealedCount++);
  }

  void _startDeleting() {
    if (!mounted) return;
    _phase = _Phase.deleting;
    _typeTimer?.cancel();
    final deleteSpeed = widget.deleteSpeed ?? widget.speed;
    _typeTimer = Timer.periodic(deleteSpeed, (_) => _onDeleteTick());
  }

  void _onDeleteTick() {
    if (!mounted) return;
    if (_revealedCount <= 0) {
      _typeTimer?.cancel();
      _startTyping();
      return;
    }
    setState(() => _revealedCount--);
  }

  void _startBlinking() {
    final cursor = widget.cursor;
    if (cursor == null) return;
    _blinkTimer = Timer.periodic(widget.cursorBlinkInterval, (_) {
      if (!mounted) return;
      setState(() => _cursorVisible = !_cursorVisible);
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _typeTimer?.cancel();
    _blinkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final revealed = _graphemes.take(_revealedCount).join();
    final cursor = widget.cursor;

    if (cursor == null) {
      return Text(revealed, style: widget.style);
    }

    final showCursor = _phase == _Phase.waiting || _cursorVisible;
    return Text.rich(
      TextSpan(
        style: widget.style,
        children: [
          TextSpan(text: revealed),
          TextSpan(text: showCursor ? cursor : ''),
        ],
      ),
    );
  }
}

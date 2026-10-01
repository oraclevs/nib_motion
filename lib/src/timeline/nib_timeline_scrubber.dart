import 'package:flutter/widgets.dart';

import 'nib_timeline.dart';

/// A debug slider that scrubs a [NibTimeline] with [NibTimeline.seek] and
/// mirrors [NibTimeline.progress].
///
/// Built from widgets-layer primitives only (no Material), so it works under
/// `WidgetsApp`, `CupertinoApp` or a bare `Directionality`. Typically placed
/// under a `kDebugMode` check:
///
/// ```dart
/// if (kDebugMode) NibTimelineScrubber(timeline: timeline)
/// ```
class NibTimelineScrubber extends StatelessWidget {
  /// Creates a scrubber for [timeline].
  const NibTimelineScrubber({
    super.key,
    required this.timeline,
    this.activeColor = const Color(0xFF2196F3),
    this.inactiveColor = const Color(0xFFBDBDBD),
    this.textColor = const Color(0xFF616161),
  });

  /// The timeline to scrub.
  final NibTimeline timeline;

  /// Colour of the elapsed part of the track and the thumb.
  final Color activeColor;

  /// Colour of the remaining part of the track.
  final Color inactiveColor;

  /// Colour of the `elapsed / total ms` label.
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: timeline.progress,
      builder: (context, value, _) {
        final total = timeline.duration.inMilliseconds;
        final ms = (total * value).round();
        return Row(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  void seekTo(Offset local) {
                    if (width <= 0) return;
                    timeline.seek(local.dx / width);
                  }

                  return GestureDetector(
                    key: const ValueKey('nib_timeline_scrubber_track'),
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => seekTo(d.localPosition),
                    onHorizontalDragStart: (d) => seekTo(d.localPosition),
                    onHorizontalDragUpdate: (d) => seekTo(d.localPosition),
                    child: SizedBox(
                      height: 32,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _ScrubberPainter(
                          progress: value,
                          active: activeColor,
                          inactive: inactiveColor,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              width: 112,
              child: Text(
                '$ms / $total ms',
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 12,
                  color: textColor,
                  decoration: TextDecoration.none,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScrubberPainter extends CustomPainter {
  _ScrubberPainter({
    required this.progress,
    required this.active,
    required this.inactive,
  });

  final double progress;
  final Color active;
  final Color inactive;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final x = size.width * progress.clamp(0.0, 1.0);
    final track = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;
    canvas.drawLine(
        Offset(0, y), Offset(size.width, y), track..color = inactive);
    canvas.drawLine(Offset(0, y), Offset(x, y), track..color = active);
    canvas.drawCircle(Offset(x, y), 8, Paint()..color = active);
  }

  @override
  bool shouldRepaint(_ScrubberPainter old) =>
      old.progress != progress ||
      old.active != active ||
      old.inactive != inactive;
}

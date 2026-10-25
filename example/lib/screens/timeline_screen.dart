import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

import 'demo_scaffold.dart';

/// Labelled, relative timeline you can play or scrub.
class TimelineScreen extends StatefulWidget {
  /// Creates the screen.
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final _title = NibMotionController();
  final _subtitle = NibMotionController();
  final _cta = NibMotionController();
  late final NibTimeline _timeline;

  static const _hidden = NibAnim(opacity: 0, y: 24);
  static const _shown = NibAnim(opacity: 1, y: 0);

  @override
  void initState() {
    super.initState();
    _timeline = NibTimeline([
      NibTimelineEntry(
        controller: _title,
        target: _shown,
        from: _hidden,
        at: Duration.zero,
        label: 'title',
        transition: const NibTransition(duration: Duration(milliseconds: 500)),
      ),
      NibTimelineEntry.after(
        controller: _subtitle,
        target: _shown,
        from: _hidden,
        transition: const NibTransition(duration: Duration(milliseconds: 400)),
      ),
      NibTimelineEntry.after(
        controller: _cta,
        target: _shown,
        from: _hidden,
        reference: 'title',
        offset: const Duration(milliseconds: -100),
        transition: const NibTransition(duration: Duration(milliseconds: 400)),
      ),
    ]);
  }

  @override
  void dispose() {
    _timeline.dispose();
    _title.dispose();
    _subtitle.dispose();
    _cta.dispose();
    super.dispose();
  }

  Widget _line(NibMotionController c, Widget child) => NibMotion(
        controller: c,
        initial: _hidden,
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Timeline',
      blurb: 'Entries are placed with labels and "after" offsets. Press play, '
          'or drag the scrubber to seek to any moment.',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _line(_title, const Text('Title', style: TextStyle(fontSize: 32))),
          const SizedBox(height: 8),
          _line(_subtitle, const Text('Subtitle after the title')),
          const SizedBox(height: 16),
          _line(
              _cta,
              FilledButton(
                  onPressed: () {}, child: const Text('Overlaps title'))),
          const Spacer(),
          NibTimelineScrubber(timeline: _timeline),
          FilledButton(
            onPressed: _timeline.play,
            child: const Text('Play'),
          ),
        ]),
      ),
    );
  }
}

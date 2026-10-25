import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

import 'demo_scaffold.dart';

/// Scrub a timeline by dragging; entries carry no explicit `from:`.
class TimelineScrubScreen extends StatefulWidget {
  /// Creates the screen.
  const TimelineScrubScreen({super.key});

  @override
  State<TimelineScrubScreen> createState() => _TimelineScrubScreenState();
}

class _TimelineScrubScreenState extends State<TimelineScrubScreen> {
  final _a = NibMotionController();
  final _b = NibMotionController();
  final _c = NibMotionController();
  late final NibTimeline _timeline;

  static const _hidden = NibAnim(opacity: 0, y: 40, scale: 0.8);

  @override
  void initState() {
    super.initState();
    // No `from:` anywhere: the start state is derived from each widget's
    // `initial`.
    _timeline = NibTimeline([
      NibTimelineEntry(
        controller: _a,
        target: NibAnim.identity,
        at: Duration.zero,
        label: 'a',
        transition: const NibTransition(duration: Duration(milliseconds: 600)),
      ),
      NibTimelineEntry.after(
        controller: _b,
        target: NibAnim.identity,
        transition: const NibTransition(duration: Duration(milliseconds: 600)),
      ),
      NibTimelineEntry.withStart(
        controller: _c,
        target: NibAnim.identity,
        reference: 'a',
        offset: const Duration(milliseconds: 200),
        transition: const NibTransition(duration: Duration(milliseconds: 600)),
      ),
    ]);
  }

  @override
  void dispose() {
    _timeline.dispose();
    _a.dispose();
    _b.dispose();
    _c.dispose();
    super.dispose();
  }

  Widget _tile(NibMotionController c, Color color, String label) => NibMotion(
        controller: c,
        initial: _hidden,
        child: DemoBox(size: 72, color: color, label: label),
      );

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Timeline drag-scrub',
      blurb: 'Drag anywhere on the stage to scrub the timeline (RTL and '
          'reverse aware). A starts at 0, B follows A, C starts with A plus '
          '200 ms. No entry declares from:.',
      child: Column(children: [
        Expanded(
          child: NibTimelineDragScrubber(
            timeline: _timeline,
            child: Container(
              color: Colors.indigo.withAlpha(16),
              child: Center(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _tile(_a, Colors.indigo, 'A'),
                  const SizedBox(width: 16),
                  _tile(_b, Colors.teal, 'B'),
                  const SizedBox(width: 16),
                  _tile(_c, Colors.orange, 'C'),
                ]),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            NibTimelineScrubber(timeline: _timeline),
            const SizedBox(height: 8),
            FilledButton(onPressed: _timeline.play, child: const Text('Play')),
          ]),
        ),
      ]),
    );
  }
}

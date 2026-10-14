import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

import 'demo_scaffold.dart';

/// Reading a NibMotion's velocity, and driving it from a `MotionValue<Offset>`.
class VelocityScreen extends StatefulWidget {
  /// Creates the screen.
  const VelocityScreen({super.key});

  @override
  State<VelocityScreen> createState() => _VelocityScreenState();
}

class _VelocityScreenState extends State<VelocityScreen>
    with SingleTickerProviderStateMixin {
  final NibMotionController _controller = NibMotionController();
  final NibOffsetMotionValue _offset =
      NibOffsetMotionValue(const Offset(24, 24));
  late final MultiSpringSolver<Offset> _solver = MultiSpringSolver<Offset>(
    vsync: this,
    value: _offset,
    converter: MotionConverter.offset,
    spring: NibSpring.bouncy,
  );
  MotionValue<double>? _vx;

  @override
  void initState() {
    super.initState();
    // The controller exposes the widget's live MotionValues once attached.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _vx = _controller.motionValueOf(NibProperty.x));
      }
    });
  }

  @override
  void dispose() {
    _solver.dispose();
    _offset.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vx = _vx;
    return DemoScaffold(
      title: 'Velocity read + Offset adapter',
      blurb: 'Top: fling the card; the readout is controller.velocityOf(x). '
          'Bottom: tap the pad; a MotionValue<Offset> drives a NibMotion '
          'paint-only through NibMotionValues(offset:).',
      child: Column(children: [
        Expanded(
          child: Container(
            color: Colors.indigo.withAlpha(16),
            child: Stack(children: [
              Positioned(
                left: 0,
                top: 40,
                child: NibMotion(
                  controller: _controller,
                  drag: const NibDragConfig(
                    axis: Axis.horizontal,
                    releaseMode: NibDragReleaseMode.inertia,
                    constraints: Rect.fromLTRB(0, 0, 240, 0),
                  ),
                  child: const DemoBox(size: 64, label: 'fling'),
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: vx == null
                    ? const Text('vx = …')
                    : ValueListenableBuilder<double>(
                        valueListenable: vx,
                        builder: (context, _, __) => Text(
                          'vx = ${_controller.velocityOf(NibProperty.x).toStringAsFixed(0)} px/s',
                          style: const TextStyle(fontFeatures: []),
                        ),
                      ),
              ),
            ]),
          ),
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) =>
                _solver.animateTo(d.localPosition - const Offset(28, 28)),
            child: Container(
              color: Colors.teal.withAlpha(16),
              child: Stack(children: [
                const Positioned(
                    left: 12, top: 12, child: Text('tap to move (Offset)')),
                NibMotion(
                  motionValues: NibMotionValues(offset: _offset),
                  child: const DemoBox(color: Colors.teal),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

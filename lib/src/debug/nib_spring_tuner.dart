import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/reduced_motion.dart';
import '../physics/nib_spring_curve.dart';
import '../physics/spring_description.dart';
import '../physics/spring_solver.dart';
import '../values/motion_value.dart';

/// Which parameterisation [NibSpringTuner] edits.
enum NibSpringTunerMode {
  /// Perceptual: duration and bounce ([NibSpringDescription.fromDuration]).
  durationBounce,

  /// Physical: mass, stiffness and damping.
  physical,
}

/// A debug tool for tuning a spring by feel: sliders, a live preview driven by
/// a real [SpringSolver], the step-response curve (via [NibSpringCurve]) and a
/// copyable `NibSpringDescription(...)` snippet.
///
/// Widgets-only (no Material), so it drops into any debug overlay:
///
/// ```dart
/// if (kDebugMode) NibSpringTuner(onChanged: (spring) => print(spring))
/// ```
class NibSpringTuner extends StatefulWidget {
  /// Creates a tuner starting from [initial] in [mode].
  const NibSpringTuner({
    super.key,
    this.initial = NibSpringDescription.gentle,
    this.mode = NibSpringTunerMode.durationBounce,
    this.onChanged,
  });

  /// The spring the tuner starts from. In [NibSpringTunerMode.durationBounce]
  /// mode the duration/bounce sliders start at sensible values near it.
  final NibSpringDescription initial;

  /// Which parameter set is shown first.
  final NibSpringTunerMode mode;

  /// Called with the tuned spring whenever a slider moves.
  final ValueChanged<NibSpringDescription>? onChanged;

  @override
  State<NibSpringTuner> createState() => _NibSpringTunerState();
}

class _NibSpringTunerState extends State<NibSpringTuner>
    with SingleTickerProviderStateMixin {
  late NibSpringTunerMode _mode = widget.mode;
  late final ({Duration duration, double bounce}) _initialDurationBounce =
      nibSpringToDurationBounce(widget.initial);
  late double _durationMs =
      _initialDurationBounce.duration.inMilliseconds.toDouble();
  late double _bounce = _initialDurationBounce.bounce;
  late double _mass = widget.initial.mass;
  late double _stiffness = widget.initial.stiffness;
  late double _damping = widget.initial.damping;

  final MotionValue<double> _position = MotionValue<double>(0.0);
  late final SpringSolver _solver;
  bool _atEnd = false;

  NibSpringDescription get _spring => _mode == NibSpringTunerMode.durationBounce
      ? NibSpringDescription.fromDuration(
          duration: Duration(milliseconds: _durationMs.round()),
          bounce: _bounce,
        )
      : NibSpringDescription(
          mass: _mass, stiffness: _stiffness, damping: _damping);

  String get _snippet {
    if (_mode == NibSpringTunerMode.durationBounce) {
      return 'NibSpringDescription.fromDuration('
          'duration: Duration(milliseconds: ${_durationMs.round()}), '
          'bounce: ${_bounce.toStringAsFixed(2)})';
    }
    return 'NibSpringDescription('
        'mass: ${_mass.toStringAsFixed(2)}, '
        'stiffness: ${_stiffness.toStringAsFixed(1)}, '
        'damping: ${_damping.toStringAsFixed(1)})';
  }

  @override
  void initState() {
    super.initState();
    _solver = SpringSolver(
        vsync: this, value: _position, spring: NibSpringDescription.gentle);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Preview once on first build.
    if (!_atEnd && _position.value == 0.0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _replay();
      });
    }
  }

  void _replay() {
    _solver.stop();
    _position.value = 0.0;
    _atEnd = true;
    if (NibMotionConfig.shouldReduceMotion(context)) {
      _position.value = 1.0;
      return;
    }
    _solver
      ..spring = _spring
      ..animateTo(target: 1.0);
  }

  void _changed(VoidCallback mutate) {
    setState(mutate);
    widget.onChanged?.call(_spring);
    _replay();
  }

  @override
  void dispose() {
    _solver.dispose();
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spring = _spring;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _Chip(
              key: const ValueKey('nib-tuner-mode-duration'),
              label: 'duration / bounce',
              selected: _mode == NibSpringTunerMode.durationBounce,
              onTap: () =>
                  _changed(() => _mode = NibSpringTunerMode.durationBounce),
            ),
            _Chip(
              key: const ValueKey('nib-tuner-mode-physical'),
              label: 'mass / stiffness / damping',
              selected: _mode == NibSpringTunerMode.physical,
              onTap: () => _changed(() => _mode = NibSpringTunerMode.physical),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_mode == NibSpringTunerMode.durationBounce) ...[
          _TunerSlider(
            key: const ValueKey('nib-tuner-duration'),
            label: 'duration (ms)',
            value: _durationMs,
            min: 100,
            max: 2000,
            onChanged: (v) => _changed(() => _durationMs = v),
          ),
          _TunerSlider(
            key: const ValueKey('nib-tuner-bounce'),
            label: 'bounce',
            value: _bounce,
            min: -0.9,
            max: 0.9,
            onChanged: (v) => _changed(() => _bounce = v),
          ),
        ] else ...[
          _TunerSlider(
            key: const ValueKey('nib-tuner-mass'),
            label: 'mass',
            value: _mass,
            min: 0.1,
            max: 5,
            onChanged: (v) => _changed(() => _mass = v),
          ),
          _TunerSlider(
            key: const ValueKey('nib-tuner-stiffness'),
            label: 'stiffness',
            value: _stiffness,
            min: 10,
            max: 800,
            onChanged: (v) => _changed(() => _stiffness = v),
          ),
          _TunerSlider(
            key: const ValueKey('nib-tuner-damping'),
            label: 'damping',
            value: _damping,
            min: 1,
            max: 80,
            onChanged: (v) => _changed(() => _damping = v),
          ),
        ],
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: CustomPaint(
            key: const ValueKey('nib-tuner-curve'),
            painter: _CurvePainter(NibSpringCurve(spring)),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 24,
          child: CustomPaint(
            key: const ValueKey('nib-tuner-preview'),
            painter: _PreviewPainter(_position),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _Chip(
              key: const ValueKey('nib-tuner-replay'),
              label: 'replay',
              onTap: _replay,
            ),
            _Chip(
              key: const ValueKey('nib-tuner-copy'),
              label: 'copy',
              onTap: () => Clipboard.setData(ClipboardData(text: _snippet)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(_snippet, key: const ValueKey('nib-tuner-snippet')),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF02569B) : const Color(0x1F000000),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: selected ? const Color(0xFFFFFFFF) : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// A minimal horizontal slider (no Material): tap or drag along the track.
class _TunerSlider extends StatelessWidget {
  const _TunerSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  void _set(BuildContext context, double dx) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || box.size.width <= 0) return;
    final t = (dx / box.size.width).clamp(0.0, 1.0);
    onChanged(min + (max - min) * t);
  }

  @override
  Widget build(BuildContext context) {
    final fraction = ((value - min) / (max - min)).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text('$label ${value.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 11)),
          ),
          Expanded(
            child: Builder(
              builder: (context) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _set(context, d.localPosition.dx),
                onHorizontalDragUpdate: (d) =>
                    _set(context, d.localPosition.dx),
                child: SizedBox(
                  height: 24,
                  child: CustomPaint(painter: _SliderPainter(fraction)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderPainter extends CustomPainter {
  _SliderPainter(this.fraction);

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = const Color(0x33000000)
          ..strokeWidth = 3);
    canvas.drawLine(
        Offset(0, y),
        Offset(size.width * fraction, y),
        Paint()
          ..color = const Color(0xFF02569B)
          ..strokeWidth = 3);
    canvas.drawCircle(Offset(size.width * fraction, y), 7,
        Paint()..color = const Color(0xFF02569B));
  }

  @override
  bool shouldRepaint(_SliderPainter old) => old.fraction != fraction;
}

/// The `(duration, bounce)` that [NibSpringDescription.fromDuration] would use
/// to feel like [spring]: the same natural period (`2π·√(m/k)`) and damping
/// ratio (`bounce = 1 − ζ` when underdamped, `1/ζ − 1` when overdamped),
/// clamped to the tuner's slider ranges (100–2000 ms, −0.9…0.9). Mass is not
/// representable in this mode and is normalised to 1.
({Duration duration, double bounce}) nibSpringToDurationBounce(
    NibSpringDescription spring) {
  final omega = math.sqrt(spring.stiffness / spring.mass);
  final periodMs = (2 * math.pi / omega) * 1000;
  final zeta = spring.damping / (2 * math.sqrt(spring.stiffness * spring.mass));
  final bounce = zeta <= 1 ? 1 - zeta : 1 / zeta - 1;
  return (
    duration: Duration(milliseconds: periodMs.clamp(100, 2000).round()),
    bounce: bounce.clamp(-0.9, 0.9),
  );
}

/// The polyline [NibSpringTuner] plots for [curve] in a box of [size], plus
/// the y of the `1.0` target line and the highest value reached.
///
/// Extracted so the geometry can be tested without pixels.
@visibleForTesting
({List<Offset> points, double targetY, double peakValue}) nibSpringPlotPoints(
  NibSpringCurve curve,
  Size size, {
  int samples = 120,
}) {
  final values = [
    for (var i = 0; i <= samples; i++) curve.transform(i / samples)
  ];
  final peak = values.reduce(math.max);
  final top = math.max(1.1, peak * 1.05);
  final bottom = math.min(0.0, values.reduce(math.min));
  double y(double v) =>
      size.height - (v - bottom) / (top - bottom) * size.height;
  return (
    points: [
      for (var i = 0; i <= samples; i++)
        Offset(size.width * i / samples, y(values[i])),
    ],
    targetY: y(1),
    peakValue: peak,
  );
}

class _CurvePainter extends CustomPainter {
  _CurvePainter(this.curve);

  final NibSpringCurve curve;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = nibSpringPlotPoints(curve, size);
    // Target line at 1.0.
    canvas.drawLine(
        Offset(0, plot.targetY),
        Offset(size.width, plot.targetY),
        Paint()
          ..color = const Color(0x55000000)
          ..strokeWidth = 1);
    final path = Path()..moveTo(plot.points.first.dx, plot.points.first.dy);
    for (final p in plot.points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF54C5F8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_CurvePainter old) => old.curve.spring != curve.spring;
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.position) : super(repaint: position);

  final MotionValue<double> position;

  @override
  void paint(Canvas canvas, Size size) {
    const box = 16.0;
    final x = (size.width - box) * position.value;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, (size.height - box) / 2, box, box),
            const Radius.circular(4)),
        Paint()..color = const Color(0xFF0175C2));
  }

  @override
  bool shouldRepaint(_PreviewPainter old) => old.position != position;
}

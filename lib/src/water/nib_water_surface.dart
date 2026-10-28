import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import '../core/reduced_motion.dart';
import '../shaders/shader_loader.dart';
import '../viewport/nib_viewport_progress.dart';
import 'nib_water_controller.dart';

/// Explicit pointer modes, preventing surface wakes and body drags competing.
enum NibWaterInteraction {
  /// A contact produces bounded travelling disturbances.
  disturb,

  /// A contact translates one body until release or cancellation.
  drag,
}

/// Actual resource path selected by a mounted surface.
enum NibWaterRenderPath {
  /// Resources have not yet been bound.
  loading,

  /// A captured Flutter subtree is bound to the optical shader.
  refractive,

  /// Static outlines only, without refraction.
  fallback,
}

/// Resource diagnostics, separate from GPU timing or frame-rate claims.
@immutable
class NibWaterRenderStatus {
  /// Reports the most recent resource state.
  const NibWaterRenderStatus(
      {required this.path,
      this.captureCount = 0,
      this.lastCaptureMicros = 0,
      this.message = ''});

  /// Bound shader/image, loading, or explicit fallback.
  final NibWaterRenderPath path;

  /// Background images captured since mount.
  final int captureCount;

  /// CPU elapsed time awaiting capture, not GPU frame time.
  final int lastCaptureMicros;

  /// Explanation of the selected path.
  final String message;
}

/// Experimental optical water over a designated Flutter background subtree.
///
/// Requires finite bounds. Only [background] is captured after painting, with
/// one capture in flight, capped to two million pixels. Unchanged backgrounds
/// reuse the image while water repaints without rebuilding widgets. Platform
/// views and content outside [background] are not sampled. Sampling clamps to
/// the local image edges: include background padding when appropriate.
///
/// One surface drives one [controller] in receiver-local logical pixels. The
/// caller disposes the controller. This widget owns its shader and images.
/// [child] remains sharp and keeps its own semantics. TickerMode, [paused] and
/// app backgrounding suspend work; wall time is discarded on resume.
class NibWaterSurface extends StatefulWidget {
  /// Creates a water scene using only supported Flutter rendering APIs.
  const NibWaterSurface(
      {super.key,
      required this.controller,
      required this.background,
      this.child,
      this.interaction = NibWaterInteraction.disturb,
      this.surface = false,
      this.paused = false,
      this.reducedMotion = false,
      this.captureScale = 1,
      this.backgroundChanges,
      this.onStatus});

  /// Externally owned solver and interaction state.
  final NibWaterController controller;

  /// Sole optical input; must not recursively include this water surface.
  final Widget background;

  /// Optional invalidation signal for independently composited background
  /// animations. Ordinary paints and descendant scroll notifications refresh
  /// automatically. This widget listens without owning/disposal of the signal.
  final Listenable? backgroundChanges;

  /// Sharp foreground, including independently accessible controls.
  final Widget? child;

  /// Disturb the surface or translate a droplet, explicitly.
  final NibWaterInteraction interaction;

  /// True fills the box; false draws individual droplets.
  final bool surface;

  /// Suspends time, captures and pointer input while retaining state.
  final bool paused;

  /// Uses a static response when enabled here, by [NibMotionConfig], or by
  /// the system disableAnimations preference.
  final bool reducedMotion;

  /// Capture pixels/logical pixel, .5..2, with a two-million-pixel cap.
  /// Independent of device pixel ratio.
  final double captureScale;

  /// Resource-path reports, never emitted for every wave frame.
  final ValueChanged<NibWaterRenderStatus>? onStatus;
  @override
  State<NibWaterSurface> createState() => _NibWaterSurfaceState();
}

class _NibWaterSurfaceState extends State<NibWaterSurface>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker = createTicker(_tick);
  final _backgroundKey = GlobalKey();
  final _revision = ValueNotifier<int>(0);
  final _viewport = NibViewportProgressController();
  bool _visible = false;
  late Listenable _repaint;
  ui.FragmentShader? _shader;
  ui.Image? _image;
  Duration? _previousTick;
  bool _enabled = true, _foreground = true;
  bool _captureQueued = false, _capturing = false, _needsCapture = true;
  int _captureCount = 0, _lastCaptureMicros = 0, _generation = 0;
  bool _failed = false;
  final Map<int, Offset> _contacts = {};
  @override
  void initState() {
    super.initState();
    _validateScale();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_syncTicker);
    _viewport.visibleFraction.addListener(_visibilityChanged);
    _repaint = Listenable.merge([widget.controller, _revision]);
    widget.backgroundChanges?.addListener(_backgroundPainted);
    _loadShader();
  }

  void _validateScale() {
    if (!widget.captureScale.isFinite ||
        widget.captureScale < .5 ||
        widget.captureScale > 2) {
      throw ArgumentError.value(widget.captureScale, 'captureScale', '.5..2');
    }
  }

  Future<void> _loadShader() async {
    try {
      final program = await NibShaderLoader.load(
          'packages/nib_motion/lib/shaders/water_material.frag');
      if (!mounted) return;
      _shader = program.fragmentShader();
      _revision.value++;
      _report(
          'Canvas fragment shader loaded; controlled Flutter background sampling.');
      _queueCapture();
    } catch (_) {
      if (!mounted) return;
      _failed = true;
      _report(
          'Water shader unavailable. Static outline fallback; no refraction.');
      _revision.value++;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updatePolicy();
  }

  @override
  void didUpdateWidget(NibWaterSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    _validateScale();
    if (oldWidget.backgroundChanges != widget.backgroundChanges) {
      oldWidget.backgroundChanges?.removeListener(_backgroundPainted);
      widget.backgroundChanges?.addListener(_backgroundPainted);
      _needsCapture = true;
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncTicker);
      oldWidget.controller.cancelInputs();
      widget.controller.addListener(_syncTicker);
      _repaint = Listenable.merge([widget.controller, _revision]);
      _contacts.clear();
    }
    if (oldWidget.interaction != widget.interaction) _cancelContacts();
    if (oldWidget.captureScale != widget.captureScale) {
      _generation++;
      _needsCapture = true;
    }
    _updatePolicy();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _updatePolicy();
  }

  void _updatePolicy() {
    // Keep the package's Flutter 3.29 API floor; valuesOf arrived later.
    // ignore: deprecated_member_use
    final tickerEnabled = TickerMode.of(context);
    final enabled = !widget.paused && tickerEnabled && _foreground && _visible;
    if (_enabled && !enabled) _cancelContacts();
    _enabled = enabled;
    widget.controller.setReducedMotion(widget.reducedMotion ||
        MediaQuery.disableAnimationsOf(context) ||
        NibMotionConfig.watchReducedMotion(context));
    _syncTicker();
    if (_enabled && _needsCapture) _queueCapture();
  }

  void _visibilityChanged() {
    _visible = _viewport.visibleFraction.value > 0;
    if (mounted) _updatePolicy();
  }

  void _syncTicker() {
    if (!mounted) return;
    if (_enabled && widget.controller.isActive) {
      if (!_ticker.isActive) {
        _previousTick = null;
        _ticker.start();
      }
    } else if (_ticker.isActive) {
      _ticker.stop();
      _previousTick = null;
    }
  }

  void _tick(Duration elapsed) {
    final previous = _previousTick;
    _previousTick = elapsed;
    if (previous != null && _enabled) {
      widget.controller.advance((elapsed - previous).inMicroseconds / 1000000);
    }
    _syncTicker();
  }

  void _backgroundPainted() {
    _needsCapture = true;
    _queueCapture();
  }

  void _queueCapture() {
    if (!_enabled || _captureQueued || _capturing || !mounted || _failed) {
      return;
    }
    _captureQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureQueued = false;
      if (mounted && _enabled && _needsCapture) _capture();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  Future<void> _capture() async {
    final boundary = _backgroundKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary ||
        !boundary.attached ||
        !boundary.hasSize ||
        boundary.size.isEmpty ||
        !boundary.size.isFinite ||
        boundary.debugNeedsPaint) {
      return;
    }
    _capturing = true;
    _needsCapture = false;
    final generation = _generation;
    final capturedSize = boundary.size;
    final clock = Stopwatch()..start();
    try {
      final scale = math.min(widget.captureScale,
          math.sqrt(2000000 / (boundary.size.width * boundary.size.height)));
      final image = await boundary.toImage(pixelRatio: scale);
      if (!mounted ||
          !_enabled ||
          generation != _generation ||
          !boundary.attached ||
          boundary.size != capturedSize) {
        image.dispose();
        _needsCapture = true;
      } else {
        final previous = _image;
        _image = image;
        _captureCount++;
        _lastCaptureMicros = clock.elapsedMicroseconds;
        _revision.value++;
        _report(
            'Designated Flutter background; Canvas fragment shader. Capture timing is CPU elapsed, not frame time.');
        if (previous != null) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => previous.dispose());
        }
      }
    } catch (_) {
      if (mounted) {
        _failed = true;
        _report(
            'Background capture unavailable. Static outline fallback; no refraction.');
        _revision.value++;
      }
    } finally {
      _capturing = false;
      if (mounted && _needsCapture) _queueCapture();
    }
  }

  void _report(String message) => widget.onStatus?.call(NibWaterRenderStatus(
      path: _failed
          ? NibWaterRenderPath.fallback
          : _shader != null && _image != null
              ? NibWaterRenderPath.refractive
              : NibWaterRenderPath.loading,
      captureCount: _captureCount,
      lastCaptureMicros: _lastCaptureMicros,
      message: message));
  void _down(PointerDownEvent event) {
    if (!_enabled) return;
    if (widget.interaction == NibWaterInteraction.drag && !widget.surface) {
      widget.controller.beginDrag(event.pointer, event.localPosition);
    } else {
      if (_contacts.length >= 10) return;
      _contacts[event.pointer] = event.localPosition;
      widget.controller.disturb(event.localPosition);
    }
  }

  void _move(PointerMoveEvent event) {
    if (!_enabled) return;
    if (widget.interaction == NibWaterInteraction.drag && !widget.surface) {
      widget.controller.dragTo(event.pointer, event.localPosition);
    } else {
      final previous = _contacts[event.pointer];
      if (previous != null && (event.localPosition - previous).distance >= 10) {
        _contacts[event.pointer] = event.localPosition;
        widget.controller.disturb(event.localPosition);
      }
    }
  }

  void _end(int pointer, {bool cancelled = false}) {
    _contacts.remove(pointer);
    widget.controller.endDrag(pointer, cancelled: cancelled);
  }

  void _cancelContacts() {
    _contacts.clear();
    widget.controller.cancelInputs();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.backgroundChanges?.removeListener(_backgroundPainted);
    widget.controller.removeListener(_syncTicker);
    _cancelContacts();
    _viewport.visibleFraction.removeListener(_visibilityChanged);
    _viewport.dispose();
    _ticker.dispose();
    _revision.dispose();
    _shader?.dispose();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, bounds) {
        if (!bounds.hasBoundedWidth || !bounds.hasBoundedHeight) {
          throw FlutterError(
              'NibWaterSurface requires finite width and height.');
        }
        return NibViewportProgress(
            controller: _viewport,
            child: ClipRect(
                child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _down,
                    onPointerMove: _move,
                    onPointerUp: (e) => _end(e.pointer),
                    onPointerCancel: (e) => _end(e.pointer, cancelled: true),
                    child: Stack(fit: StackFit.expand, children: [
                      _WaterBackgroundBoundary(
                          key: _backgroundKey,
                          onPaint: _backgroundPainted,
                          child: NotificationListener<ScrollNotification>(
                              onNotification: (_) {
                                _backgroundPainted();
                                return false;
                              },
                              child: widget.background)),
                      IgnorePointer(
                          child: RepaintBoundary(
                              child: CustomPaint(
                                  painter: _WaterPainter(
                                      controller: widget.controller,
                                      repaint: _repaint,
                                      shader: () => _shader,
                                      image: () => _image,
                                      surface: widget.surface,
                                      failed: () => _failed)))),
                      if (widget.child != null) widget.child!,
                    ]))));
      });
}

class _WaterBackgroundBoundary extends SingleChildRenderObjectWidget {
  const _WaterBackgroundBoundary(
      {super.key, required this.onPaint, required super.child});
  final VoidCallback onPaint;
  @override
  RenderRepaintBoundary createRenderObject(BuildContext context) =>
      _WaterCaptureBoundary(onPaint);
  @override
  void updateRenderObject(
      BuildContext context, _WaterCaptureBoundary renderObject) {
    renderObject.onPaint = onPaint;
  }
}

class _WaterCaptureBoundary extends RenderRepaintBoundary {
  _WaterCaptureBoundary(this.onPaint);
  VoidCallback onPaint;
  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    onPaint();
  }
}

class _WaterPainter extends CustomPainter {
  _WaterPainter(
      {required this.controller,
      required Listenable repaint,
      required this.shader,
      required this.image,
      required this.surface,
      required this.failed})
      : super(repaint: repaint);
  final NibWaterController controller;
  final ui.FragmentShader? Function() shader;
  final ui.Image? Function() image;
  final bool surface;
  final bool Function() failed;
  @override
  void paint(Canvas canvas, Size size) {
    final program = shader();
    final background = image();
    if (program == null || background == null || failed()) {
      final pen = Paint()
        ..color = const Color(0x88FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      if (surface) {
        canvas.drawRect((Offset.zero & size).deflate(1), pen);
      } else {
        for (final drop in controller.drops) {
          canvas.drawCircle(drop.center, drop.radius, pen);
        }
      }
      return;
    }
    final config = controller.config;
    final drops = controller.drops;
    final impulses = controller.impulses;
    var index = 0;
    for (final value in <double>[
      size.width,
      size.height,
      background.width.toDouble(),
      background.height.toDouble(),
      drops.length.toDouble(),
      surface ? 1 : 0,
      config.waveSpeed,
      config.damping,
      config.wavelength,
      config.refraction,
      config.highlight,
      impulses.length.toDouble()
    ]) {
      program.setFloat(index++, value);
    }
    for (var i = 0; i < 10; i++) {
      final drop = i < drops.length ? drops[i] : null;
      for (final value in <double>[
        drop?.center.dx ?? 0,
        drop?.center.dy ?? 0,
        drop?.radius ?? 1,
        0
      ]) {
        program.setFloat(index++, value);
      }
    }
    for (var i = 0; i < 12; i++) {
      final impulse = i < impulses.length ? impulses[i] : null;
      for (final value in <double>[
        impulse?.center.dx ?? 0,
        impulse?.center.dy ?? 0,
        impulse?.age ?? 0,
        impulse?.strength ?? 0
      ]) {
        program.setFloat(index++, value);
      }
    }
    program.setImageSampler(0, background);
    canvas.drawRect(Offset.zero & size, Paint()..shader = program);
  }

  @override
  bool shouldRepaint(_WaterPainter old) => true;
}

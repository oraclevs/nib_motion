part of 'nib_water_surface.dart';

class _WaterSampleWidget extends SingleChildRenderObjectWidget {
  const _WaterSampleWidget(
      {required this.surfaceState,
      required this.devicePixelRatio,
      required super.child});
  final _NibWaterSurfaceState surfaceState;
  final double devicePixelRatio;
  @override
  _WaterSampleRenderBox createRenderObject(BuildContext context) =>
      _WaterSampleRenderBox(surfaceState, devicePixelRatio);
  @override
  void updateRenderObject(
          BuildContext context, _WaterSampleRenderBox renderObject) =>
      renderObject.update(surfaceState, devicePixelRatio);
}

class _WaterSampleRenderBox extends RenderProxyBox {
  _WaterSampleRenderBox(this.surfaceState, this.dpr);
  _NibWaterSurfaceState surfaceState;
  double dpr;
  Listenable? _listening;
  final LayerHandle<_WaterSampleLayer> _sample =
      LayerHandle<_WaterSampleLayer>();

  @override
  bool get alwaysNeedsCompositing => true;

  void update(_NibWaterSurfaceState next, double ratio) {
    surfaceState = next;
    dpr = ratio;
    _listen();
    markNeedsPaint();
  }

  void _listen() {
    if (_listening == surfaceState._repaint) return;
    _listening?.removeListener(markNeedsPaint);
    _listening = attached ? surfaceState._repaint : null;
    _listening?.addListener(markNeedsPaint);
  }

  @override
  void attach(PipelineOwner surfaceState) {
    super.attach(surfaceState);
    _listen();
  }

  @override
  void detach() {
    _listening?.removeListener(markNeedsPaint);
    _listening = null;
    super.detach();
  }

  @override
  void dispose() {
    _listening?.removeListener(markNeedsPaint);
    _sample.layer = null;
    super.dispose();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final layer = _sample.layer ??= _WaterSampleLayer(surfaceState);
    layer
      ..offset = offset
      ..size = size
      ..dpr = dpr;
    context.pushLayer(layer, super.paint, Offset.zero,
        childPaintBounds: Offset.zero & size);
  }
}

// Sampling during composition includes independently repainted child layers.
// toImageSync queues raster work; it does not measure GPU completion.
class _WaterSampleLayer extends OffsetLayer {
  _WaterSampleLayer(this.surfaceState);
  final _NibWaterSurfaceState surfaceState;
  Offset _paintOffset = Offset.zero;
  @override
  Offset get offset => _paintOffset;
  @override
  set offset(Offset value) => _paintOffset = value;
  Size size = Size.zero;
  double dpr = 1;
  Size? _sampleSize;
  double? _sampleScale;
  NibWaterQuality? _quality;
  ui.Image? _input;
  ui.Picture? _output;
  Duration? _submitted;
  int _sequence = 0;
  bool _reportQueued = false;
  Duration? _lastReport;
  NibWaterRenderStatus? _status;

  @override
  bool get alwaysNeedsAddToScene => true;

  void _report(NibWaterRenderStatus status) {
    _status = status;
    if (_reportQueued || surfaceState.widget.onStatus == null) return;
    _reportQueued = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _reportQueued = false;
      if (surfaceState.mounted && attached) {
        surfaceState.widget.onStatus?.call(_status!);
      }
    });
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    if (!surfaceState.mounted || size.isEmpty) return;
    final widget = surfaceState.widget;
    final shader = surfaceState._shader;
    final now = SchedulerBinding.instance.currentSystemFrameTimeStamp;
    if (shader == null || surfaceState._failed) {
      super.addToScene(builder);
      return;
    }
    final resolution = widget.quality.resolve(size, dpr);
    final resized = _sampleSize != size ||
        _sampleScale != resolution.effectiveScale ||
        _quality != widget.quality;
    final due =
        _submitted == null || now - _submitted! >= widget.sampleInterval;
    final capture = surfaceState._enabled &&
        (_input == null ||
            resized ||
            surfaceState._needsCapture ||
            widget.sampling == NibWaterSampling.live ||
            (widget.sampling == NibWaterSampling.throttled && due));
    if (capture) {
      final watch = Stopwatch()..start();
      ui.Scene? scene;
      try {
        final source = ui.SceneBuilder();
        source.pushTransform(Matrix4.diagonal3Values(
                resolution.effectiveScale, resolution.effectiveScale, 1)
            .storage);
        final blur = widget.material?.blurSigma ?? 0;
        if (blur > 0) {
          source
              .pushImageFilter(ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur));
        }
        addChildrenToScene(source);
        if (blur > 0) source.pop();
        source.pop();
        scene = source.build();
        final image = scene.toImageSync(resolution.width, resolution.height);
        final previous = _input;
        _input = image;
        previous?.dispose();
        _sampleSize = size;
        _sampleScale = resolution.effectiveScale;
        _quality = widget.quality;
        _submitted = now;
        _sequence++;
        surfaceState._needsCapture = false;
        if (_lastReport == null ||
            resized ||
            now - _lastReport! >= const Duration(milliseconds: 250)) {
          _lastReport = now;
          _report(NibWaterRenderStatus(
            path: NibWaterRenderPath.refractive,
            backend: 'layerSampler',
            captureCount: _sequence,
            lastCaptureMicros: watch.elapsedMicroseconds,
            resolution: resolution,
            sampleSequence: _sequence,
            boundSequence: _sequence,
            submittedAt: now,
            boundAt: now,
            message:
                '${resolution.reason}. CPU submission only; GPU completion and display age are unmeasured.',
          ));
        }
      } catch (error) {
        _lastReport = null;
        _report(NibWaterRenderStatus(
            path: NibWaterRenderPath.fallback,
            backend: 'direct',
            message: 'Layer sampling failed; live source shown. $error'));
        super.addToScene(builder);
        return;
      } finally {
        scene?.dispose();
      }
    }
    if (_input == null || _sampleSize != size) {
      super.addToScene(builder);
      return;
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _WaterPainter(
            controller: widget.controller,
            repaint: surfaceState._repaint,
            shader: () => shader,
            image: () => _input,
            surface: widget.surface,
            failed: () => false,
            compositeSource: true,
            sourceScale: _sampleScale!,
            material: widget.material)
        .paint(canvas, size);
    final picture = recorder.endRecording();
    _output?.dispose();
    _output = picture;
    builder.addPicture(offset, picture);
  }

  @override
  void dispose() {
    _input?.dispose();
    _output?.dispose();
    super.dispose();
  }
}

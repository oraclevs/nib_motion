# Water rendering

`NibWaterController` simulates bounded droplets and surface disturbances.
`NibWaterSurface` renders them over a designated Flutter `background`, with an
optional sharp foreground `child`. `NibBubbleEmitter` supplies bubble events;
`NibWaterMaterial` adjusts the optics.

Water is part of the stable public API. Its supported behavior is the bounded
rendering contract below. Verify the selected shader or fallback path on the
devices and browsers your application supports.

## Ownership and sampling

One surface drives one controller in receiver-local logical pixels. The caller
disposes the controller; the surface owns its shader and images. Supply finite
bounds and a background that does not recursively contain the water surface.

`NibWaterSampling.legacy` is the default asynchronous snapshot path.
`live` samples child layers during scene composition. `static` caches artwork
until invalidation; `throttled` samples at `sampleInterval`. Use
`backgroundChanges` for independently composited background animations that
need explicit invalidation.

`NibWaterQuality` bounds the input texture by pixel count, estimated RGBA bytes,
and texture dimensions. It does not bound all engine allocations or GPU memory.
The non-legacy path uses device-relative quality; `captureScale` belongs to
the legacy path. `NibWaterMaterial` applies to non-legacy sampling.

## Fallbacks and diagnostics

`onStatus` reports `loading`, `refractive`, or `fallback`, with the selected
backend, resolution, and sample/bound sequence counters. These report resources
and submission, not GPU completion, display latency, or frame-rate guarantees.
Paused state, `TickerMode`, backgrounding, and reduced motion suspend or reduce
work according to the surface policy.

Platform views and content outside `background` cannot be sampled. Refraction
clamps at the input image edges; provide padded artwork when required. Foreground
controls keep their own semantics. Optical distortion does not inverse-warp
their hit targets.

See the [public surface contract](../lib/src/water/nib_water_surface.dart),
[quality settings](../lib/src/water/nib_water_quality.dart), and
[water tests](../test/water/) for exact fields and tested cases. Check the chosen renderer before presenting water alongside the example
app's spring, layout, presence, and shader demonstrations.

## API status

The maintainer confirmed stable API status on November 3, 2026. Water was
already exported in 0.3.5; older published documentation may still use the
previous designation. This clarification changes no signatures, rendering
algorithms, sampling defaults, or platform guarantees.

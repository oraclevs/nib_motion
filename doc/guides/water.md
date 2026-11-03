---
{
  "id": "water",
  "evidence": "MotionNib/motion/lib/src/water/nib_water_surface.dart; MotionNib/motion/lib/src/water/nib_water_controller.dart; MotionNib/motion/test/water/nib_water_live_test.dart"
}
---

# Water surfaces

Render decorative water over a bounded Flutter subtree, with visible sampling status and an honest fallback.

<!-- section: availability -->
## Stable API and bounded rendering

NibWaterSurface, NibWaterController, sampling policies, quality settings, material optics and bubble emission are available in nib_motion 0.3.5. They are not waiting for 0.3.6. Water is part of the stable public API. It renders a decorative 2D/2.5D approximation; it does not simulate a fluid volume.

Use the live example to disturb a bounded surface. Its status comes from onStatus. Refractive means the surface bound a sampled image and shader; fallback means direct content or outlines without refraction. Neither status measures GPU completion, display latency or sustained frame rate.

<!-- section: ownership -->
## Give the surface one controller and finite bounds

Create NibWaterController once in State and dispose it with that State. One surface drives one controller. Empty drops are useful for a continuous surface; individual droplets use stable IDs and receiver-local logical pixels. Do not tick the same controller from a second surface.

Put the artwork or widgets to sample in background. Keep readable controls in child or outside the surface. The surface owns its shader and images. Its background must not recursively contain the water surface.

[Open the complete water example](https://www.nibmotion.xyz/playground/guide-motion-water-example)

<!-- section: sampling -->
## Choose freshness and cost deliberately

NibWaterSampling.legacy is the default asynchronous snapshot path. live samples child layers during scene composition. static caches artwork until invalidation. throttled samples at sampleInterval. For independently composited background animations, backgroundChanges can provide explicit invalidation.

NibWaterQuality bounds the sampled input texture by pixel count, estimated RGBA bytes and texture dimensions. It does not bound every engine allocation or total GPU memory. Non-legacy paths use device-relative quality and NibWaterMaterial; captureScale belongs to the legacy path.

Pause, TickerMode, app backgrounding and reduced motion suspend or reduce work according to the surface policy. Profile a sustained interaction in a consumer release/profile build on the intended device. A successful web build alone is not rendering evidence.

<!-- section: interaction -->
## Keep the optical and input spaces distinct

Choose NibWaterInteraction.disturb for travelling disturbances or drag for moving a droplet. Do not combine two pointer owners for the same surface. The example also offers a keyboard-accessible Disturb button and Reset action.

Only the designated Flutter background is sampled. Platform views and pixels outside that subtree are unsupported. Refraction clamps at the image edges; pad artwork when the composition requires it. Optical distortion does not inverse-warp hit targets. Foreground controls retain their normal semantics and geometry.

Browser and physical-device parity, long-running GPU cost and platform-view capture are not established by this preview. Read the selected path before describing a recording as refraction.

[Shader and glass limits](shaders.md)

[Profile a real screen](performance.md)

[Published water API](https://pub.dev/documentation/nib_motion/0.3.5/nib_motion/NibWaterSurface-class.html)

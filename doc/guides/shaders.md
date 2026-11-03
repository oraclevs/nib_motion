---
{
  "id": "shaders",
  "evidence": "MotionNib/motion/pubspec.yaml; MotionNib/motion/lib/src/shaders/shader_loader.dart; MotionNib/motion/lib/src/shaders/nib_shimmer.dart; MotionNib/motion/lib/src/shaders/nib_dissolve.dart; MotionNib/motion/lib/src/shaders/nib_glass.dart"
}
---

# Shaders

Use bundled effects with asset and renderer fallbacks understood.

<!-- section: custom-fragments -->
## Bring a custom fragment shader

Declare the .frag asset under flutter: shaders: in the consumer pubspec. Give NibShaderEffect exactly one asset key or compiled FragmentProgram. For an overlay, uniform floats are elapsed time when includeTime is true, then width and height when includeSize is true, followed by the supplied MotionValues in list order. Dispose values that you create.

sampleChild transforms the child texture through ImageFilter.shader and requires a supported Impeller renderer. Its first uniform must be a vec2 size, includeSize must stay true, and OpenGL ES sampling needs the documented y-axis treatment. Unsupported or failed shader loading paints the child unchanged; use onLoadError for diagnostics. Reduced motion freezes automatic time at zero; externally driven uniforms remain your responsibility.

[Flutter fragment shader authoring](https://docs.flutter.dev/ui/design/graphics/fragment-shaders)

<!-- section: related-effects -->
## Choose the right sampling boundary

Glass samples a backdrop where shader filters are supported. Water samples its designated Flutter background. Custom fragment effects use an explicit asset and uniforms; these are different rendering contracts.

[Water surfaces and sampling policies](water.md)

<!-- section: bundle -->
## Check shader assets in the consumer

The published 0.3.5 package declares six fragment shaders: shimmer, dissolve, gradient sweep, liquid glass, the nav indicator, and the water material. Water is part of the stable public API. NibShaderLoader loads package asset keys and caches compiled FragmentPrograms. NibMotionConfig.init can preload them; preloadAll swallows failures so startup can continue.

Inspect a built consumer’s asset manifest and rendered result. A successful compile alone does not prove that a particular shader path ran.

<!-- section: choose-effect -->
## Choose an effect for a real state

Use NibShimmer on a loading placeholder whose eventual content has roughly the same shape. Its child paints after the shimmer; an opaque child can hide the effect. Use a transparent SizedBox to see the sweep. Its speed is sweeps per second, angle is radians, and enabled false stops its ticker and shows the child without the overlay. A missing shader also leaves the child visible. Replace the placeholder with real content when loading ends; do not let the sweep masquerade as progress with a known percentage.

NibDissolve is a one-shot reveal or removal around a child. direction decides whether it enters or leaves, duration is 500 ms by default, and onComplete runs when the effect finishes. If the shader is unavailable, the child still fades. NibGlass paints child content over a sampled backdrop with subtle tint and a rim. Its blurSigma is a backdrop blur amount, while thickness, refractiveIndex, chromaticAberration, and saturation tune the shader path. Those shader-only settings do not have identical visual meaning in the frosted fallback.

<!-- section: widgets -->
## Choose the visual effect

NibShimmer makes a diagonal loading sweep, with speed 1.5 and enabled true by default. NibDissolve takes 500 ms by default and can run inward or outward; if its program is unavailable it falls back to a plain opacity fade. NibGlass uses a refractive path where shader filters are supported, otherwise a frosted blur, tint, and rim.

```dart
// In build() while the content is loading.
NibShimmer(
  child: const SizedBox(width: 160, height: 20),
)
```

<!-- api -->
| Name | Type | Default | Description |
| --- | --- | --- | --- |
| NibShimmer.speed | double | 1.5 | Rate of the diagonal sweep. |
| NibDissolve.duration | Duration | 500 ms | Time for inward or outward dissolve. |
| NibGlass.blurSigma | double | 1.0 | Backdrop blur strength in its surface effect. |

<!-- section: asset-check -->
## Inspect the built consumer

The published 0.3.5 package declares six fragment shader assets, including the water material alongside shimmer, dissolve, gradient sweep, liquid glass, and the navigation indicator. A package example can find an asset that a mispackaged consumer cannot, so inspect the final consumer asset manifest and load the effect there. A successful Dart or web compile is insufficient: serve the release build, observe the interaction, and record whether the shader path or fallback painted.

For a hands-on check, render the shimmer snippet in an isolated app, toggle enabled at runtime, and compare it with reduced motion enabled. Then try NibDissolve with both directions. Capture the device, SDK, browser backend or renderer, and a screenshot or short recording. If raster frames spike, compare with the effect removed in the same profile workload before adjusting a visual parameter. A static fallback that leaves the content readable is preferable to a hidden control.

Do not make a business state depend on the shader being available. A dissolve completion may be useful for coordinating a decorative transition, but the content must remain correct when the fallback fades instead. Keep contrast legible under NibGlass’s tint and blur, especially over changing backgrounds. If the browser and a physical device render different effects, document the two results separately; they may have different shader-filter support and raster cost. Check fallback appearance before adjusting shader-only parameters.

<!-- section: limits -->
## Profile the renderer and reduced motion

Shaders can add raster cost even when the widget tree stays stable. Record browser backend or device renderer, GPU support, and fallback behavior in a profile run. The true NibGlass refraction path depends on shader filter support; reduced motion still needs a useful final state.

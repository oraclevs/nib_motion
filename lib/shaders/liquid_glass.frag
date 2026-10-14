#include <flutter/runtime_effect.glsl>

// Apple-style "Liquid Glass": PHYSICALLY-BASED refraction.
//
// The glass is modelled as a plano-convex dome sitting on the backdrop:
//   * getHeight(sd, thickness) gives a quarter-circle height profile — flat
//     (height == thickness) deeper than `thickness` px inside the shape,
//     curving down to 0 at the rim.
//   * A 3D surface normal is built analytically from the rounded-rect SDF
//     gradient: straight up (0,0,1) across the flat center (no distortion —
//     the backdrop stays sharp and straight), tilting to horizontal at the
//     rim (strong bend).
//   * Real Snell's-law refraction: refract() a straight-down eye ray at the
//     surface, march it through the glass plus a virtual base depth, and
//     sample the backdrop where the ray lands. Rays always bend inward, so
//     samples never leave the backdrop (sampleBg clamps defensively too).
//   * Chromatic aberration: red/blue sample slightly longer/shorter
//     displacements (3 taps).
//   * Glass tint is alpha-blended, backdrop saturation is boosted so colors
//     pop through the glass, and a rim highlight derived from the BACKGROUND
//     color (so it picks up ambient hues) tracks uLight, concentrated where
//     the dome curves.
//
// Ported from whynotmake.it's liquid_glass_renderer shaders (render.glsl /
// liquid_glass_final_render.frag), adapted to a single rounded-rect SDF with
// an analytic gradient because dFdx/dFdy is unreliable in ImageFilter.shader.
//
// Used as an `ImageFilter.shader` inside a `BackdropFilter` (Impeller only).
// Image-filter shaders run in DEVICE (physical) pixels: the host passes
// uSize, uRadius and uThickness pre-multiplied by the device pixel ratio,
// and FlutterFragCoord() is physical here too.

uniform vec2 uSize;                 // MUST be first: Impeller overwrites it with the backdrop TEXTURE size (the enclosing layer), px
uniform float uRadius;              // corner radius, physical px
uniform float uThickness;           // glass depth (dome height), physical px
uniform float uRefractiveIndex;     // index of refraction, ~1.2
uniform float uChromaticAberration; // dispersion strength, 0 = off
uniform float uSaturation;          // backdrop saturation boost, 1 = unchanged
uniform float uLightIntensity;      // rim highlight intensity, 0..1
uniform vec2 uLight;                // light direction (points toward the light)
uniform vec4 uTint;                 // glass color rgba; alpha is the mix amount
uniform vec2 uOrigin;               // glass top-left in the backdrop texture, px
uniform vec2 uGlassSize;            // the glass widget's own size, physical px
uniform sampler2D uTexture;         // backdrop, auto-bound by ImageFilter.shader

out vec4 fragColor;

const vec3 LUMA_WEIGHTS = vec3(0.299, 0.587, 0.114);

float sdRoundRect(vec2 p, vec2 hs, float r) {
  vec2 q = abs(p) - (hs - vec2(r));
  return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

// Analytic unit gradient (outward surface normal) of the rounded-rect SDF at
// p — the ImageFilter.shader-safe replacement for dFdx(sd)/dFdy(sd).
vec2 rectNormal(vec2 p, vec2 hs, float r) {
  vec2 d = abs(p) - (hs - vec2(r));
  if (max(d.x, d.y) > 0.0) {
    return normalize(sign(p) * max(d, vec2(0.0)) + vec2(1e-5));
  }
  return (abs(p.x) - hs.x > abs(p.y) - hs.y)
      ? vec2(sign(p.x), 0.0)
      : vec2(0.0, sign(p.y));
}

// `coordPx` is in the glass's own pixel space (0..uGlassSize). Inside an
// ImageFilter.shader, FlutterFragCoord() and the uTexture sampler are both in
// the *enclosing layer's* space (the texture is the whole layer, not just the
// glass), and uSize is that texture's size, so uOrigin translates between the
// two spaces.
vec3 sampleBg(vec2 coordPx) {
  // Refracted rays can overshoot the glass; clamp to the glass's own rect so
  // they pick up its edge colours instead of unrelated backdrop outside it
  // (or, past the texture, the transparent decal border).
  vec2 c = clamp(coordPx, vec2(0.5), uGlassSize - vec2(0.5));
  vec2 uv = (c + uOrigin) / uSize;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return texture(uTexture, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
}

// Height of the glass dome above the backdrop. Quarter-circle profile:
// 0 at the rim (sd == 0), full thickness deeper than `thickness` px inside.
float getHeight(float sd, float thickness) {
  if (sd >= 0.0 || thickness <= 0.0) {
    return 0.0;
  }
  if (sd < -thickness) {
    return thickness;
  }
  float x = thickness + sd;
  return sqrt(max(0.0, thickness * thickness - x * x));
}

vec3 applySaturation(vec3 color, float saturation) {
  float luminance = dot(color, LUMA_WEIGHTS);
  return clamp(mix(vec3(luminance), color, saturation), 0.0, 1.0);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy - uOrigin;
  vec2 hs = uGlassSize * 0.5;
  vec2 p = fragCoord - hs;

  float radius = min(uRadius, min(hs.x, hs.y));
  float sd = sdRoundRect(p, hs, radius);
  float thickness = max(uThickness, 1e-3);

  // --- DOME NORMAL -----------------------------------------------------------
  // (0,0,1) across the flat center, horizontal at the rim. nCos is the cosine
  // between the normal and the xy plane (0 deep inside -> 1 at the rim).
  vec2 grad = rectNormal(p, hs, radius);
  float nCos = clamp(max(thickness + sd, 0.0) / thickness, 0.0, 1.0);
  float nSin = sqrt(max(0.0, 1.0 - nCos * nCos));
  vec3 normal = normalize(vec3(grad * nCos, nSin));

  // --- REFRACTION (real Snell's law) ------------------------------------------
  float height = getHeight(sd, thickness);
  vec3 incident = vec3(0.0, 0.0, -1.0);
  vec3 refr = refract(incident, normal, 1.0 / max(uRefractiveIndex, 1.0));
  float baseHeight = thickness * 8.0;
  float rayLen = (height + baseHeight) / max(0.001, abs(refr.z));
  vec2 disp = refr.xy * rayLen;

  vec3 color;
  if (uChromaticAberration < 0.001) {
    color = sampleBg(fragCoord + disp);
  } else {
    // 3-tap dispersion: red refracts more than blue.
    float ds = uChromaticAberration * 0.5;
    color.r = sampleBg(fragCoord + disp * (1.0 + ds)).r;
    color.g = sampleBg(fragCoord + disp).g;
    color.b = sampleBg(fragCoord + disp * (1.0 - ds)).b;
  }
  vec3 bg = color;

  // --- GLASS COLOR (alpha blend) ----------------------------------------------
  color = mix(color, uTint.rgb, uTint.a);

  // --- SATURATION ---------------------------------------------------------------
  color = applySaturation(color, uSaturation);

  // --- EDGE LIGHTING -------------------------------------------------------------
  // Rim highlight derived from the background color so it picks up ambient
  // hues, concentrated where the dome curves (low normalized height),
  // brightest toward uLight with a weaker counter-light on the far side.
  float normalizedHeight = height / thickness;
  float thicknessScale = clamp(40.0 / max(uThickness, 1.0), 1.0, 4.0);
  float edgeThreshold = mix(0.8, 0.5, 1.0 / thicknessScale);
  float edgeFactor = 1.0 - smoothstep(0.0, edgeThreshold, normalizedHeight);

  if (edgeFactor > 0.01 && sd < 0.5) {
    vec2 lightDir = uLight / max(length(uLight), 1e-5);
    float mainLight = max(0.0, dot(grad, lightDir));
    float oppositeLight = max(0.0, dot(grad, -lightDir));
    float totalInfluence = mainLight + oppositeLight * 0.8;

    float directional = pow(totalInfluence, 1.5) * uLightIntensity * 3.0;
    float ambient = 0.05;
    float brightness =
        clamp((directional + ambient) * edgeFactor * thicknessScale * 0.8, 0.0, 1.0);

    float bgLum = dot(bg, LUMA_WEIGHTS);
    vec3 saturatedBg = mix(bg, bg / max(bgLum, 0.001), 0.8);
    float colorfulness = length(bg - vec3(bgLum));
    float colorMix = clamp(colorfulness + 0.5, 0.5, 1.0);
    vec3 highlightColor = mix(vec3(1.0), saturatedBg, colorMix);

    color = mix(color, highlightColor, brightness);
  }

  // Smooth boundary: fade to the untouched backdrop right at the rim so the
  // edge antialiases instead of stair-stepping.
  float fgAlpha = 1.0 - smoothstep(-2.0, 0.0, sd);
  color = mix(sampleBg(fragCoord), color, fgAlpha);

  fragColor = vec4(color, 1.0);
}

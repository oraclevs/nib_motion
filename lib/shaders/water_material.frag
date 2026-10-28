#version 460 core
#include <flutter/runtime_effect.glsl>
uniform vec2 uSize;
uniform vec2 uTextureSize;
uniform float uDropCount;
uniform float uSurface;
uniform float uWaveSpeed;
uniform float uDamping;
uniform float uWavelength;
uniform float uRefraction;
uniform float uHighlight;
uniform float uImpulseCount;
uniform vec4 uDrop0;
uniform vec4 uDrop1;
uniform vec4 uDrop2;
uniform vec4 uDrop3;
uniform vec4 uDrop4;
uniform vec4 uDrop5;
uniform vec4 uDrop6;
uniform vec4 uDrop7;
uniform vec4 uDrop8;
uniform vec4 uDrop9;
uniform vec4 uImpulse0;
uniform vec4 uImpulse1;
uniform vec4 uImpulse2;
uniform vec4 uImpulse3;
uniform vec4 uImpulse4;
uniform vec4 uImpulse5;
uniform vec4 uImpulse6;
uniform vec4 uImpulse7;
uniform vec4 uImpulse8;
uniform vec4 uImpulse9;
uniform vec4 uImpulse10;
uniform vec4 uImpulse11;
uniform sampler2D uBackground;
out vec4 fragColor;
// Bounded Gaussian field: no singular 1/r expression. .5 is the contour.
void dropField(vec2 p, vec4 drop, inout float field, inout vec2 gradient) {
  vec2 delta = p - drop.xy;
  float radius2 = max(drop.z * drop.z, 1.0);
  float value = exp(-0.69314718 * dot(delta, delta) / radius2);
  field += value;
  gradient += (-1.38629436 / radius2) * value * delta;
}
// Travelling, damped analytical pulse. Time is solver seconds, never eased.
void ripple(vec2 p, vec4 impulse, inout float height, inout vec2 slope) {
  vec2 delta = p - impulse.xy;
  float distance = length(delta);
  float wavelength = max(uWavelength, 8.0);
  float spread = wavelength * 0.65;
  float offset = distance - uWaveSpeed * impulse.z;
  float k = 6.2831853 / wavelength;
  float envelope = exp(-uDamping * impulse.z - offset * offset / (spread * spread));
  float amplitude = impulse.w * envelope * min(impulse.z * 18.0, 1.0);
  height += amplitude * sin(k * offset);
  float derivative = amplitude * (k * cos(k * offset) -
    2.0 * offset / (spread * spread) * sin(k * offset));
  slope += delta / max(distance, 1.0) * derivative;
}
// Explicit bilinear sampling keeps refraction smooth on backends whose
// ImageSampler defaults to nearest-neighbour, including older supported SDKs.
vec4 sampleBackground(vec2 uv) {
  vec2 p = uv * uTextureSize - 0.5;
  vec2 base = floor(p);
  vec2 t = fract(p);
  vec2 a = (base + 0.5) / uTextureSize;
  vec2 step = 1.0 / uTextureSize;
  vec2 low = 0.5 / uTextureSize;
  vec2 high = 1.0 - low;
  vec4 c00 = texture(uBackground, clamp(a, low, high));
  vec4 c10 = texture(uBackground, clamp(a + vec2(step.x, 0.0), low, high));
  vec4 c01 = texture(uBackground, clamp(a + vec2(0.0, step.y), low, high));
  vec4 c11 = texture(uBackground, clamp(a + step, low, high));
  return mix(mix(c00, c10, t.x), mix(c01, c11, t.x), t.y);
}
void main() {
  vec2 p = FlutterFragCoord().xy;
  float field = 0.0;
  vec2 gradient = vec2(0.0);
  if (uDropCount > 0.5) dropField(p, uDrop0, field, gradient);
  if (uDropCount > 1.5) dropField(p, uDrop1, field, gradient);
  if (uDropCount > 2.5) dropField(p, uDrop2, field, gradient);
  if (uDropCount > 3.5) dropField(p, uDrop3, field, gradient);
  if (uDropCount > 4.5) dropField(p, uDrop4, field, gradient);
  if (uDropCount > 5.5) dropField(p, uDrop5, field, gradient);
  if (uDropCount > 6.5) dropField(p, uDrop6, field, gradient);
  if (uDropCount > 7.5) dropField(p, uDrop7, field, gradient);
  if (uDropCount > 8.5) dropField(p, uDrop8, field, gradient);
  if (uDropCount > 9.5) dropField(p, uDrop9, field, gradient);
  float height = 0.0;
  vec2 waveSlope = vec2(0.0);
  if (uImpulseCount > 0.5) ripple(p, uImpulse0, height, waveSlope);
  if (uImpulseCount > 1.5) ripple(p, uImpulse1, height, waveSlope);
  if (uImpulseCount > 2.5) ripple(p, uImpulse2, height, waveSlope);
  if (uImpulseCount > 3.5) ripple(p, uImpulse3, height, waveSlope);
  if (uImpulseCount > 4.5) ripple(p, uImpulse4, height, waveSlope);
  if (uImpulseCount > 5.5) ripple(p, uImpulse5, height, waveSlope);
  if (uImpulseCount > 6.5) ripple(p, uImpulse6, height, waveSlope);
  if (uImpulseCount > 7.5) ripple(p, uImpulse7, height, waveSlope);
  if (uImpulseCount > 8.5) ripple(p, uImpulse8, height, waveSlope);
  if (uImpulseCount > 9.5) ripple(p, uImpulse9, height, waveSlope);
  if (uImpulseCount > 10.5) ripple(p, uImpulse10, height, waveSlope);
  if (uImpulseCount > 11.5) ripple(p, uImpulse11, height, waveSlope);
  float mask = 1.0;
  vec2 domeSlope = vec2(0.0);
  float rim = 0.0;
  if (uSurface < 0.5) {
    float boundaryField = field + height * 0.012 * exp(-6.0 * (field - 0.5) * (field - 0.5));
    mask = smoothstep(0.49, 0.51, boundaryField);
    float dome = sqrt(max(log(max(field, 0.501) / 0.5), 0.0));
    domeSlope = gradient * 16.0 / (max(field, 0.5) * max(dome, 0.28));
    rim = exp(-180.0 * (boundaryField - 0.53) * (boundaryField - 0.53));
  }
  vec2 slope = clamp(domeSlope + waveSlope, vec2(-2.0), vec2(2.0));
  vec3 normal = normalize(vec3(-slope, 1.0));
  vec2 uv = (p - slope * uRefraction) / max(uSize, vec2(1.0));
  vec2 padding = 0.5 / max(uSize, vec2(1.0));
  vec4 sampleColor = sampleBackground(clamp(uv, padding, 1.0 - padding));
  vec3 light = normalize(vec3(-0.45, -0.7, 1.4));
  float specular = pow(max(dot(normal, light), 0.0), 48.0);
  float edgeLight = rim * (0.1 + 0.25 * max(dot(normal.xy, light.xy), 0.0));
  vec3 color = sampleColor.rgb + vec3(uHighlight * (specular * 0.42 + edgeLight));
  // Sample is premultiplied; preserve alpha and avoid invalid RGB > alpha.
  float alpha = sampleColor.a * mask;
  fragColor = vec4(clamp(color, vec3(0.0), vec3(sampleColor.a)) * mask, alpha);
}

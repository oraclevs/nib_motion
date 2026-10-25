#include <flutter/runtime_effect.glsl>
precision highp float;
uniform vec2 uCenter;
uniform vec2 uSize;
uniform float uTail;
uniform float uPhase;
uniform vec4 uTint;
out vec4 fragColor;

float roundedBox(vec2 p, vec2 halfSize, float radius) {
  vec2 q = abs(p) - halfSize + radius;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}
float smoothUnion(float a, float b, float k) {
  float h = clamp(0.5 + 0.5 * (b-a)/k, 0.0, 1.0);
  return mix(b, a, h) - k*h*(1.0-h);
}
float surface(vec2 p) {
  float energy = sin(uPhase * 3.14159265) * (1.0-uPhase);
  vec2 halfSize = uSize * 0.5;
  float radius = min(halfSize.x, halfSize.y) * 0.88;
  float ripple = sin(p.x * .11 - uPhase * 17.0) *
      sin(p.y * .16 + uPhase * 11.0) * energy * 2.2;
  float head = roundedBox(p, halfSize, radius);
  // The smaller trailing lobe is contained completely at rest, and stretches
  // out into a neck while moving. Smooth union models surface tension.
  float tail = roundedBox(p - vec2(uTail, 0.0), halfSize * vec2(.68, .73), radius * .73);
  return smoothUnion(head, tail, min(uSize.y * .20, abs(uTail) * .25 + .01)) + ripple;
}
void main() {
  vec2 p = FlutterFragCoord().xy - uCenter;
  float d = surface(p);
  float coverage = 1.0 - smoothstep(-.8, .8, d);
  if (coverage < .001) { fragColor = vec4(0.0); return; }
  vec2 grad = vec2(surface(p + vec2(.7,0.0))-surface(p-vec2(.7,0.0)),
                   surface(p + vec2(0.0,.7))-surface(p-vec2(0.0,.7)));
  vec2 n = grad / max(length(grad), .001);
  float rim = exp(-abs(d) * .55);
  float inner = exp(-abs(d + 3.0) * .34);
  float fresnel = pow(clamp(1.0 + d / 13.0, 0.0, 1.0), 2.0);
  float light = pow(max(dot(n, normalize(vec2(-.5,-1.0))), 0.0), 5.0);
  float energy = sin(uPhase * 3.14159265) * (1.0-uPhase);
  float caustic = pow(.5+.5*sin(length(p*vec2(.65,1.0))*.31-uPhase*19.0), 9.0);
  vec3 color = uTint.rgb * (.85 + .18 * inner);
  color += vec3(.35,.62,.72) * caustic * energy * .22;
  color = mix(color, vec3(1.0), clamp(light * rim * .75 + fresnel*.14, 0.0, .85));
  float alpha = clamp(uTint.a + rim*.26 + light*rim*.3 + inner*.07, 0.0, 1.0) * coverage;
  fragColor = vec4(color * alpha, alpha);
}

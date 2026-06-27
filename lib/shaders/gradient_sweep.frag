#include <flutter/runtime_effect.glsl>

uniform float uOffset;      // 0.0–1.0 sweep position
uniform vec4 uColorA;
uniform vec4 uColorB;
uniform vec4 uColorC;
uniform vec2 uResolution;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uResolution;
  float x = uv.x + uOffset;
  x = mod(x, 1.0);

  vec4 color = x < 0.5
    ? mix(uColorA, uColorB, x * 2.0)
    : mix(uColorB, uColorC, (x - 0.5) * 2.0);

  fragColor = color;
}

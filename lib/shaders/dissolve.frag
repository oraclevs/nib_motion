#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture;   // the widget's texture
uniform float uProgress;      // 0.0 = fully visible, 1.0 = fully dissolved
uniform float uNoiseScale;    // grain size (default 0.02)
uniform vec2 uResolution;     // widget size

out vec4 fragColor;

// Simple hash noise
float hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uResolution;
  vec4 color = texture(uTexture, uv);

  // Noise value for this pixel
  float noise = hash(floor(uv / uNoiseScale));

  // Pixel dissolves when progress exceeds its noise threshold
  float alpha = step(uProgress, noise);

  fragColor = vec4(color.rgb, color.a * alpha);
}

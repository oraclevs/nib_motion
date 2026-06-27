#include <flutter/runtime_effect.glsl>

uniform float uTime;        // seconds elapsed, drives sweep position
uniform float uSpeed;       // sweep speed multiplier
uniform vec4 uBaseColor;    // the background color
uniform vec4 uShimmerColor; // the highlight color
uniform float uWidth;       // widget width in pixels
uniform float uHeight;      // widget height in pixels
uniform float uAngle;       // sweep angle in radians (default ~-0.3)

out vec4 fragColor;

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;

  // Project coord onto the sweep direction
  float progress = mod(uTime * uSpeed, 1.0);
  float sweepPos = progress * (uWidth + uWidth * 0.5) - uWidth * 0.25;

  // Band width as fraction of widget width
  float bandHalf = uWidth * 0.2;

  // Distance from the sweep center line
  float dist = fragCoord.x + fragCoord.y * tan(uAngle) - sweepPos;

  // Smooth falloff within the band
  float shimmer = smoothstep(bandHalf, 0.0, abs(dist));

  fragColor = mix(uBaseColor, uShimmerColor, shimmer);
}

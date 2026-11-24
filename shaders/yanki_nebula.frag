#version 460 core
#include <flutter/runtime_effect.glsl>

// Yankı's backdrop: deep blue, slow nebula, soft bokeh, a faint field of
// dots, brighter where the figure is and with the voice.
uniform vec2 uSize;
uniform float uTime;
uniform float uEnergy;
uniform vec2 uFocus;

out vec4 fragColor;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
             mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 5; i++) {
    v += a * noise(p);
    p = p * 2.03 + vec2(1.7, 9.2);
    a *= 0.5;
  }
  return v;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uSize;
  float aspect = uSize.x / uSize.y;
  vec2 p = vec2(uv.x * aspect, uv.y);
  vec2 focus = vec2(uFocus.x * aspect, uFocus.y);
  float t = uTime;

  // The ground: navy at the focus, near black at the edges.
  float d = length(p - focus);
  vec3 col = mix(vec3(0.035, 0.11, 0.28), vec3(0.004, 0.012, 0.035),
                 smoothstep(0.0, 1.25, d));

  // Nebula: two slow layers of cloud, cyan and violet.
  vec2 q = p * 1.6 + vec2(t * 0.012, -t * 0.008);
  float n1 = fbm(q + fbm(q * 0.7 + t * 0.02));
  float n2 = fbm(q * 1.4 - vec2(t * 0.015, 0.0) + 7.3);
  float glow = 0.35 + 0.65 * uEnergy;
  col += vec3(0.05, 0.28, 0.55) * pow(n1, 3.0) * 0.55 * glow *
         (1.0 - smoothstep(0.2, 1.3, d));
  col += vec3(0.25, 0.10, 0.45) * pow(n2, 4.0) * 0.35 *
         (1.0 - smoothstep(0.4, 1.6, d));

  // Bokeh: soft discs drifting up.
  for (int i = 0; i < 14; i++) {
    float fi = float(i);
    vec2 c = vec2(hash(vec2(fi, 1.3)) * aspect,
                  fract(hash(vec2(fi, 7.1)) - t * (0.004 + 0.006 * hash(vec2(fi, 3.3)))));
    float r = 0.015 + 0.05 * hash(vec2(fi, 9.9));
    float b = smoothstep(r, r * 0.6, length(p - c));
    vec3 tint = mix(vec3(0.2, 0.6, 1.0), vec3(0.6, 0.35, 1.0), hash(vec2(fi, 4.4)));
    col += tint * b * (0.025 + 0.03 * hash(vec2(fi, 2.2)));
  }

  // The field of dots.
  vec2 g = frag / 22.0;
  vec2 cell = fract(g) - 0.5;
  float wave = 0.5 + 0.5 * sin(floor(g.x) * 0.31 + floor(g.y) * 0.23 + t * 0.7);
  float dotv = smoothstep(0.09, 0.0, length(cell)) * (0.05 + 0.07 * wave);
  col += vec3(0.45, 0.72, 1.0) * dotv * (1.0 - smoothstep(0.3, 1.4, d));

  // Vignette and a little grain.
  col *= 1.0 - 0.35 * smoothstep(0.6, 1.5, d);
  col += (hash(frag + t) - 0.5) * 0.012;
  fragColor = vec4(col, 1.0);
}

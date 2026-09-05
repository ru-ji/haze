#version 460 core
#include <flutter/runtime_effect.glsl>

// One separable pass of a progressive (variable-radius) Gaussian blur,
// applied as a BackdropFilter image filter (ui.ImageFilter.shader). Run
// twice — once with u_blur_direction (1,0), once (0,1) — stacked, for a
// full 2D Gaussian.
//
// The sigma falls off continuously from the chosen edge of the widget's own
// rectangle, so the blur has no visible steps; sampling is masked to that
// rectangle (u_area_*) so pixels outside it can never smear in.

// Maximum taps per side. Must be a compile-time constant (SkSL loops);
// larger radii are covered by widening the stride, not adding taps.
#define MAX_TAPS 64
#define MAX_TAPS_F 64.0

#define MIN_SIGMA 1.0e-2
#define MIN_WEIGHT 1.0e-5

uniform vec2 u_size;           // floats 0,1 — filled by the engine
uniform sampler2D u_texture;   // sampler 0 — the backdrop, bound by the engine

uniform float u_blur_sigma;    // 2 — peak sigma at the edge, device px
uniform vec2 u_blur_direction; // 3,4 — (1,0) horizontal pass, (0,1) vertical
uniform vec2 u_area_origin;    // 5,6 — effect rect origin, device px (screen space)
uniform vec2 u_area_size;      // 7,8 — effect rect size, device px
uniform float u_edge;          // 9 — 0 top, 1 bottom, 2 left, 3 right
uniform float u_power;         // 10 — falloff exponent (higher = tighter to the edge)
uniform float u_extent;        // 11 — fraction of the area the falloff spans (0..1]

out vec4 frag_color;

void main() {
  vec2 xy = FlutterFragCoord().xy;
  vec2 uv = xy / u_size;
  vec2 texel = 1.0 / u_size;

  vec2 areaTopLeftUV = u_area_origin / u_size;
  vec2 areaBottomRightUV = (u_area_origin + u_area_size) / u_size;

  vec4 bg = texture(u_texture, uv);

  // Normalized position inside the effect area along the falloff axis.
  vec2 rel = clamp((xy - u_area_origin) / max(u_area_size, vec2(1.0)), 0.0, 1.0);
  float t = u_edge < 1.5 ? rel.y : rel.x;
  // Distance from the hugged edge: 0 at the edge, 1 fully inward. Odd
  // values (bottom / right) mirror the axis.
  float flip = mod(u_edge, 2.0);
  float edgeDist = clamp(mix(t, 1.0 - t, flip) / max(u_extent, 1.0e-3), 0.0, 1.0);

  // Smootherstep falloff: full strength at the edge, easing to exactly zero
  // with zero FIRST AND SECOND derivative at the inner boundary, so the blur
  // dies instead of stopping. A cosine gets to zero too, but on a straight
  // slope — it still carries a sigma of ~2 at 90% of the span and sheds it
  // over the last few points, and a text line crossing there comes back
  // blurred on top and crisp on the bottom. The eye reads the end of a ramp,
  // not its value.
  float s = 1.0 - edgeDist * edgeDist * edgeDist *
                 (edgeDist * (edgeDist * 6.0 - 15.0) + 10.0);
  // Clamped, and the guard below is written NaN-safe, for the same one reason:
  // the polynomial is 1 at the inner boundary in exact arithmetic and can
  // round a hair past it in float, and pow() of a negative base is UNDEFINED
  // in GLSL. The NaN it returns on a real GPU fails `sigma < MIN_SIGMA`, so
  // the tap loop runs with NaN weights and the row comes out black — one
  // pure-black scanline straight across the effect, at the pixel where the
  // blur is meant to be exactly zero. (The cosine this replaced was immune by
  // accident: HALF_PI was truncated just below pi/2, so it never went
  // negative.)
  float falloff = pow(max(s, 0.0), u_power);

  float sigma = u_blur_sigma * falloff;
  if (!(sigma >= MIN_SIGMA)) {
    frag_color = bg;
    return;
  }

  float invTwoSigma2 = 1.0 / (2.0 * sigma * sigma);
  // Radius approximated as 3 * sigma (~99% of the Gaussian's weight).
  float radius = ceil(3.0 * sigma);
  // Wider stride instead of more taps when the radius exceeds the tap budget.
  float stride = max(1.0, radius / MAX_TAPS_F);
  vec2 texelStep = texel * u_blur_direction * stride;

  float totalWeight = 0.0;
  vec4 totalColor = vec4(0.0);

  for (int i = 0; i <= MAX_TAPS; i++) {
    float x = float(i) * stride;
    if (x > radius) break;

    float weight = exp(-(x * x) * invTwoSigma2);

    if (i == 0) {
      totalColor += bg * weight;
      totalWeight += weight;
    } else {
      vec2 offset = texelStep * float(i);
      vec2 uvRaw1 = uv + offset;
      vec2 uvRaw2 = uv - offset;

      // Taps outside the effect area contribute nothing.
      float mask1 =
          step(areaTopLeftUV.x, uvRaw1.x) * step(uvRaw1.x, areaBottomRightUV.x) *
          step(areaTopLeftUV.y, uvRaw1.y) * step(uvRaw1.y, areaBottomRightUV.y);
      float mask2 =
          step(areaTopLeftUV.x, uvRaw2.x) * step(uvRaw2.x, areaBottomRightUV.x) *
          step(areaTopLeftUV.y, uvRaw2.y) * step(uvRaw2.y, areaBottomRightUV.y);

      vec2 uv1 = clamp(uvRaw1, areaTopLeftUV, areaBottomRightUV);
      vec2 uv2 = clamp(uvRaw2, areaTopLeftUV, areaBottomRightUV);

      float w1 = weight * mask1;
      float w2 = weight * mask2;

      totalColor += texture(u_texture, uv1) * w1 + texture(u_texture, uv2) * w2;
      totalWeight += w1 + w2;
    }
  }

  frag_color = totalColor / max(totalWeight, MIN_WEIGHT);
}

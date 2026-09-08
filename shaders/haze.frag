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
uniform float u_power;         // 10 — falloff exponent on the POSITION (higher = tighter to the edge)
uniform float u_plateau;       // 11 — fraction held at full sigma before the fade
uniform float u_blur_curve;    // 12 — perceptual exponent on the SIGMA only (>= 1)
// vec4 and not vec3 + float: a vec3 is the one type a uniform layout is free
// to pad out to four floats, and `setFloat` indices are a flat count with no
// padding. rgb plus the peak scrim alpha at the edge; alpha 0 disables it.
uniform vec4 u_tint;           // 13,14,15,16 — scrim colour (sRGB 0..1) + peak alpha
uniform float u_tint_adapt;    // 17 — 0 flat alpha, 1 derived from the backdrop's luminance
uniform float u_blur_plateau;  // 18 — the SIGMA's plateau; u_plateau is the scrim's

// The adaptive law, measured off iOS 26's own scroll edge effect by sampling a
// pixel column of a screen recording over flat bands (dark mode, so the scrim
// colour is black):
//
//   white 255 -> 169   (x0.663)
//   grey  117 ->  45   (x0.385)
//   crimson/purple     (x0.36-0.37, uniform across R,G,B — hue is preserved)
//
// No single (colour, alpha) pair can produce both of the first two, so the
// system's scrim is not a constant: the further the backdrop is from the scrim
// colour, the LESS it is covered. Fitting alpha = 1 - K * d^P against those
// points, where d is the luminance distance from the scrim colour, gives
// K = 0.663 and P = 0.7 — and reproduces every sample to within a few percent.
#define TINT_K 0.663
#define TINT_P 0.7

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

// Cheap hash, used for a sub-LSB dither. The scrim is a slow ramp across a
// large area, which is the exact case 8-bit output quantises into visible
// Mach bands — the ramp crosses a code boundary along a straight line and the
// eye reads that line. Breaking the rounding with a fraction of one code
// removes it without being visible itself.
float hash12(vec2 p) {
  vec3 q = fract(vec3(p.xyx) * 0.1031);
  q += dot(q, q.yzx + 33.33);
  return fract((q.x + q.y) * q.z);
}

out vec4 frag_color;

// Full strength over the first `plateau` of the span, then a smootherstep to
// exactly zero at the inner boundary.
//
// The exponent warps the POSITION, never the result. Applied on the way out —
// pow(s, p) — it destroys the very property the smootherstep is here for:
// d/dx s^p = p * s^(p-1) * s', and s^(p-1) diverges as s reaches 0, so any
// p < 1 turns the zero-slope death into a vertical drop. The effect then ends
// on a visible line and reads as a plain BackdropFilter in a ClipRect.
// Warping x first leaves the smootherstep as the last link, so its zero first
// AND second derivative at x = 1 survive for every p: the effect is guaranteed
// to die inside the rectangle, invisibly, whatever the knobs are set to.
//
// A cosine gets to zero too, but on a straight slope — it still carries a
// sigma of ~2 at 90% of the span and sheds it over the last few points, and a
// text line crossing there comes back blurred on top and crisp on the bottom.
// The eye reads the end of a ramp, not its value.
float profile(float edgeDist, float plateau) {
  float d = clamp((edgeDist - plateau) / max(1.0 - plateau, 1.0e-3), 0.0, 1.0);
  float x = pow(max(d, 0.0), 1.0 / u_power);
  return 1.0 - x * x * x * (x * (x * 6.0 - 15.0) + 10.0);
}

// The scrim, applied to the already-blurred colour and riding the same profile
// the sigma does. It lives here rather than as a gradient painted over the
// blur for two reasons. A Dart `LinearGradient` can only be a piecewise-LINEAR
// approximation of this curve: however many stops it is given, its second
// derivative jumps at every one of them, and the eye reads those jumps as
// faint lines — one where the plateau gives way to the fade, one where the
// fade lands. Here the curve is evaluated per pixel, so there are no stops to
// see. And only from inside the shader can the scrim's alpha depend on the
// backdrop it is covering, which is what the system's does.
vec4 tinted(vec4 c, float profile, vec2 xy) {
  if (u_tint.a <= 0.0 || profile <= 0.0) return c;

  // How far the backdrop is from the scrim colour, in luminance. Zero when
  // they already match — covering a black page with black is a no-op whatever
  // the alpha says, so the law is free to go to full there.
  float d = abs(dot(c.rgb, LUMA) - dot(u_tint.rgb, LUMA));
  float adaptive = 1.0 - TINT_K * pow(max(d, 0.0), TINT_P);
  float alpha = mix(1.0, adaptive, clamp(u_tint_adapt, 0.0, 1.0))
              * u_tint.a * profile;

  // +-0.5 of one 8-bit code, so the quantisation error is dithered instead of
  // landing on the same side of the boundary all along a scanline.
  alpha += (hash12(xy) - 0.5) / 255.0;

  return vec4(mix(c.rgb, u_tint.rgb, clamp(alpha, 0.0, 1.0)), c.a);
}

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
  float edgeDist = mix(t, 1.0 - t, flip);

  // Two profiles off one position, because the blur and the scrim do not hold
  // for the same distance. The scrim's plateau is measured off the system
  // effect; the blur's is not, and inheriting the scrim's made the blur sit at
  // full sigma over more than twice the band it used to — which reads as a
  // much heavier blur without the sigma having moved at all.
  float blurFalloff = profile(edgeDist, u_blur_plateau);
  float falloff = profile(edgeDist, u_plateau);

  // Perceptual correction, on the sigma and not on the tint. Apparent
  // blurriness tracks the cutoff frequency, roughly 1/sigma: 40 -> 20 is
  // barely a change, 6 -> 0 is the whole change. A ramp linear in sigma
  // therefore crams everything the eye notices into its last stretch and reads
  // as a uniform slab that suddenly clears. Raising the profile to a power
  // above 1 sheds the big sigmas early and spends the distance where the eye
  // is actually looking. Applied to the RESULT, which is safe here and only
  // here: for an exponent >= 1 the zero slope and curvature at the far side
  // survive (they do not for one below 1 — that is the cliff this file's
  // position-warping exists to avoid).
  float sigma = u_blur_sigma * pow(max(blurFalloff, 0.0), u_blur_curve);
  if (!(sigma >= MIN_SIGMA)) {
    // Past the blur's reach the scrim can still be on — they share a profile
    // but not a scale, and `u_blur_curve` sheds the sigma first. Returning the
    // bare backdrop here is what used to end the wash on a line.
    frag_color = tinted(bg, falloff, xy);
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

  vec4 blurred = totalColor / max(totalWeight, MIN_WEIGHT);
  frag_color = tinted(blurred, falloff, xy);
}

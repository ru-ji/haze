## 0.4.4

* **`debugProfile: true`** paints the two profiles instead of the effect — red
  the sigma's, green the scrim's — so a curve problem can be told apart from a
  coordinate one by looking. Both must reach black exactly at the rectangle's
  far side.

## 0.4.3

* **The line at the start of the fade is gone.** `falloff` warped the position
  along the ramp with `pow(d, 1 / falloff)`, which has an infinite derivative
  at the junction, and the smootherstep could not absorb it: the composed
  profile is about `d^(3/falloff)` there, whose second derivative vanishes only
  below 1.5, sits at a non-zero constant AT 1.5 — the default — and diverges
  above it. A curvature break on a slow ramp is a Mach band, so every band
  drawn at the default settings had a faint line across it exactly where the
  plateau gave way, which read as the hard start of a plain `BackdropFilter`.
  The warp is a rational bias now: same endpoints, same shape between them,
  finite non-zero derivatives at both ends, so the smootherstep's zero first
  and second derivative survive at the start of the fade as well as at its
  death. It is also cheaper than `pow`.

  `falloff` values away from 1 cost slightly less transition width than they
  used to, so `fadeRoom` and the plateau ceiling are a little more generous.

## 0.4.2

* **The kernel only walls off the hugged edge now.** It was masked to the
  widget's rectangle on all four sides and renormalized, so a pixel in the
  middle of a band could not sample the page below it: the average leaned
  toward the edge, the band came out lighter than the untouched pixels just
  outside it, and the difference landed on a straight line at the far side —
  the exact artifact the widget exists to avoid. The one-sided kernel also
  dragged nearby content along the pass direction, which read as streaks.
  Only the hugged edge is a real boundary; the other three sample freely.

## 0.4.1

Two ways a band could still show a visible edge, and the number that prevents
the second one.

* **`blurPlateau` is now bound by the same ceiling as `plateau`.** It was going
  to the shader raw, so a caller could hold the sigma over more of the
  rectangle than the fade had room for — the one combination of knobs left that
  produced a block with a findable edge. `Haze.resolve` scales both, and
  constrains the sigma with whichever holds longest. It returns a third value.

* **`plateau: 1` is now legal**, and is the value to reach for. The assert
  rejecting it dated from when the value went to the shader raw, where 1 meant
  no fade at all; it is read as a fraction of the affordable room now, so 1 is
  the safest value there is rather than the worst.

* **`Haze.fadeRoom(sigma, [falloff])`**, the span a band needs BEYOND the
  chrome it covers. Too short a rectangle is the one thing the widget cannot
  fix for you: it keeps the effect smooth by shortening the plateau, which
  leaves your bar sitting on the ramp — a bar you can see through. Size the
  rectangle at `chrome + fadeRoom(sigma)`, pass `plateau: 1`, and the plateau
  lands exactly on the chrome's edge.

## 0.4.0

The tint moved into the shader, and gained the option of reading the backdrop.

* **The wash is no longer a `LinearGradient`.** It was 30 piecewise-linear
  segments approximating a smootherstep, and a piecewise-linear approximation
  of a curve breaks its second derivative at every stop — which the eye reads
  as faint lines, one where the plateau gives way and one where the fade
  lands. It is now evaluated per pixel in `haze.frag`, on the same profile as
  the sigma, with a sub-LSB dither so 8-bit quantisation cannot band it
  either. The gradient remains for the pre-Impeller fallback, which has no
  shader to put it in.
* **New: `blurPlateau`.** The sigma's own plateau, independent of the scrim's.
  Null (the default) keeps them on one plateau, as before. They are separate
  because they are shaped by different things and measured differently: a flat
  band of wash has an end you can point at in a single screenshot, a blur's
  takes tracking edges across frames. It may be longer than `plateau` —
  measurement says it usually is — since `blurCurve` then makes the blur die
  first anyway. Whatever it is set to, the profile still reaches zero inside
  the rectangle, so it cannot produce a hard edge.
* **New: `tintAdaptivity`.** 0 (default) keeps the flat wash. 1 derives the
  scrim's alpha from the backdrop's luminance, so a white page is covered far
  less than a mid-grey one — iOS 26's behaviour, fitted to measurements of the
  system effect (the samples are in `haze.frag`). The gradient fallback — used
  during route transitions and pre-Impeller, where there is no backdrop to
  read — applies the same law at an assumed mid-range distance rather than
  ignoring it, which would paint the tint solid.

## 0.3.0

Everything in this release is one idea: a progressive blur must never have a
findable edge, and that is the package's job rather than the caller's.

**Breaking**

* `extent` is gone. The ramp always spans the whole rectangle; to shorten it,
  shorten the rectangle. It existed as a dead margin against a faint line at
  the boundary, which the fixes below remove the cause of.
* `falloff` now warps the position along the ramp instead of the result. Same
  direction and the same meaning, `1.0` is unchanged, but values either side of
  1 shape the middle of the curve slightly differently.
* `blurCurve` defaults to `2`, so the blur sheds its radius earlier than in
  0.2.0. Pass `1` for the previous behaviour.

**Fixed**

* `falloff` below 1 ended the blur on a vertical drop. `pow(s, p)` has an
  infinite derivative as `s` reaches 0 for any `p < 1`, which destroyed the
  smootherstep's flat landing — the effect stopped on a line and read as a
  plain `BackdropFilter` in a `ClipRect`. The exponent now applies to the
  position, leaving the smootherstep as the last link, so the ramp lands flat
  for every value.
* `Haze` threw under unbounded constraints. The blur render object is
  `sizedByParent`, and the internal stack expanded, so a `Haze` asked to be as
  tall as its child asked the shader for an infinite height. The child now
  sizes the widget.
* A large `plateau` or a `falloff` far from 1 could squeeze the fade into fewer
  pixels than the blur spans, which is a slab with an edge however smooth the
  curve. The transition (profile 0.9 down to 0.1) is now kept at least as wide
  as `3 × sigma`: `plateau` yields first and proportionally, sigma only when
  even a plateau-free rectangle is too short. See `Haze.resolve`.

**Added**

* `blurCurve`, a perceptual exponent on the blur alone. Apparent blurriness
  tracks `1 / sigma`, so a ramp linear in sigma hides its whole visible change
  in the last stretch. This is the sigma shaping 0.2.0 rejected — it was
  rejected because it was tried on the shared profile, where it also flattened
  the tint.
* `plateau` now holds the **blur** as well as the tint. In 0.2.0 the wash sat
  flat over the bar while the radius was already shedding underneath it, so the
  boundary the tint hid was the one the blur drew.
* `Haze.falloffAt`, `Haze.resolve`, `Haze.plateauCeiling`, `Haze.sigmaCeiling`
  and `Haze.transitionFraction` are public — to line something else up with the
  fade, or to show what the rectangle actually allowed.
* `example/` rebuilt as a one-page studio: live sliders, the profile curve
  plotted from `Haze.falloffAt` itself, the resolved values when the rectangle
  overrules you, and a one-tap switch to a plain `BackdropFilter` for contrast.

## 0.2.0

* `plateau`: the tint can be held at full strength before it starts to fade,
  which is the shape of iOS's scroll edge effect — constant over the bar, then
  a fade whose start is as undetectable as its end (smootherstep, zero first
  and second derivatives at both ends). More gradient stops with it, so the
  gradient's own quantisation cannot reintroduce the banding the curve exists
  to remove.

  Tint only; the blur was byte-for-byte 0.1.1. (0.3.0 puts the blur on the
  same plateau — the two disagreeing was a bug, not a finding.)

## 0.1.0

- Initial release: `Haze`, a shader-based progressive blur with a matching
  tint wash, on any of the four edges.

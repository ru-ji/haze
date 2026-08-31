## 0.2.0

* `plateau`: the tint can be held at full strength before it starts to fade,
  which is the shape of iOS's scroll edge effect — constant over the bar, then
  a fade whose start is as undetectable as its end (smootherstep, zero first
  and second derivatives at both ends). More gradient stops with it, so the
  gradient's own quantisation cannot reintroduce the banding the curve exists
  to remove.

  Tint only. **The blur is byte-for-byte 0.1.1.** A plateau, a smootherstep
  tail, exponential shaping of sigma, bilinear tap pairing and cross-fading a
  fixed blur into the backdrop were each tried on it and each was worse in the
  hand: what makes an alpha fade invisible is not what makes a radius ramp
  invisible.

## 0.1.0

- Initial release: `Haze`, a shader-based progressive blur with a matching
  tint wash, on any of the four edges.

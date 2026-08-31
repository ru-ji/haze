## 0.2.0

* The blur now dies in output space, like the tint: over the falloff's tail
  the blurred image is cross-faded back into the backdrop. Perceived sharpness
  is not linear in sigma — a hard edge snaps from "soft" to "sharp" as sigma
  crosses ~1 — so a sigma-only fade left a readable boundary between blurred
  and sharp content that the cross-fade removes.
* The backdrop-filter layers no longer cover the falloff's dead zone. An
  identity filter is not "no filter": its round-trip edge could show as a
  hairline floating below the fade. The layers now end at the falloff
  terminus, where the effect is already nothing.

* The falloff is now iOS's own profile: an optional full-strength `plateau`
  off the edge, then a smootherstep decay — first and second derivatives are
  zero at both ends, so neither where the fade begins nor where it dies is
  detectable. The previous cosine left a visible line at the far boundary at
  low `falloff` exponents. Blur and tint share the profile, as one effect.

## 0.1.0

- Initial release: `Haze`, a shader-based progressive blur with a matching
  tint wash, on any of the four edges.

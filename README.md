# haze

Progressive (gradient) blur for Flutter — a **true variable-radius Gaussian**
over the backdrop, strongest at one edge and fading continuously to nothing,
with an optional tint wash on the same profile.

This is iOS 26's *scroll edge effect* as a plain widget: put it over an image,
under a navigation bar, above a tab bar, anywhere text has to stay legible on
top of moving content.

```dart
Stack(children: [
  Image.network(url, fit: BoxFit.cover),
  Positioned(
    left: 0, right: 0, bottom: 0, height: 160,
    child: Haze(
      edge: HazeEdge.bottom,
      sigma: 22,
      tint: CupertinoColors.black,
      tintOpacity: 0.5,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Text('Light on the dunes'),
      ),
    ),
  ),
]);
```

## Why not stacked BackdropFilters

The usual trick — a column of `BackdropFilter`s with increasing sigma — has
visible steps and smears in whatever sits outside the widget. `haze` runs a
bundled fragment shader in two separable passes (`ui.ImageFilter.shader`), so
the sigma is a continuous function of the distance to the edge, and sampling
is walled off at the edge it hugs — where there is nothing behind the effect to
read — while staying free on the other three sides, so the kernel never goes
one-sided and the band never differs from the pixels just outside it. Bounds are recomputed **at paint
time**, so the effect stays correct while a header collapses under a scroll or
a page slides during a route transition.

Where shader image filters aren't available (non-Impeller), it degrades to the
stacked-blur approximation automatically.

## The effect always ends inside its rectangle

A progressive blur has one job: no findable edge. `haze` guarantees it rather
than leaving it to the caller's numbers.

The ramp is a smootherstep, and the shape knob (`falloff`) warps the *position*
along it, never the result — so the profile reaches zero at the far side with
zero slope and zero curvature whatever it is set to. There is no dead margin to
reserve and nothing overflows the rectangle, so a `ClipRect` sitting exactly on
its bounds cuts nothing.

That covers the end of the ramp. The other way to get a visible edge is a
transition too *narrow* to read as one — a big `plateau`, or a `falloff` far
from 1, squeezing the fade into fewer pixels than the blur itself spans. So
`haze` measures the transition (where the profile runs 0.9 down to 0.1) and
keeps it at least as wide as the blur's own reach, `3 × sigma`:

```
transition = height × (1 - plateau) × (0.7546^falloff - 0.2454^falloff)
```

When it does not fit, `plateau` yields first and *proportionally* — asking for
0.9 where 0.8 is the most the rectangle can carry gives 0.72, so callers asking
for different plateaus still get different ones. Only a rectangle too short
even without a plateau goes on to cap the sigma itself. Nothing here is a fixed
distance: the constraint scales with the rectangle, and a rectangle with room
to spare never comes near it.

`Haze.resolve(span, sigma, plateau, falloff)` returns what will actually be
painted, if you want to show it or line something up with it.

## Parameters

| | |
|---|---|
| `edge` | `HazeEdge.top / bottom / left / right` — where the blur is strongest. |
| `sigma` | Peak blur radius in logical px at `edge`, fading to 0. Capped only when the rectangle cannot give it room to fade — see above. |
| `tint` | Wash colour painted over the blur, same profile. `null` = blur only. |
| `tintOpacity` | Peak alpha of the tint at `edge`. |
| `plateau` | Fraction of the rectangle held at full strength — sigma and tint both — before the fade starts. `0` fades from the very first pixel. Read as a fraction of the room there actually is. |
| `falloff` | Shape of the fade: an exponent on the position along the ramp. `1` is the bare smootherstep and spreads the transition widest; higher keeps the effect tight to the edge, lower holds it flat then releases late. Cannot change how the ramp ends. |
| `blurCurve` | Perceptual exponent on the **blur alone**, `>= 1`. Default `2`. |
| `borderRadius` | Rounds the clip, to match a card underneath. |
| `enabled` | Paint the child only, without changing layout. |
| `child` | Drawn above the effect. Sizes the widget, so a bar can be as tall as the row inside it. |

### Why `blurCurve` exists

The tint and the sigma ride the same profile, but the eye does not read them
the same way. Alpha is roughly linear — 0.6 to 0.3 looks like half the journey.
Apparent blurriness is not: it tracks the cutoff frequency, about `1 / sigma`,
so 40 to 20 is barely a change while 6 to 0 is the whole change.

Linear in sigma, everything noticeable about the blur is therefore crammed into
the last stretch of the ramp, and the rest reads as a uniform slab that
suddenly clears. `blurCurve` raises the profile to a power for the sigma only,
shedding the big radii early and spending the distance where the eye is
actually looking. At the default `2`, half way down the ramp the sigma is at a
quarter rather than a half. Set it to `1` to put the blur back on the tint's
curve.

Applied to the result rather than the position, which is safe here and only
here: for an exponent at or above 1 the flat landing at the far side survives.
Below 1 it would not, hence the assert.

## Example

`example/` is a one-page studio over a swipeable photograph: live sliders for
every parameter, the profile curve plotted from `Haze.falloffAt` itself, the
resolved values shown whenever the rectangle overrules you, and a switch
between `Haze` and a plain `BackdropFilter` given the same sigma and the same
tint — which is the shortest way to see what this package is for.

```bash
cd example && flutter run
```

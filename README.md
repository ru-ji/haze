# haze

Progressive (gradient) blur for Flutter — a **true variable-radius Gaussian**
over the backdrop, strongest at one edge and fading continuously to nothing,
with an optional tint wash on the exact same falloff.

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
is clamped to the widget's own rectangle. Bounds are recomputed **at paint
time**, so the effect stays correct while a header collapses under a scroll or
a page slides during a route transition.

Where shader image filters aren't available (non-Impeller), it degrades to the
stacked-blur approximation automatically.

## Parameters

| | |
|---|---|
| `edge` | `HazeEdge.top / bottom / left / right` — where the blur is strongest. |
| `sigma` | Peak blur radius in logical px at `edge`, fading to 0. |
| `tint` | Wash colour painted over the blur, same falloff. `null` = blur only. |
| `tintOpacity` | Peak alpha of the tint at `edge`. |
| `falloff` | Cosine exponent. Higher keeps the effect tight to the edge, lower spreads it inward. |
| `extent` | Fraction of the widget the falloff spans (default `0.97`, a thin dead zone that avoids a faint line at the boundary). |
| `borderRadius` | Rounds the clip, to match a card underneath. |
| `enabled` | Paint the child only, without changing layout. |
| `child` | Drawn above the effect. |

## Example

`example/` is a Cupertino photo gallery: a soft-edge navigation bar, hero and
grid cards with blurred captions, and a detail page with live sliders for every
parameter.

```bash
cd example && flutter run
```

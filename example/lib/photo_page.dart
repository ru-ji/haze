import 'package:flutter/cupertino.dart';
import 'package:haze/haze.dart';

import 'photos.dart';

/// Detail view — and a live playground for every [Haze] parameter.
class PhotoPage extends StatefulWidget {
  const PhotoPage({super.key, required this.photo});

  final Photo photo;

  @override
  State<PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends State<PhotoPage> {
  double _sigma = 24;
  double _tintOpacity = 0.5;
  double _falloff = 1.5;
  double _extent = 0.97;
  HazeEdge _edge = HazeEdge.bottom;
  bool _showControls = true;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final vertical = _edge == HazeEdge.top || _edge == HazeEdge.bottom;

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF07070A),
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: widget.photo.placeholder,
              child: Image.network(widget.photo.url, fit: BoxFit.cover),
            ),
          ),

          // The effect being demonstrated: it hugs the chosen edge and takes
          // half the screen along that axis.
          Positioned(
            top: _edge == HazeEdge.bottom ? null : 0,
            bottom: _edge == HazeEdge.top ? null : 0,
            left: _edge == HazeEdge.right ? null : 0,
            right: _edge == HazeEdge.left ? null : 0,
            height: vertical ? MediaQuery.sizeOf(context).height * 0.5 : null,
            width: vertical ? null : MediaQuery.sizeOf(context).width * 0.6,
            child: Haze(
              edge: _edge,
              sigma: _sigma,
              falloff: _falloff,
              extent: _extent,
              tint: CupertinoColors.black,
              tintOpacity: _tintOpacity,
            ),
          ),

          // Caption, anchored where the blur is deepest.
          Positioned(
            left: 20,
            right: 20,
            top: _edge == HazeEdge.bottom ? null : padding.top + 60,
            bottom: _edge == HazeEdge.bottom
                ? padding.bottom + (_showControls ? 300 : 40)
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.photo.title,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.photo.story,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    color: Color(0xD9FFFFFF),
                  ),
                ),
              ],
            ),
          ),

          // Back button, on its own small top Haze.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: padding.top + 48,
            child: Haze(
              edge: HazeEdge.top,
              sigma: 12,
              tint: CupertinoColors.black,
              tintOpacity: 0.35,
              child: Padding(
                padding: EdgeInsets.only(top: padding.top, left: 4),
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Row(
                        children: [
                          Icon(CupertinoIcons.back, size: 24),
                          Text('Gallery', style: TextStyle(fontSize: 17)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      onPressed: () =>
                          setState(() => _showControls = !_showControls),
                      child: Icon(
                        _showControls
                            ? CupertinoIcons.chevron_down_circle
                            : CupertinoIcons.slider_horizontal_3,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_showControls)
            Positioned(
              left: 12,
              right: 12,
              bottom: padding.bottom + 12,
              child: _Controls(
                edge: _edge,
                sigma: _sigma,
                tintOpacity: _tintOpacity,
                falloff: _falloff,
                extent: _extent,
                onChanged:
                    ({edge, sigma, tintOpacity, falloff, extent}) => setState(() {
                      _edge = edge ?? _edge;
                      _sigma = sigma ?? _sigma;
                      _tintOpacity = tintOpacity ?? _tintOpacity;
                      _falloff = falloff ?? _falloff;
                      _extent = extent ?? _extent;
                    }),
              ),
            ),
        ],
      ),
    );
  }
}

typedef _ControlsChanged =
    void Function({
      HazeEdge? edge,
      double? sigma,
      double? tintOpacity,
      double? falloff,
      double? extent,
    });

class _Controls extends StatelessWidget {
  const _Controls({
    required this.edge,
    required this.sigma,
    required this.tintOpacity,
    required this.falloff,
    required this.extent,
    required this.onChanged,
  });

  final HazeEdge edge;
  final double sigma;
  final double tintOpacity;
  final double falloff;
  final double extent;
  final _ControlsChanged onChanged;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF15151A).withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoSlidingSegmentedControl<HazeEdge>(
                groupValue: edge,
                onValueChanged: (value) => onChanged(edge: value),
                children: const {
                  HazeEdge.top: Text('Top'),
                  HazeEdge.bottom: Text('Bottom'),
                  HazeEdge.left: Text('Left'),
                  HazeEdge.right: Text('Right'),
                },
              ),
              const SizedBox(height: 6),
              _Row(
                label: 'sigma',
                value: sigma,
                min: 0,
                max: 40,
                onChanged: (v) => onChanged(sigma: v),
              ),
              _Row(
                label: 'tintOpacity',
                value: tintOpacity,
                min: 0,
                max: 1,
                onChanged: (v) => onChanged(tintOpacity: v),
              ),
              _Row(
                label: 'falloff',
                value: falloff,
                min: 0.4,
                max: 4,
                onChanged: (v) => onChanged(falloff: v),
              ),
              _Row(
                label: 'extent',
                value: extent,
                min: 0.2,
                max: 1,
                onChanged: (v) => onChanged(extent: v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xB3FFFFFF)),
          ),
        ),
        Expanded(
          child: CupertinoSlider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 42,
          child: Text(
            value.toStringAsFixed(max <= 1 ? 2 : 1),
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              color: CupertinoColors.white,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

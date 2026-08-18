import 'package:flutter/cupertino.dart';
import 'package:haze/haze.dart';

import 'main.dart' show PhotoImage, kContentWidth, kInset, kRadius;
import 'photos.dart';
import 'zoom_press.dart';

/// Detail view — the same floating card as the gallery, with a Haze on it and
/// a live control for every parameter.
class PhotoPage extends StatefulWidget {
  const PhotoPage({super.key, required this.photo});

  final Photo photo;

  @override
  State<PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends State<PhotoPage> {
  HazeEdge _edge = HazeEdge.bottom;
  double _sigma = 18;
  double _tintOpacity = 0.45;
  double _falloff = 1.5;
  double _extent = 0.97;
  Color? _tint = CupertinoColors.black;
  bool _caption = true;

  static const _swatches = <Color?>[
    CupertinoColors.black,
    CupertinoColors.white,
    Color(0xFF0A2A6B),
    null,
  ];

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: Stack(
        children: [
          Center(
            child: SizedBox(
              width: kContentWidth,
              child: Column(
                children: [
                  SizedBox(height: padding.top + 72),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: kInset),
                    child: _Card(
                      photo: widget.photo,
                      edge: _edge,
                      sigma: _sigma,
                      tint: _tint,
                      tintOpacity: _tintOpacity,
                      falloff: _falloff,
                      extent: _extent,
                      caption: _caption,
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        kInset,
                        20,
                        kInset,
                        padding.bottom + 24,
                      ),
                      child: _ControlPanel(
                        edge: _edge,
                        sigma: _sigma,
                        tintOpacity: _tintOpacity,
                        falloff: _falloff,
                        extent: _extent,
                        tint: _tint,
                        swatches: _swatches,
                        caption: _caption,
                        onEdge: (v) => setState(() => _edge = v),
                        onSigma: (v) => setState(() => _sigma = v),
                        onTintOpacity: (v) => setState(() => _tintOpacity = v),
                        onFalloff: (v) => setState(() => _falloff = v),
                        onExtent: (v) => setState(() => _extent = v),
                        onTint: (v) => setState(() => _tint = v),
                        onCaption: (v) => setState(() => _caption = v),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Same top Haze bar as the gallery.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: padding.top + 52,
            child: Haze(
              edge: HazeEdge.top,
              sigma: 7,
              falloff: 2.8,
              tint: CupertinoColors.systemGroupedBackground.resolveFrom(
                context,
              ),
              tintOpacity: 0.72,
              child: Padding(
                padding: EdgeInsets.only(top: padding.top),
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: Size.zero,
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Row(
                        children: [
                          Icon(CupertinoIcons.back, size: 24),
                          Text('Gallery', style: TextStyle(fontSize: 17)),
                        ],
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.photo,
    required this.edge,
    required this.sigma,
    required this.tint,
    required this.tintOpacity,
    required this.falloff,
    required this.extent,
    required this.caption,
  });

  final Photo photo;
  final HazeEdge edge;
  final double sigma;
  final Color? tint;
  final double tintOpacity;
  final double falloff;
  final double extent;
  final bool caption;

  @override
  Widget build(BuildContext context) {
    final vertical = edge == HazeEdge.top || edge == HazeEdge.bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kRadius),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.16),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kRadius),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              fit: StackFit.expand,
              children: [
                ZoomPress(child: PhotoImage(photo: photo, width: 1400)),
                Positioned(
                  top: edge == HazeEdge.bottom ? null : 0,
                  bottom: edge == HazeEdge.top ? null : 0,
                  left: edge == HazeEdge.right ? null : 0,
                  right: edge == HazeEdge.left ? null : 0,
                  height: vertical ? constraints.maxHeight * 0.55 : null,
                  width: vertical ? null : constraints.maxWidth * 0.62,
                  child: IgnorePointer(
                    child: Haze(
                      edge: edge,
                      sigma: sigma,
                      falloff: falloff,
                      extent: extent,
                      tint: tint,
                      tintOpacity: tintOpacity,
                      child: caption
                          ? _Caption(photo: photo, edge: edge)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({required this.photo, required this.edge});

  final Photo photo;
  final HazeEdge edge;

  @override
  Widget build(BuildContext context) {
    final onTop = edge == HazeEdge.top;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: onTop
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            photo.place.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w600,
              color: Color(0xB3FFFFFF),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            photo.title,
            style: const TextStyle(
              fontSize: 26,
              height: 1.1,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              color: CupertinoColors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            photo.story,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              height: 1.3,
              color: Color(0xD9FFFFFF),
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating panel, same radius and shadow as the photo card.
class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.edge,
    required this.sigma,
    required this.tintOpacity,
    required this.falloff,
    required this.extent,
    required this.tint,
    required this.swatches,
    required this.caption,
    required this.onEdge,
    required this.onSigma,
    required this.onTintOpacity,
    required this.onFalloff,
    required this.onExtent,
    required this.onTint,
    required this.onCaption,
  });

  final HazeEdge edge;
  final double sigma;
  final double tintOpacity;
  final double falloff;
  final double extent;
  final Color? tint;
  final List<Color?> swatches;
  final bool caption;
  final ValueChanged<HazeEdge> onEdge;
  final ValueChanged<double> onSigma;
  final ValueChanged<double> onTintOpacity;
  final ValueChanged<double> onFalloff;
  final ValueChanged<double> onExtent;
  final ValueChanged<Color?> onTint;
  final ValueChanged<bool> onCaption;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
          context,
        ),
        borderRadius: BorderRadius.circular(kRadius),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoSlidingSegmentedControl<HazeEdge>(
              groupValue: edge,
              onValueChanged: (v) => v == null ? null : onEdge(v),
              children: const {
                HazeEdge.top: Text('Top'),
                HazeEdge.bottom: Text('Bottom'),
                HazeEdge.left: Text('Left'),
                HazeEdge.right: Text('Right'),
              },
            ),
            const SizedBox(height: 10),
            _SliderRow(
              label: 'sigma',
              value: sigma,
              min: 0,
              max: 40,
              onChanged: onSigma,
            ),
            _SliderRow(
              label: 'tintOpacity',
              value: tintOpacity,
              min: 0,
              max: 1,
              onChanged: onTintOpacity,
            ),
            _SliderRow(
              label: 'falloff',
              value: falloff,
              min: 0.4,
              max: 4,
              onChanged: onFalloff,
            ),
            _SliderRow(
              label: 'extent',
              value: extent,
              min: 0.2,
              max: 1,
              onChanged: onExtent,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const _Label('tint'),
                for (final swatch in swatches)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _Swatch(
                      color: swatch,
                      selected: swatch?.toARGB32() == tint?.toARGB32(),
                      onTap: () => onTint(swatch),
                    ),
                  ),
              ],
            ),
            Row(
              children: [
                const _Label('caption'),
                CupertinoSwitch(value: caption, onChanged: onCaption),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 86,
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
    ),
  );
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  /// Null is the "no tint" option — blur only.
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color:
              color ?? CupertinoColors.tertiarySystemFill.resolveFrom(context),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? CupertinoColors.activeBlue
                : CupertinoColors.separator.resolveFrom(context),
            width: selected ? 2.5 : 1,
          ),
        ),
        child: color == null
            ? Icon(
                CupertinoIcons.slash_circle,
                size: 14,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              )
            : null,
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
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
        _Label(label),
        Expanded(
          child: CupertinoSlider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            value.toStringAsFixed(max <= 1 ? 2 : 1),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
        ),
      ],
    );
  }
}

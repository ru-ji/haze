import 'package:flutter/cupertino.dart';
import 'package:haze/haze.dart';

import 'photo_page.dart';
import 'photos.dart';
import 'zoom_press.dart';

void main() => runApp(const HazeGalleryApp());

/// Widest the gallery column ever gets — on the web the page centres inside
/// this instead of stretching a phone layout across a desktop.
const double kContentWidth = 620;

/// Shared with the detail page so cards, panels and paddings line up.
const double kInset = 50;
const double kRadius = 26;

class HazeGalleryApp extends StatelessWidget {
  const HazeGalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(title: 'Haze', home: GalleryPage());
  }
}

class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: Stack(
        children: [
          Center(
            child: SizedBox(
              width: kContentWidth,
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(kInset, top + 72, kInset, 72),
                itemCount: photos.length,
                separatorBuilder: (_, _) => const SizedBox(height: 40),
                itemBuilder: (context, i) => _PhotoCard(photo: photos[i]),
              ),
            ),
          ),

          // The navigation bar: no opaque fill, just a Haze hugging the top
          // edge so the photos melt into the status bar as they scroll under.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: top + 52,
            child: Haze(
              edge: HazeEdge.top,
              sigma: 7,
              falloff: 2.8,
              tint: CupertinoColors.systemGroupedBackground.resolveFrom(context),
              tintOpacity: 0.72,
              child: Padding(
                padding: EdgeInsets.only(top: top),
                child: Center(
                  child: Text(
                    'Haze',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.photo});

  final Photo photo;

  @override
  Widget build(BuildContext context) {
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
          child: ZoomPress(
            onTap: () => Navigator.of(context).push(
              CupertinoPageRoute<void>(builder: (_) => PhotoPage(photo: photo)),
            ),
            child: PhotoImage(photo: photo),
          ),
        ),
      ),
    );
  }
}

/// Network photo with a coloured placeholder, so the layout never jumps and
/// the blur has something to chew on from the first frame.
class PhotoImage extends StatelessWidget {
  const PhotoImage({super.key, required this.photo, this.width = 1200});

  final Photo photo;
  final double width;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: photo.placeholder,
      child: Image.network(
        photo.url(width),
        fit: BoxFit.cover,
        frameBuilder: (context, child, frame, wasSync) => AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 260),
          child: child,
        ),
        errorBuilder: (context, _, _) => const SizedBox.expand(),
      ),
    );
  }
}

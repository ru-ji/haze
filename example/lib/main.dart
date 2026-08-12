import 'package:flutter/cupertino.dart';
import 'package:haze/haze.dart';

import 'photo_page.dart';
import 'photos.dart';

void main() => runApp(const HazeGalleryApp());

class HazeGalleryApp extends StatelessWidget {
  const HazeGalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'Haze',
      theme: CupertinoThemeData(brightness: Brightness.dark),
      home: GalleryPage(),
    );
  }
}

class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF07070A),
      child: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Hero(topPadding: top)),
              const SliverToBoxAdapter(child: _SectionTitle('Recently added')),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.78,
                      ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _PhotoCard(photo: photos[i + 1]),
                    childCount: photos.length - 1,
                  ),
                ),
              ),
            ],
          ),

          // The navigation bar: no opaque background, just a Haze hugging the
          // top edge so the scrolling photos melt into the status bar.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: top + 52,
            child: Haze(
              edge: HazeEdge.top,
              sigma: 16,
              tint: const Color(0xFF07070A),
              tintOpacity: 0.55,
              child: Padding(
                padding: EdgeInsets.only(top: top),
                child: const _NavBarContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBarContent extends StatelessWidget {
  const _NavBarContent();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: () {},
            child: const Icon(CupertinoIcons.slider_horizontal_3, size: 22),
          ),
          const Spacer(),
          const Text(
            'Haze',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.white,
            ),
          ),
          const Spacer(),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: () {},
            child: const Icon(CupertinoIcons.square_grid_2x2, size: 22),
          ),
        ],
      ),
    );
  }
}

/// Full-bleed cover photo whose caption sits on a bottom-edge Haze.
class _Hero extends StatelessWidget {
  const _Hero({required this.topPadding});

  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final photo = photos.first;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute<void>(builder: (_) => PhotoPage(photo: photo)),
      ),
      child: SizedBox(
        height: 460 + topPadding,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _Photo(photo: photo),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 220,
              child: Haze(
                edge: HazeEdge.bottom,
                sigma: 24,
                tint: CupertinoColors.black,
                tintOpacity: 0.5,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        photo.place.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w600,
                          color: Color(0xCCFFFFFF),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        photo.title,
                        style: const TextStyle(
                          fontSize: 34,
                          height: 1.1,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Row(
                        children: [
                          Icon(
                            CupertinoIcons.person_crop_circle,
                            size: 16,
                            color: Color(0xCCFFFFFF),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Featured story',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xCCFFFFFF),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: CupertinoColors.white,
            ),
          ),
          const Icon(
            CupertinoIcons.chevron_right,
            size: 18,
            color: CupertinoColors.systemGrey,
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
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute<void>(builder: (_) => PhotoPage(photo: photo)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _Photo(photo: photo),
            // Rounded to match the card, so the blur never spills past it.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 110,
              child: Haze(
                edge: HazeEdge.bottom,
                sigma: 14,
                tint: CupertinoColors.black,
                tintOpacity: 0.45,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        photo.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        photo.place,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xB3FFFFFF),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Network photo with a coloured placeholder, so the layout never jumps.
class _Photo extends StatelessWidget {
  const _Photo({required this.photo});

  final Photo photo;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: photo.placeholder,
      child: Image.network(
        photo.url,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const Center(child: CupertinoActivityIndicator()),
        errorBuilder: (context, _, _) => const SizedBox.expand(),
      ),
    );
  }
}

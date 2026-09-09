import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:haze/haze.dart';

import 'album.dart';

void main() => runApp(const HazeExampleApp());

const accent = Color(0xFFFA2B56);
const kNavBarHeight = 52.0;
const kMiniPlayerHeight = 64.0;
const kTabBarHeight = 54.0;

const kSigma = 10.0;

/// Room the band keeps for the fade, below the chrome it covers. The bar rides
/// the full-strength part, the ramp happens in the empty space under it.
/// `Haze.fadeRoom(sigma)` computes the smallest value that works; 60 is that
/// for a sigma of 10 (60.7), rounded up.
const kFade = 64.0;
const hairline = Color(0x1FFFFFFF);

class HazeExampleApp extends StatelessWidget {
  const HazeExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'Haze',
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: accent,
        scaffoldBackgroundColor: Color(0xFF000000),
      ),
      home: AlbumPage(),
    );
  }
}

/// An album screen, close enough to the system one that the only thing left to
/// look at is the two bands: content passing under the bar at the top and the
/// player at the bottom, blurred harder the closer it gets to the edge.
class AlbumPage extends StatefulWidget {
  const AlbumPage({super.key});

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context);
    // The chrome, and the band that covers it plus its fade.
    final topChrome = inset.top + kNavBarHeight;
    final bottomChrome = inset.bottom + kMiniPlayerHeight + kTabBarHeight;

    return CupertinoPageScaffold(
      child: Stack(
        children: [
          const _Ambience(),
          CustomScrollView(
            controller: _scroll,
            slivers: [
              // The list runs the full height of the screen and slides under
              // both bands; the padding is only what keeps its two ends
              // reachable.
              SliverPadding(
                padding: EdgeInsets.only(top: topChrome),
                sliver: const SliverToBoxAdapter(child: _AlbumHeader()),
              ),
              SliverList.builder(
                itemCount: tracks.length,
                itemBuilder: (context, i) =>
                    _TrackRow(index: i, track: tracks[i]),
              ),
              SliverPadding(
                padding: EdgeInsets.only(bottom: bottomChrome + 28),
                sliver: const SliverToBoxAdapter(child: _AlbumFooter()),
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topChrome + kFade,
            child: Haze(
              edge: HazeEdge.top,
              sigma: kSigma,
              // Hold as long as this rectangle can afford — which, with kFade
              // of room under the bar, is exactly the bar.
              plateau: .5,
              tint: CupertinoColors.black,
              tintOpacity: 0.3,
              child: Align(
                alignment: Alignment.topCenter,
                child: _NavBar(scroll: _scroll, topInset: inset.top),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: bottomChrome + kFade,
            child: Haze(
              edge: HazeEdge.bottom,
              sigma: kSigma - 5,
              plateau: .6,
              tint: CupertinoColors.black,
              tintOpacity: 0.2,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _PlayerDock(bottomInset: inset.bottom),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The sleeve, blown up and blurred behind the top of the page — the wash the
/// system puts behind a now-playing screen, and something with real structure
/// for the top band to eat into.
class _Ambience extends StatelessWidget {
  const _Ambience();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 480,
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 48, sigmaY: 48),
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
            stops: [0.4, 1],
          ).createShader(rect),
          child: const Opacity(opacity: 0.7, child: Sleeve()),
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.scroll, required this.topInset});

  final ScrollController scroll;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topInset),
      child: SizedBox(
        height: kNavBarHeight,
        child: Row(
          children: [
            CupertinoButton(
              padding: const EdgeInsets.only(left: 6, right: 8),
              minimumSize: const Size(44, 44),
              onPressed: () {},
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.back, size: 26, color: accent),
                  Text(
                    'Library',
                    style: TextStyle(
                      fontSize: 17,
                      letterSpacing: -0.4,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: scroll,
                builder: (context, _) {
                  // The title trades places with the sleeve: it fades in over
                  // the stretch where the artwork leaves under the bar.
                  final t = scroll.hasClients
                      ? ((scroll.offset - 200) / 60).clamp(0.0, 1.0)
                      : 0.0;
                  return Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, (1 - t) * 10),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            albumTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                              color: CupertinoColors.white,
                            ),
                          ),
                          Text(
                            albumArtist,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: -0.1,
                              color: Color(0x99FFFFFF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const _GlassButton(CupertinoIcons.shuffle),
            const SizedBox(width: 8),
            const _GlassButton(CupertinoIcons.ellipsis),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

/// The round translucent control the system puts in a bar over content.
class _GlassButton extends StatelessWidget {
  const _GlassButton(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0x24FFFFFF),
        ),
        child: Icon(icon, size: 15, color: CupertinoColors.white),
      ),
    );
  }
}

class _AlbumHeader extends StatelessWidget {
  const _AlbumHeader();

  @override
  Widget build(BuildContext context) {
    final side = (MediaQuery.sizeOf(context).width * 0.62).clamp(180.0, 290.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        children: [
          Container(
            width: side,
            height: side,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xA6000000),
                  blurRadius: 34,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x1AFFFFFF)),
            ),
            child: const Sleeve(),
          ),
          const SizedBox(height: 18),
          const Text(
            albumTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.6,
              color: CupertinoColors.white,
            ),
          ),
          const SizedBox(height: 1),
          const Text(
            albumArtist,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, letterSpacing: -0.6, color: accent),
          ),
          const SizedBox(height: 8),
          const Text(
            albumMeta,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: Color(0x8CFFFFFF),
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(child: _BigButton(CupertinoIcons.play_fill, 'Play')),
              SizedBox(width: 12),
              Expanded(child: _BigButton(CupertinoIcons.shuffle, 'Shuffle')),
            ],
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(12),
      color: const Color(0x1FFFFFFF),
      onPressed: () {},
      child: SizedBox(
        height: 48,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({required this.index, required this.track});

  final int index;
  final Track track;

  /// The track the mini player is on gets the system's playing state: accent
  /// number, and the little level meter instead of a digit.
  bool get playing => track.title == 'Fog Bank';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Container(
        height: 52,
        padding: const EdgeInsets.only(right: 20),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: hairline, width: 0.5)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: playing
                  ? const Icon(
                      CupertinoIcons.speaker_2_fill,
                      size: 14,
                      color: accent,
                    )
                  : Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0x80FFFFFF),
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
            ),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        letterSpacing: -0.3,
                        color: playing ? accent : CupertinoColors.white,
                      ),
                    ),
                  ),
                  if (track.explicit) ...[
                    const SizedBox(width: 6),
                    const _ExplicitBadge(),
                  ],
                ],
              ),
            ),
            Text(
              track.duration,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0x66FFFFFF),
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 14),
            const Icon(
              CupertinoIcons.ellipsis,
              size: 17,
              color: Color(0x66FFFFFF),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExplicitBadge extends StatelessWidget {
  const _ExplicitBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0x59FFFFFF),
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Text(
        'E',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          height: 1.1,
          color: Color(0xFF1C1C1E),
        ),
      ),
    );
  }
}

class _AlbumFooter extends StatelessWidget {
  const _AlbumFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '12 songs · 57 minutes',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0x99FFFFFF),
                ),
              ),
              SizedBox(height: 8),
              Text(
                albumNote,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: Color(0x73FFFFFF),
                ),
              ),
              SizedBox(height: 8),
              Text(
                albumRelease,
                style: TextStyle(fontSize: 12, color: Color(0x59FFFFFF)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'More by $albumArtist',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: CupertinoColors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: related.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final (title, artist, colors) = related[i];
              return SizedBox(
                width: 140,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 140,
                        height: 140,
                        child: Sleeve(colors: colors),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        letterSpacing: -0.2,
                        color: CupertinoColors.white,
                      ),
                    ),
                    Text(
                      artist,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0x8CFFFFFF),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Mini player and tab bar. Both live inside the bottom band, so the list
/// scrolls up into them and dissolves rather than stopping on a line.
class _PlayerDock extends StatelessWidget {
  const _PlayerDock({required this.bottomInset});

  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: kMiniPlayerHeight,
          decoration: const BoxDecoration(
            // The hairline the system keeps even over a blur — it is what
            // says the dock is a surface and not part of the page.
            border: Border(
              top: BorderSide(color: Color(0x26FFFFFF), width: 0.5),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              const ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(6)),
                child: SizedBox(width: 44, height: 44, child: Sleeve()),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fog Bank',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        letterSpacing: -0.2,
                        color: CupertinoColors.white,
                      ),
                    ),
                    Text(
                      albumArtist,
                      maxLines: 1,
                      style: TextStyle(fontSize: 13, color: Color(0x8CFFFFFF)),
                    ),
                  ],
                ),
              ),
              const _DockButton(CupertinoIcons.pause_fill),
              const _DockButton(CupertinoIcons.forward_fill),
              const SizedBox(width: 10),
            ],
          ),
        ),
        SizedBox(
          height: kTabBarHeight,
          child: Row(
            children: const [
              _Tab(CupertinoIcons.house_fill, 'Home'),
              _Tab(CupertinoIcons.square_grid_2x2_fill, 'New'),
              _Tab(CupertinoIcons.dot_radiowaves_left_right, 'Radio'),
              _Tab(CupertinoIcons.music_albums_fill, 'Library', active: true),
              _Tab(CupertinoIcons.search, 'Search'),
            ],
          ),
        ),
        SizedBox(height: bottomInset),
      ],
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 44),
      onPressed: () {},
      child: Icon(icon, size: 24, color: CupertinoColors.white),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab(this.icon, this.label, {this.active = false});

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? accent : const Color(0x8CFFFFFF);
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 23, color: color),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

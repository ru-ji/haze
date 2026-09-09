import 'package:flutter/cupertino.dart';

class Track {
  const Track(this.title, this.duration, {this.explicit = false});
  final String title;
  final String duration;
  final bool explicit;
}

/// The record on screen. Fictional, and the sleeve is painted rather than
/// downloaded — a stock photograph never reads as an album cover.
const albumTitle = 'Coastal Signals';
const albumArtist = 'Marin Vale';
const albumMeta = 'AMBIENT · 2025';
const albumNote =
    'Recorded over two winters in a converted lighthouse, mostly at night, '
    'mostly on tape.';
const albumRelease = 'Released 14 November 2025 · ℗ 2025 Northlight';

const tracks = <Track>[
  Track('Low Tide, No Wind', '4:12'),
  Track('Harbour Lights', '3:48'),
  Track('Signal Fade', '6:05'),
  Track('The Long Room', '5:21'),
  Track('Salt in the Tape', '4:02', explicit: true),
  Track('Winter Rota', '3:35'),
  Track('Fog Bank', '7:19'),
  Track('Every Ninth Second', '4:44'),
  Track('Stone Stairwell', '3:07'),
  Track('Two Winters', '5:58'),
  Track('Lamp Room (Reprise)', '2:31'),
  Track('Morning Boats', '6:40'),
];

const related = <(String, String, List<Color>)>[
  ('Northlight', 'Marin Vale', [Color(0xFF243B55), Color(0xFF0B1119)]),
  ('Tape Hiss Vol. 2', 'Marin Vale', [Color(0xFF4A2B3C), Color(0xFF140C11)]),
  ('Slow Rotation', 'Aster Kell', [Color(0xFF1F4740), Color(0xFF0A1412)]),
];

/// The sleeve: a dark field, a low horizon glow and the beam that gives the
/// record its title. Deterministic, no assets, and it holds up blown up to
/// the full width behind the top band.
class Sleeve extends StatelessWidget {
  const Sleeve({super.key, this.colors = const [
    Color(0xFF35506B),
    Color(0xFF0A0E14),
  ]});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The beam, off-centre and cut by the sleeve's own edges.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.35, -0.55),
                radius: 0.95,
                colors: [Color(0x9EFFE7C2), Color(0x00FFE7C2)],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x00000000), Color(0x66FFD9A0), Color(0x00000000)],
                stops: [0.18, 0.34, 0.62],
              ),
            ),
          ),
          // Horizon.
          const Align(
            alignment: Alignment(0, 0.34),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0x00FFFFFF), Color(0x8CFFFFFF), Color(0x00FFFFFF)],
                ),
              ),
              child: SizedBox(height: 1, width: double.infinity),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(0, 0.34),
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0xB3060A0F)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

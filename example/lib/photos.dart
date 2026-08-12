import 'package:flutter/painting.dart';

class Photo {
  const Photo({
    required this.id,
    required this.title,
    required this.place,
    required this.story,
    required this.placeholder,
  });

  final String id;
  final String title;
  final String place;
  final String story;

  /// Shown while the image loads — keeps the blur reading correctly from the
  /// very first frame.
  final Color placeholder;

  String get url => 'https://picsum.photos/seed/$id/1200/1600';
}

const photos = <Photo>[
  Photo(
    id: 'haze-dune',
    title: 'Light on the dunes',
    place: 'Erg Chebbi, Morocco',
    story:
        'Shot an hour before sunset, when the ridges hold the last warm light '
        'and everything below them has already gone blue.',
    placeholder: Color(0xFF7A5B3A),
  ),
  Photo(
    id: 'haze-fjord',
    title: 'Slow water',
    place: 'Geirangerfjord',
    story: 'Twenty minutes of nothing moving except the fog.',
    placeholder: Color(0xFF2C3E44),
  ),
  Photo(
    id: 'haze-city',
    title: 'Blue hour',
    place: 'Shibuya, Tokyo',
    story: 'Handheld, wide open, entirely too many people.',
    placeholder: Color(0xFF1E2233),
  ),
  Photo(
    id: 'haze-forest',
    title: 'Ferns',
    place: 'Olympic National Park',
    story: 'Green in a hundred slightly different ways.',
    placeholder: Color(0xFF24361F),
  ),
  Photo(
    id: 'haze-ridge',
    title: 'The ridge',
    place: 'Dolomites',
    story: 'We started walking at four in the morning for this.',
    placeholder: Color(0xFF4A4C57),
  ),
  Photo(
    id: 'haze-coast',
    title: 'Cold swim',
    place: 'Big Sur',
    story: 'The water was 11°C. Worth it.',
    placeholder: Color(0xFF1F4450),
  ),
  Photo(
    id: 'haze-desert',
    title: 'Salt flats',
    place: 'Uyuni, Bolivia',
    story: 'No horizon to speak of, just a seam where two whites meet.',
    placeholder: Color(0xFF8E8F94),
  ),
];

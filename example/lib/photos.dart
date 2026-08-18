import 'package:flutter/painting.dart';

class Photo {
  const Photo({
    required this.id,
    required this.title,
    required this.place,
    required this.story,
    required this.placeholder,
  });

  /// Lorem Picsum photo id — stable, so the gallery always looks the same.
  final int id;
  final String title;
  final String place;
  final String story;

  /// Shown while the image loads — keeps the blur reading correctly from the
  /// very first frame.
  final Color placeholder;

  String url(double width) =>
      'https://picsum.photos/id/$id/${width.round()}/${(width * 0.75).round()}';
}

const photos = <Photo>[
  Photo(
    id: 1025,
    title: 'Good boy',
    place: 'Studio, afternoon',
    story: 'He held the pose for exactly one frame.',
    placeholder: Color(0xFF8C7A6B),
  ),
  Photo(
    id: 1015,
    title: 'River stones',
    place: 'Somewhere upstream',
    story: 'Cold water, warm rock, nothing else for an hour.',
    placeholder: Color(0xFF9AA3A8),
  ),
  Photo(
    id: 1043,
    title: 'Through the canopy',
    place: 'Old growth',
    story: 'Green in a hundred slightly different ways.',
    placeholder: Color(0xFF3F5A3A),
  ),
  Photo(
    id: 1039,
    title: 'The drop',
    place: 'Waterfall, no name',
    story: 'We started walking at four in the morning for this.',
    placeholder: Color(0xFF4A5C55),
  ),
  Photo(
    id: 1016,
    title: 'Canyon light',
    place: 'Late october',
    story: 'An hour before sunset, when the ridges hold the last warm light.',
    placeholder: Color(0xFF8A6A4E),
  ),
  Photo(
    id: 1024,
    title: 'Undergrowth',
    place: 'Forest floor',
    story: 'Everything at this scale is somebody else’s architecture.',
    placeholder: Color(0xFF5B5343),
  ),
  Photo(
    id: 1069,
    title: 'Blue hour',
    place: 'Rooftop',
    story: 'Handheld, wide open, entirely too much wind.',
    placeholder: Color(0xFF2C3547),
  ),
  Photo(
    id: 1050,
    title: 'Slow water',
    place: 'The bay',
    story: 'Twenty minutes of nothing moving except the fog.',
    placeholder: Color(0xFF6E7C84),
  ),
];

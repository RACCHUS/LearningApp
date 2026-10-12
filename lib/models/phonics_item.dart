import 'package:learning_pwa/models/pre_reader_profile.dart';

class PhonicsAnchor {
  final String label;
  final String emoji;
  final bool isCorrect;

  const PhonicsAnchor({
    required this.label,
    required this.emoji,
    required this.isCorrect,
  });
}

class PhonicsItem {
  final String letter;
  final String phonemeSound;
  final String explanation;
  final List<PhonicsAnchor> adultAnchors;
  final List<PhonicsAnchor> youthAnchors;

  const PhonicsItem({
    required this.letter,
    required this.phonemeSound,
    required this.explanation,
    required this.adultAnchors,
    required this.youthAnchors,
  });

  List<PhonicsAnchor> anchorsFor(PreReaderTrack track) {
    return track == PreReaderTrack.youth ? youthAnchors : adultAnchors;
  }
}

/// Curated foundational phonics catalog (Orton-Gillingham progression)
/// allowing pre-readers to immediately connect letter shapes, pure sounds,
/// and track-specific visual anchors.
final List<PhonicsItem> foundationalPhonicsCatalog = [
  const PhonicsItem(
    letter: 'M',
    phonemeSound: '/m/',
    explanation: 'M makes the /m/ sound.',
    adultAnchors: [
      PhonicsAnchor(label: 'Money', emoji: '💵', isCorrect: true),
      PhonicsAnchor(label: 'Car', emoji: '🚗', isCorrect: false),
      PhonicsAnchor(label: 'Phone', emoji: '📱', isCorrect: false),
    ],
    youthAnchors: [
      PhonicsAnchor(label: 'Monkey', emoji: '🐵', isCorrect: true),
      PhonicsAnchor(label: 'Ball', emoji: '⚽', isCorrect: false),
      PhonicsAnchor(label: 'Cat', emoji: '🐱', isCorrect: false),
    ],
  ),
  const PhonicsItem(
    letter: 'S',
    phonemeSound: '/s/',
    explanation: 'S makes the /s/ sound.',
    adultAnchors: [
      PhonicsAnchor(label: 'Stop sign', emoji: '🛑', isCorrect: true),
      PhonicsAnchor(label: 'Water', emoji: '💧', isCorrect: false),
      PhonicsAnchor(label: 'Clock', emoji: '⏰', isCorrect: false),
    ],
    youthAnchors: [
      PhonicsAnchor(label: 'Sun', emoji: '☀️', isCorrect: true),
      PhonicsAnchor(label: 'Tree', emoji: '🌳', isCorrect: false),
      PhonicsAnchor(label: 'Dog', emoji: '🐶', isCorrect: false),
    ],
  ),
  const PhonicsItem(
    letter: 'A',
    phonemeSound: '/æ/',
    explanation: 'A makes the short /æ/ sound.',
    adultAnchors: [
      PhonicsAnchor(label: 'Apple', emoji: '🍎', isCorrect: true),
      PhonicsAnchor(label: 'Door', emoji: '🚪', isCorrect: false),
      PhonicsAnchor(label: 'Tool', emoji: '🔧', isCorrect: false),
    ],
    youthAnchors: [
      PhonicsAnchor(label: 'Apple', emoji: '🍎', isCorrect: true),
      PhonicsAnchor(label: 'Fish', emoji: '🐟', isCorrect: false),
      PhonicsAnchor(label: 'House', emoji: '🏠', isCorrect: false),
    ],
  ),
  const PhonicsItem(
    letter: 'B',
    phonemeSound: '/b/',
    explanation: 'B makes the /b/ sound.',
    adultAnchors: [
      PhonicsAnchor(label: 'Bus', emoji: '🚌', isCorrect: true),
      PhonicsAnchor(label: 'Hospital', emoji: '🏥', isCorrect: false),
      PhonicsAnchor(label: 'Key', emoji: '🔑', isCorrect: false),
    ],
    youthAnchors: [
      PhonicsAnchor(label: 'Bear', emoji: '🐻', isCorrect: true),
      PhonicsAnchor(label: 'Star', emoji: '⭐', isCorrect: false),
      PhonicsAnchor(label: 'Flower', emoji: '🌸', isCorrect: false),
    ],
  ),
  const PhonicsItem(
    letter: 'T',
    phonemeSound: '/t/',
    explanation: 'T makes the /t/ sound.',
    adultAnchors: [
      PhonicsAnchor(label: 'Truck', emoji: '🚚', isCorrect: true),
      PhonicsAnchor(label: 'Coffee', emoji: '☕', isCorrect: false),
      PhonicsAnchor(label: 'Bag', emoji: '👜', isCorrect: false),
    ],
    youthAnchors: [
      PhonicsAnchor(label: 'Train', emoji: '🚂', isCorrect: true),
      PhonicsAnchor(label: 'Moon', emoji: '🌙', isCorrect: false),
      PhonicsAnchor(label: 'Duck', emoji: '🦆', isCorrect: false),
    ],
  ),
];

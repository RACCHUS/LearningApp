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
  final String letterName;
  final String phonemeSound;
  final bool isVowel;
  final String explanation;
  final List<PhonicsAnchor> adultAnchors;
  final List<PhonicsAnchor> youthAnchors;

  const PhonicsItem({
    required this.letter,
    required this.letterName,
    required this.phonemeSound,
    this.isVowel = false,
    required this.explanation,
    required this.adultAnchors,
    required this.youthAnchors,
  });

  List<PhonicsAnchor> anchorsFor(PreReaderTrack track) {
    return track == PreReaderTrack.youth ? youthAnchors : adultAnchors;
  }
}

/// Comprehensive 26-Letter Foundational Phonics Catalog
///
/// Designed in accordance with Orton-Gillingham scope and the Science of Reading.
/// Each letter features:
/// - Letter Name (for spelling personal names and completing administrative forms)
/// - Pure Phoneme Sound (isolated sound for decoding)
/// - Concrete, singular, picturable adult anchors (everyday independence, work, tools, cash)
/// - Playful, vibrant youth anchors (animals, nature, toys)
final List<PhonicsItem> foundationalPhonicsCatalog = [
  const PhonicsItem(
    letter: 'A',
    letterName: 'Ay',
    phonemeSound: 'ah',
    isVowel: true,
    explanation: 'A makes the short "ah" sound.',
    adultAnchors: [
      PhonicsAnchor(label: 'Apple', emoji: '🍎', isCorrect: true),
      PhonicsAnchor(label: 'Door', emoji: '🚪', isCorrect: false),
      PhonicsAnchor(label: 'Hammer', emoji: '🔨', isCorrect: false),
    ],
    youthAnchors: [
      PhonicsAnchor(label: 'Apple', emoji: '🍎', isCorrect: true),
      PhonicsAnchor(label: 'Fish', emoji: '🐟', isCorrect: false),
      PhonicsAnchor(label: 'House', emoji: '🏠', isCorrect: false),
    ],
  ),
  const PhonicsItem(
    letter: 'B',
    letterName: 'Bee',
    phonemeSound: 'b',
    explanation: 'B makes the "b" sound.',
    adultAnchors: [
      PhonicsAnchor(label: 'Bus', emoji: '🚌', isCorrect: true),
      PhonicsAnchor(label: 'Key', emoji: '🔑', isCorrect: false),
      PhonicsAnchor(label: 'Hospital', emoji: '🏥', isCorrect: false),
    ],
    youthAnchors: [
      PhonicsAnchor(label: 'Bear', emoji: '🐻', isCorrect: true),
      PhonicsAnchor(label: 'Star', emoji: '⭐', isCorrect: false),
      PhonicsAnchor(label: 'Flower', emoji: '🌸', isCorrect: false),
    ],
  ),
  const PhonicsItem(
    letter: 'C',
    letterName: 'See',
    phonemeSound: 'k',
    explanation: 'C makes the "k" sound.',
    adultAnchors: [
      PhonicsAnchor(label: 'Car', emoji: '🚗', isCorrect: true),
      PhonicsAnchor(label: 'Phone', emoji: '📱', isCorrect: false),
      PhonicsAnchor(label: 'Pen', emoji: '🖊️', isCorrect: false),
    ],
    youthAnchors: [
      PhonicsAnchor(label: 'Cat', emoji: '🐱', isCorrect: true),
      PhonicsAnchor(label: 'Sun', emoji: '☀️', isCorrect: false),
      PhonicsAnchor(label: 'Moon', emoji: '🌙', isCorrect: false),
    ],
  ),
  const PhonicsItem(
    letter: 'D',
    letterName: 'Dee',
    phonemeSound: 'd',
    explanation: 'D makes the "d" sound.',
    adultAnchors: [
      PhonicsAnchor(label: 'Door', emoji: '🚪', isCorrect: true),
      PhonicsAnchor(label: 'Cup', emoji: '☕', isCorrect: false),
      PhonicsAnchor(label: 'Bed', emoji: '🛏️', isCorrect: false),
    ],
    youthAnchors: [
      PhonicsAnchor(label: 'Dog', emoji: '🐶', isCorrect: true),
      PhonicsAnchor(label: 'Tree', emoji: '🌳', isCorrect: false),
      PhonicsAnchor(label: 'Bird', emoji: '🐦', isCorrect: false),
    ],
  ),
  const PhonicsItem(
    letter: 'E',
    letterName: 'Ee',
    phonemeSound: 'eh',
    isVowel: true,
    explanation: 'E makes the short "eh" sound.',
    adultAnchors: [
      PhonicsAnchor(label: 'Egg', emoji: '🥚', isCorrect: true),
      PhonicsAnchor(label: 'Clock', emoji: '⏰', isCorrect: false),
      PhonicsAnchor(label: 'Truck', emoji: '🚚', isCorrect: false),
    ],
    youthAnchors: [
      PhonicsAnchor(label: 'Elephant', emoji: '🐘', isCorrect: true),
      PhonicsAnchor(label: 'Car', emoji: '🚗', isCorrect: false),
      PhonicsAnchor(label: 'Ball', emoji: '⚽', isCorrect: false),
    ],
  ),
  const PhonicsItem(
    letter: 'F',
    letterName: 'Ef',
    phonemeSound: 'f',
    explanation: 'F makes the "f" sound.',
    adultAnchors: [
      PhonicsAnchor(label: 'Fork', emoji: '🍴', isCorrect: true),
      PhonicsAnchor(label: 'Box', emoji: '📦', isCorrect: false),
      PhonicsAnchor(label: 'Shirt', emoji: '👕', isCorrect: false),
    ],
    youthAnchors: [
      PhonicsAnchor(label: 'Fish', emoji: '🐟', isCorrect: true),
      PhonicsAnchor(label: 'Boat', emoji: '⛵', isCorrect: false),
      PhonicsAnchor(label: 'Hat', emoji: '🎩', isCorrect: false),
    ],
  ),
  const PhonicsItem(
    letter: 'G',
    letterName: 'Gee',
    phonemeSound: 'g',
    explanation: 'G makes the hard "g" sound.',
    adultAnchors: [
      PhonicsAnchor(label: 'Gas pump', emoji: '⛽', isCorrect: true),
      PhonicsAnchor(label: 'Watch', emoji: '⌚', isCorrect: false),
      PhonicsAnchor(label: 'Plate', emoji: '🍽️', isCorrect: false),
    ],
    youthAnchors: [
      PhonicsAnchor(label: 'Giraffe', emoji: '🦒', isCorrect: true),
      PhonicsAnchor(label: 'Kite', emoji: '🪁', isCorrect: false),
      PhonicsAnchor(label: 'Shoe', emoji: '👟', isCorrect: false),
    ],
  ),
  const PhonicsItem(
    letter: 'H',
    letterName: 'Aytch',
    phonemeSound: 'h',
    explanation: 'H makes the "h" sound.',
    adultAnchors: [
      PhonicsAnchor(label: 'Hat', emoji: '🎩', isCorrect: true),
      PhonicsAnchor(label: 'Shoe', emoji: '👟', isCorrect: false),
      PhonicsAnchor(label: 'Map', emoji: '🗺️', isCorrect: false),
    ],
    youthAnchors: [
      PhonicsAnchor(label: 'Horse', emoji: '🐴', isCorrect: true),
      PhonicsAnchor(label: 'Frog', emoji: '🐸', isCorrect: false),
      PhonicsAnchor(label: 'Cloud', emoji: '☁️', isCorrect: false),
    ],
  ),
  const PhonicsItem(
    letter: 'I',
    letterName: 'Eye',
    phonemeSound: 'ih',
    isVowel: true,
    explanation: 'I makes the short "ih" sound.',
    adultAnchors: [
      PhonicsAnchor(label: 'Ink pen', emoji: '✒️', isCorrect: true),
      PhonicsAnchor(label: 'Bag', emoji: '👜', isCorrect: false),
      PhonicsAnchor(label: 'Cup', emoji: '🥤', isCorrect: false),
    ],
    youthAnchors: [
      PhonicsAnchor(label: 'Igloo', emoji: '🧊', isCorrect: true),
      PhonicsAnchor(label: 'Duck', emoji: '🦆', isCorrect: false),
      PhonicsAnchor(label: 'Leaf', emoji: '🍃', isCorrect: false),
    ],
  ),
  const PhonicsItem(
    letter: 'J',
    letterName: 'Jay',
    phonemeSound: 'j',
    explanation: 'J makes the "j" sound.',
    adultAnchors: [
      PhonicsAnchor(label: 'Jacket', emoji: '🧥', isCorrect: true),
      PhonicsAnchor(label: 'Book', emoji: '📖', isCorrect: false),
      PhonicsAnchor(label: 'Pencil', emoji: '✏️', isCorrect: false),
    ],
    youthAnchors: [
      PhonicsAnchor(label: 'Juice', emoji: '🧃', isCorrect: true),
      PhonicsAnchor(label: 'Cake', emoji: '🎂', isCorrect: false),
      PhonicsAnchor(label: 'Drum', emoji: '🥁', isCorrect: false),
    ],
  ),
  const PhonicsItem(
    letter: 'K',
    letterName: 'Kay',
    phonemeSound: 'k',
    explanation: 'K makes the "k" sound.',
    adultAnchors: [
      PhonicsAnchor(label: 'Key', emoji: '🔑', isCorrect: true),
      PhonicsAnchor(label: 'Lamp', emoji: '💡', isCorrect: false),
      PhonicsAnchor(label: 'Chair', emoji: '🪑', isCorrect: false),
    ],
    youthAnchors: [
      PhonicsAnchor(label: 'Kangaroo', emoji: '🦘', isCorrect: true),
      PhonicsAnchor(label: 'Ball', emoji: '⚽', isCorrect: false),
      PhonicsAnchor(label: 'Apple', emoji: '🍎', isCorrect: false),
    ],
  ),
  const PhonicsItem(
    letter: 'L',
    letterName: 'El',
    phonemeSound: 'l',
    explanation: 'L makes the "l" sound.',
    adultAnchors: [
      PhonicsAnchor(label: 'Lock', emoji: '🔒', isCorrect: true),
      PhonicsAnchor(label: 'Bed', emoji: '🛏️', isCorrect: false),
      PhonicsAnchor(label: 'Clock', emoji: '⏰', isCorrect: false),
    ],
    youthAnchors: [
      PhonicsAnchor(label: 'Lion', emoji: '🦁', isCorrect: true),
      PhonicsAnchor(label: 'Moon', emoji: '🌙', isCorrect: false),
      PhonicsAnchor(label: 'Tree', emoji: '🌳', isCorrect: false),
    ],
  ),
  const PhonicsItem(
    letter: 'M',
    letterName: 'Em',
    phonemeSound: 'm',
    explanation: 'M makes the "m" sound.',
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
    letter: 'N',
    letterName: 'En',
    phonemeSound: 'n',
    explanation: 'N makes the "n" sound.',
    adultAnchors: [
      PhonicsAnchor(label: 'Nail', emoji: '🔩', isCorrect: true),
      PhonicsAnchor(label: 'Cup', emoji: '🥤', isCorrect: false),
      PhonicsAnchor(label: 'Shoe', emoji: '👟', isCorrect: false),
    ],
    youthAnchors: [
      PhonicsAnchor(label: 'Nest', emoji: '🪹', isCorrect: true),
      PhonicsAnchor(label: 'Dog', emoji: '🐶', isCorrect: false),
      PhonicsAnchor(label: 'Star', emoji: '⭐', isCorrect: false),
    ],
  ),
  const PhonicsItem(
    letter: 'O',
    letterName: 'Oh',
    phonemeSound: 'ah',
    isVowel: true,
    explanation: 'O makes the short "ah" sound.',
    adultAnchors: [
      PhonicsAnchor(label: 'On/Off button', emoji: '🔘', isCorrect: true),
      PhonicsAnchor(label: 'Truck', emoji: '🚚', isCorrect: false),
      PhonicsAnchor(label: 'Door', emoji: '🚪', isCorrect: false),
    ],
    youthAnchors: [
      PhonicsAnchor(label: 'Octopus', emoji: '🐙', isCorrect: true),
      PhonicsAnchor(label: 'Sun', emoji: '☀️', isCorrect: false),
      PhonicsAnchor(label: 'Bird', emoji: '🐦', isCorrect: false),
    ],
  ),
  const PhonicsItem(
    letter: 'P',
    letterName: 'Pee',
    phonemeSound: 'p',
    explanation: 'P makes the "p" sound.',
    adultAnchors: [
      PhonicsAnchor(label: 'Phone', emoji: '📱', isCorrect: true),
      PhonicsAnchor(label: 'Car', emoji: '🚗', isCorrect: false),
      PhonicsAnchor(label: 'Book', emoji: '📖', isCorrect: false),
    ],
    youthAnchors: [
      PhonicsAnchor(label: 'Pig', emoji: '🐷', isCorrect: true),
      PhonicsAnchor(label: 'Tree', emoji: '🌳', isCorrect: false),
      PhonicsAnchor(label: 'House', emoji: '🏠', isCorrect: false),
    ],
  ),
  const PhonicsItem(
    letter: 'Q',
    letterName: 'Cue',
    phonemeSound: 'kw',
    explanation: 'Q makes the "kw" sound.',
    adultAnchors: [
      PhonicsAnchor(label: 'Quarter coin', emoji: '🪙', isCorrect: true),
      PhonicsAnchor(label: 'Map', emoji: '🗺️', isCorrect: false),
      PhonicsAnchor(label: 'Bed', emoji: '🛏️', isCorrect: false),
    ],
    youthAnchors: [
      PhonicsAnchor(label: 'Queen', emoji: '👑', isCorrect: true),
      PhonicsAnchor(label: 'Fish', emoji: '🐟', isCorrect: false),
      PhonicsAnchor(label: 'Hat', emoji: '🎩', isCorrect: false),
    ],
  ),
  const PhonicsItem(
    letter: 'R',
    letterName: 'Ar',
    phonemeSound: 'r',
    explanation: 'R makes the "r" sound.',
    adultAnchors: [
      PhonicsAnchor(label: 'Radio', emoji: '📻', isCorrect: true),
      PhonicsAnchor(label: 'Clock', emoji: '⏰', isCorrect: false),
      PhonicsAnchor(label: 'Fork', emoji: '🍴', isCorrect: false),
    ],
    youthAnchors: [
      PhonicsAnchor(label: 'Rabbit', emoji: '🐰', isCorrect: true),
      PhonicsAnchor(label: 'Car', emoji: '🚗', isCorrect: false),
      PhonicsAnchor(label: 'Moon', emoji: '🌙', isCorrect: false),
    ],
  ),
  const PhonicsItem(
    letter: 'S',
    letterName: 'Ess',
    phonemeSound: 's',
    explanation: 'S makes the "s" sound.',
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
    letter: 'T',
    letterName: 'Tee',
    phonemeSound: 't',
    explanation: 'T makes the "t" sound.',
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
  const PhonicsItem(
    letter: 'U',
    letterName: 'You',
    phonemeSound: 'uh',
    isVowel: true,
    explanation: 'U makes the short "uh" sound.',
    adultAnchors: [
      PhonicsAnchor(label: 'Umbrella', emoji: '☂️', isCorrect: true),
      PhonicsAnchor(label: 'Key', emoji: '🔑', isCorrect: false),
      PhonicsAnchor(label: 'Shoe', emoji: '👟', isCorrect: false),
    ],
    youthAnchors: [
      PhonicsAnchor(label: 'Umbrella bird', emoji: '☂️', isCorrect: true),
      PhonicsAnchor(label: 'Ball', emoji: '⚽', isCorrect: false),
      PhonicsAnchor(label: 'Star', emoji: '⭐', isCorrect: false),
    ],
  ),
  const PhonicsItem(
    letter: 'V',
    letterName: 'Vee',
    phonemeSound: 'v',
    explanation: 'V makes the "v" sound.',
    adultAnchors: [
      PhonicsAnchor(label: 'Van', emoji: '🚐', isCorrect: true),
      PhonicsAnchor(label: 'Cup', emoji: '🥤', isCorrect: false),
      PhonicsAnchor(label: 'Door', emoji: '🚪', isCorrect: false),
    ],
    youthAnchors: [
      PhonicsAnchor(label: 'Violin', emoji: '🎻', isCorrect: true),
      PhonicsAnchor(label: 'Apple', emoji: '🍎', isCorrect: false),
      PhonicsAnchor(label: 'Dog', emoji: '🐶', isCorrect: false),
    ],
  ),
  const PhonicsItem(
    letter: 'W',
    letterName: 'Double-you',
    phonemeSound: 'w',
    explanation: 'W makes the "w" sound.',
    adultAnchors: [
      PhonicsAnchor(label: 'Water bottle', emoji: '🧴', isCorrect: true),
      PhonicsAnchor(label: 'Bed', emoji: '🛏️', isCorrect: false),
      PhonicsAnchor(label: 'Chair', emoji: '🪑', isCorrect: false),
    ],
    youthAnchors: [
      PhonicsAnchor(label: 'Whale', emoji: '🐋', isCorrect: true),
      PhonicsAnchor(label: 'Sun', emoji: '☀️', isCorrect: false),
      PhonicsAnchor(label: 'Tree', emoji: '🌳', isCorrect: false),
    ],
  ),
  const PhonicsItem(
    letter: 'X',
    letterName: 'Ex',
    phonemeSound: 'ks',
    explanation: 'X makes the "ks" sound (as in box).',
    adultAnchors: [
      PhonicsAnchor(label: 'Exit sign', emoji: '🚪', isCorrect: true),
      PhonicsAnchor(label: 'Phone', emoji: '📱', isCorrect: false),
      PhonicsAnchor(label: 'Car', emoji: '🚗', isCorrect: false),
    ],
    youthAnchors: [
      PhonicsAnchor(label: 'Xylophone', emoji: '🎵', isCorrect: true),
      PhonicsAnchor(label: 'Cat', emoji: '🐱', isCorrect: false),
      PhonicsAnchor(label: 'Bird', emoji: '🐦', isCorrect: false),
    ],
  ),
  const PhonicsItem(
    letter: 'Y',
    letterName: 'Why',
    phonemeSound: 'y',
    explanation: 'Y makes the "y" sound.',
    adultAnchors: [
      PhonicsAnchor(label: 'Yellow light', emoji: '🟡', isCorrect: true),
      PhonicsAnchor(label: 'Fork', emoji: '🍴', isCorrect: false),
      PhonicsAnchor(label: 'Watch', emoji: '⌚', isCorrect: false),
    ],
    youthAnchors: [
      PhonicsAnchor(label: 'Yo-yo', emoji: '🪀', isCorrect: true),
      PhonicsAnchor(label: 'Fish', emoji: '🐟', isCorrect: false),
      PhonicsAnchor(label: 'House', emoji: '🏠', isCorrect: false),
    ],
  ),
  const PhonicsItem(
    letter: 'Z',
    letterName: 'Zee',
    phonemeSound: 'z',
    explanation: 'Z makes the "z" sound.',
    adultAnchors: [
      PhonicsAnchor(label: 'Zipper', emoji: '🤐', isCorrect: true),
      PhonicsAnchor(label: 'Hat', emoji: '🎩', isCorrect: false),
      PhonicsAnchor(label: 'Cup', emoji: '🥤', isCorrect: false),
    ],
    youthAnchors: [
      PhonicsAnchor(label: 'Zebra', emoji: '🦓', isCorrect: true),
      PhonicsAnchor(label: 'Moon', emoji: '🌙', isCorrect: false),
      PhonicsAnchor(label: 'Star', emoji: '⭐', isCorrect: false),
    ],
  ),
];

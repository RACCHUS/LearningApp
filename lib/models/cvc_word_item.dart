/// A decodable 3-letter Consonant-Vowel-Consonant (CVC) word item.
///
/// Complies with the Science of Reading orthographic pattern ($C + V_{short} + C$).
/// Allows learners to practice onset-rime blending:
/// Onset (/k/) + Nucleus (/æ/) + Coda (/t/) -> Blended Word ("cat")
class CvcWordItem {
  final String word;
  final String onset;
  final String nucleus;
  final String coda;
  final String onsetSound;
  final String nucleusSound;
  final String codaSound;
  final String emoji;
  final String sentence;

  const CvcWordItem({
    required this.word,
    required this.onset,
    required this.nucleus,
    required this.coda,
    required this.onsetSound,
    required this.nucleusSound,
    required this.codaSound,
    required this.emoji,
    required this.sentence,
  });

  String get uppercaseWord => word.toUpperCase();
}

/// Curated adult and foundational decodable CVC word bank
final List<CvcWordItem> decodableCvcWordBank = [
  const CvcWordItem(
    word: 'CAT',
    onset: 'C',
    nucleus: 'A',
    coda: 'T',
    onsetSound: 'k',
    nucleusSound: 'ah',
    codaSound: 't',
    emoji: '🐱',
    sentence: 'The cat sits on the mat.',
  ),
  const CvcWordItem(
    word: 'MAP',
    onset: 'M',
    nucleus: 'A',
    coda: 'P',
    onsetSound: 'm',
    nucleusSound: 'ah',
    codaSound: 'p',
    emoji: '🗺️',
    sentence: 'Find the route on the map.',
  ),
  const CvcWordItem(
    word: 'BUS',
    onset: 'B',
    nucleus: 'U',
    coda: 'S',
    onsetSound: 'b',
    nucleusSound: 'uh',
    codaSound: 's',
    emoji: '🚌',
    sentence: 'Take the city bus to work.',
  ),
  const CvcWordItem(
    word: 'SUN',
    onset: 'S',
    nucleus: 'U',
    coda: 'N',
    onsetSound: 's',
    nucleusSound: 'uh',
    codaSound: 'n',
    emoji: '☀️',
    sentence: 'The sun is warm and bright.',
  ),
  const CvcWordItem(
    word: 'BED',
    onset: 'B',
    nucleus: 'E',
    coda: 'D',
    onsetSound: 'b',
    nucleusSound: 'eh',
    codaSound: 'd',
    emoji: '🛏️',
    sentence: 'Rest in a warm bed.',
  ),
  const CvcWordItem(
    word: 'PEN',
    onset: 'P',
    nucleus: 'E',
    coda: 'N',
    onsetSound: 'p',
    nucleusSound: 'eh',
    codaSound: 'n',
    emoji: '🖊️',
    sentence: 'Sign your name with a pen.',
  ),
  const CvcWordItem(
    word: 'CUP',
    onset: 'C',
    nucleus: 'U',
    coda: 'P',
    onsetSound: 'k',
    nucleusSound: 'uh',
    codaSound: 'p',
    emoji: '🥤',
    sentence: 'Drink water from the cup.',
  ),
  const CvcWordItem(
    word: 'BOX',
    onset: 'B',
    nucleus: 'O',
    coda: 'X',
    onsetSound: 'b',
    nucleusSound: 'ah',
    codaSound: 'ks',
    emoji: '📦',
    sentence: 'Lift the heavy box carefully.',
  ),
  const CvcWordItem(
    word: 'PIN',
    onset: 'P',
    nucleus: 'I',
    coda: 'N',
    onsetSound: 'p',
    nucleusSound: 'ih',
    codaSound: 'n',
    emoji: '📍',
    sentence: 'Put a pin on the board.',
  ),
  const CvcWordItem(
    word: 'HOT',
    onset: 'H',
    nucleus: 'O',
    coda: 'T',
    onsetSound: 'h',
    nucleusSound: 'ah',
    codaSound: 't',
    emoji: '☕',
    sentence: 'The hot soup is ready.',
  ),
  const CvcWordItem(
    word: 'RED',
    onset: 'R',
    nucleus: 'E',
    coda: 'D',
    onsetSound: 'r',
    nucleusSound: 'eh',
    codaSound: 'd',
    emoji: '🔴',
    sentence: 'Stop at the red light.',
  ),
  const CvcWordItem(
    word: 'HAT',
    onset: 'H',
    nucleus: 'A',
    coda: 'T',
    onsetSound: 'h',
    nucleusSound: 'ah',
    codaSound: 't',
    emoji: '🎩',
    sentence: 'Wear a safety hat at work.',
  ),
];

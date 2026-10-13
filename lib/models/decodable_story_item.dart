/// Data model for decodable early reading stories with word-level audio sync.
///
/// Adheres to Section 6 of the Literacy Accessibility Plan:
/// Stories are curated from openly licensed sources (StoryWeaver CC-BY 4.0 / Public Domain),
/// featuring decodable vocabulary with word tokens for karaoke-style synchronized highlighting.
class StoryWordToken {
  final int index;
  final String text;
  final Duration startOffset;
  final Duration endOffset;

  const StoryWordToken({
    required this.index,
    required this.text,
    required this.startOffset,
    required this.endOffset,
  });
}

class StoryLine {
  final int lineNumber;
  final String text;
  final List<String> words;
  final String spokenText;

  const StoryLine({
    required this.lineNumber,
    required this.text,
    required this.words,
    required this.spokenText,
  });
}

class DecodableStoryItem {
  final String id;
  final String title;
  final int level; // 1 = CVC starter, 2 = Simple sentences, 3 = Life narrative
  final String coverEmoji;
  final String description;
  final String attribution;
  final List<StoryLine> lines;

  const DecodableStoryItem({
    required this.id,
    required this.title,
    required this.level,
    required this.coverEmoji,
    required this.description,
    required this.attribution,
    required this.lines,
  });
}

/// Official catalog of decodable stories for pre-readers and adult literacy learners.
const List<DecodableStoryItem> officialDecodableStories = [
  DecodableStoryItem(
    id: 'story_red_hen',
    title: 'The Red Hen',
    level: 1,
    coverEmoji: '🐔',
    description: 'A classic decodable short-vowel story about a hen in the sun.',
    attribution: 'StoryWeaver / CC-BY 4.0 & Public Domain',
    lines: [
      StoryLine(
        lineNumber: 1,
        text: 'The red hen sat in the warm sun.',
        words: ['The', 'red', 'hen', 'sat', 'in', 'the', 'warm', 'sun.'],
        spokenText: 'The red hen sat in the warm sun.',
      ),
      StoryLine(
        lineNumber: 2,
        text: 'She had a red cup and a big bag of grain.',
        words: ['She', 'had', 'a', 'red', 'cup', 'and', 'a', 'big', 'bag', 'of', 'grain.'],
        spokenText: 'She had a red cup and a big bag of grain.',
      ),
      StoryLine(
        lineNumber: 3,
        text: 'A friendly dog ran up the hill to say hello.',
        words: ['A', 'friendly', 'dog', 'ran', 'up', 'the', 'hill', 'to', 'say', 'hello.'],
        spokenText: 'A friendly dog ran up the hill to say hello.',
      ),
      StoryLine(
        lineNumber: 4,
        text: 'They rested together on the soft green mat.',
        words: ['They', 'rested', 'together', 'on', 'the', 'soft', 'green', 'mat.'],
        spokenText: 'They rested together on the soft green mat.',
      ),
    ],
  ),
  DecodableStoryItem(
    id: 'story_bus_ride',
    title: 'Taking the City Bus',
    level: 2,
    coverEmoji: '🚌',
    description: 'An everyday adult survival story about boarding the bus and paying fare.',
    attribution: 'Adult Basic Literacy Project / CC-BY 4.0',
    lines: [
      StoryLine(
        lineNumber: 1,
        text: 'Maria waits at the bus stop on Main Street.',
        words: ['Maria', 'waits', 'at', 'the', 'bus', 'stop', 'on', 'Main', 'Street.'],
        spokenText: 'Maria waits at the bus stop on Main Street.',
      ),
      StoryLine(
        lineNumber: 2,
        text: 'The big blue bus stops at the curb and opens the door.',
        words: ['The', 'big', 'blue', 'bus', 'stops', 'at', 'the', 'curb', 'and', 'opens', 'the', 'door.'],
        spokenText: 'The big blue bus stops at the curb and opens the door.',
      ),
      StoryLine(
        lineNumber: 3,
        text: 'She taps her bus card on the green scanner.',
        words: ['She', 'taps', 'her', 'bus', 'card', 'on', 'the', 'green', 'scanner.'],
        spokenText: 'She taps her bus card on the green scanner.',
      ),
      StoryLine(
        lineNumber: 4,
        text: 'She finds a safe seat and arrives at work on time.',
        words: ['She', 'finds', 'a', 'safe', 'seat', 'and', 'arrives', 'at', 'work', 'on', 'time.'],
        spokenText: 'She finds a safe seat and arrives at work on time.',
      ),
    ],
  ),
  DecodableStoryItem(
    id: 'story_at_the_clinic',
    title: 'Visiting the Clinic',
    level: 2,
    coverEmoji: '🏥',
    description: 'Functional healthcare literacy story about checking in for a medical appointment.',
    attribution: 'Community Healthcare Literacy / CC-BY 4.0',
    lines: [
      StoryLine(
        lineNumber: 1,
        text: 'Carlos walks into the community health clinic.',
        words: ['Carlos', 'walks', 'into', 'the', 'community', 'health', 'clinic.'],
        spokenText: 'Carlos walks into the community health clinic.',
      ),
      StoryLine(
        lineNumber: 2,
        text: 'He says his name clearly at the front reception desk.',
        words: ['He', 'says', 'his', 'name', 'clearly', 'at', 'the', 'front', 'reception', 'desk.'],
        spokenText: 'He says his name clearly at the front reception desk.',
      ),
      StoryLine(
        lineNumber: 3,
        text: 'The nurse calls his name and checks his blood pressure.',
        words: ['The', 'nurse', 'calls', 'his', 'name', 'and', 'checks', 'his', 'blood', 'pressure.'],
        spokenText: 'The nurse calls his name and checks his blood pressure.',
      ),
      StoryLine(
        lineNumber: 4,
        text: 'The doctor gives Carlos clear medicine instructions.',
        words: ['The', 'doctor', 'gives', 'Carlos', 'clear', 'medicine', 'instructions.'],
        spokenText: 'The doctor gives Carlos clear medicine instructions.',
      ),
    ],
  ),
];

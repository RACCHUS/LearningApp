/// Data model representing a vocabulary definition sense with contextual examples and distractors (W2, P8-3).
class WordSenseItem {
  final String id;
  final String word;
  final String partOfSpeech;
  final String definition;
  final String exampleSentence;
  final List<String> distractorDefinitions;
  final List<String> synonyms;
  final String category;

  const WordSenseItem({
    required this.id,
    required this.word,
    required this.partOfSpeech,
    required this.definition,
    required this.exampleSentence,
    required this.distractorDefinitions,
    this.synonyms = const [],
    required this.category,
  });

  factory WordSenseItem.fromJson(Map<String, dynamic> json) {
    return WordSenseItem(
      id: json['id'] as String? ?? '',
      word: json['word'] as String? ?? '',
      partOfSpeech: json['part_of_speech'] as String? ?? 'noun',
      definition: json['definition'] as String? ?? '',
      exampleSentence: json['example_sentence'] as String? ?? '',
      distractorDefinitions: (json['distractor_definitions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      synonyms: (json['synonyms'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      category: json['category'] as String? ?? 'General Academic',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'word': word,
        'part_of_speech': partOfSpeech,
        'definition': definition,
        'example_sentence': exampleSentence,
        'distractor_definitions': distractorDefinitions,
        'synonyms': synonyms,
        'category': category,
      };
}


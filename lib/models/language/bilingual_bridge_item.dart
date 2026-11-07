/// Model representing a bilingual vocabulary bridge pair for English Language Learners (P8-4).
class BilingualBridgeItem {
  final String id;
  final String englishTerm;
  final String spanishTerm;
  final String englishPhonetic;
  final String spanishPhonetic;
  final String englishDefinition;
  final String spanishDefinition;
  final String visualEmoji;
  final String category;
  final String regulatoryCitation;

  const BilingualBridgeItem({
    required this.id,
    required this.englishTerm,
    required this.spanishTerm,
    required this.englishPhonetic,
    required this.spanishPhonetic,
    required this.englishDefinition,
    required this.spanishDefinition,
    required this.visualEmoji,
    required this.category,
    required this.regulatoryCitation,
  });

  factory BilingualBridgeItem.fromJson(Map<String, dynamic> json) {
    return BilingualBridgeItem(
      id: json['id'] as String? ?? '',
      englishTerm: json['english_term'] as String? ?? '',
      spanishTerm: json['spanish_term'] as String? ?? '',
      englishPhonetic: json['english_phonetic'] as String? ?? '',
      spanishPhonetic: json['spanish_phonetic'] as String? ?? '',
      englishDefinition: json['english_definition'] as String? ?? '',
      spanishDefinition: json['spanish_definition'] as String? ?? '',
      visualEmoji: json['visual_emoji'] as String? ?? '🌐',
      category: json['category'] as String? ?? 'General',
      regulatoryCitation: json['regulatory_citation'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'english_term': englishTerm,
        'spanish_term': spanishTerm,
        'english_phonetic': englishPhonetic,
        'spanish_phonetic': spanishPhonetic,
        'english_definition': englishDefinition,
        'spanish_definition': spanishDefinition,
        'visual_emoji': visualEmoji,
        'category': category,
        'regulatory_citation': regulatoryCitation,
      };
}


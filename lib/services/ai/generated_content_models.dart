import 'dart:convert';
import 'package:learning_pwa/models/answer_key.dart';

/// Represents an AI-generated assessment item with Haladyna guidelines and provenance.
class GeneratedAssessmentItem {
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String sourceCitation;
  final String bloomLevel;
  final String difficulty;
  final int expectedSeconds;
  final List<String> haladynaViolations;

  const GeneratedAssessmentItem({
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.sourceCitation,
    this.bloomLevel = 'understand',
    this.difficulty = 'intermediate',
    this.expectedSeconds = 60,
    this.haladynaViolations = const [],
  });

  /// Whether [correctIndex] is a real, in-range, unambiguous key.
  bool get hasValidKey => AnswerKey.fromIndex(correctIndex, options).isScorable;

  String get correctAnswer =>
      (correctIndex >= 0 && correctIndex < options.length)
          ? options[correctIndex]
          : '';

  List<String> get distractors {
    final list = <String>[];
    for (int i = 0; i < options.length; i++) {
      if (i != correctIndex) list.add(options[i]);
    }
    return list;
  }

  Map<String, dynamic> toJson() => {
        'prompt': prompt,
        'options': options,
        'correct_index': correctIndex,
        'explanation': explanation,
        'source_citation': sourceCitation,
        'bloom_level': bloomLevel,
        'difficulty': difficulty,
        'expected_seconds': expectedSeconds,
        'haladyna_violations': haladynaViolations,
      };

  factory GeneratedAssessmentItem.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    final options = rawOptions is List
        ? rawOptions.map((e) => e.toString().trim()).toList()
        : <String>[];

    final violations = json['haladyna_violations'];
    final haladynaViolations = violations is List
        ? violations.map((e) => e.toString()).toList()
        : <String>[];

    return GeneratedAssessmentItem(
      prompt: (json['prompt'] ?? '').toString().trim(),
      options: options,
      // Strict integer key; a missing/invalid key is unscorable (-1), never
      // option 0 (plan v2.6 §14.8). ItemEvaluator fails such items.
      correctIndex:
          AnswerKey.fromIndex(json['correct_index'], options).storedIndex,
      explanation: (json['explanation'] ?? '').toString().trim(),
      sourceCitation: (json['source_citation'] ?? '').toString().trim(),
      bloomLevel: (json['bloom_level'] ?? 'understand').toString(),
      difficulty: (json['difficulty'] ?? 'intermediate').toString(),
      expectedSeconds: (json['expected_seconds'] as num?)?.toInt() ?? 60,
      haladynaViolations: haladynaViolations,
    );
  }

  GeneratedAssessmentItem copyWith({
    String? prompt,
    List<String>? options,
    int? correctIndex,
    String? explanation,
    String? sourceCitation,
    String? bloomLevel,
    String? difficulty,
    int? expectedSeconds,
    List<String>? haladynaViolations,
  }) {
    return GeneratedAssessmentItem(
      prompt: prompt ?? this.prompt,
      options: options ?? this.options,
      correctIndex: correctIndex ?? this.correctIndex,
      explanation: explanation ?? this.explanation,
      sourceCitation: sourceCitation ?? this.sourceCitation,
      bloomLevel: bloomLevel ?? this.bloomLevel,
      difficulty: difficulty ?? this.difficulty,
      expectedSeconds: expectedSeconds ?? this.expectedSeconds,
      haladynaViolations: haladynaViolations ?? this.haladynaViolations,
    );
  }

  /// JSON Schema for strict structured output generation of an assessment item.
  static const Map<String, dynamic> jsonSchema = {
    'type': 'object',
    'properties': {
      'prompt': {
        'type': 'string',
        'description':
            'Clear, focused question stem asking a single well-defined problem without negative stems.',
      },
      'options': {
        'type': 'array',
        'items': {'type': 'string'},
        'description':
            'Exactly 4 plausible choices of approximately equal length. No "all/none of the above".',
      },
      'correct_index': {
        'type': 'integer',
        'description': '0-based index of the single correct option (0 to 3).',
      },
      'explanation': {
        'type': 'string',
        'description':
            'Elaborative feedback explaining why the correct choice is accurate AND why each distractor is incorrect.',
      },
      'source_citation': {
        'type': 'string',
        'description':
            'Authoritative statutory, regulatory, or textbook source reference/excerpt justifying the key.',
      },
      'bloom_level': {
        'type': 'string',
        'enum': [
          'remember',
          'understand',
          'apply',
          'analyze',
          'evaluate',
          'create'
        ],
      },
      'difficulty': {
        'type': 'string',
        'enum': ['beginner', 'intermediate', 'advanced'],
      },
      'expected_seconds': {
        'type': 'integer',
        'description': 'Expected time in seconds to solve this item.',
      },
    },
    'required': [
      'prompt',
      'options',
      'correct_index',
      'explanation',
      'source_citation'
    ],
  };
}

/// Represents an AI-generated structured lesson containing multiple curated items.
class GeneratedLesson {
  final String title;
  final String description;
  final int estimatedMinutes;
  final List<String> concepts;
  final List<GeneratedAssessmentItem> items;

  const GeneratedLesson({
    required this.title,
    required this.description,
    required this.estimatedMinutes,
    required this.concepts,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'estimated_minutes': estimatedMinutes,
        'concepts': concepts,
        'items': items.map((i) => i.toJson()).toList(),
      };

  factory GeneratedLesson.fromJson(Map<String, dynamic> json) {
    final rawConcepts = json['concepts'];
    final concepts = rawConcepts is List
        ? rawConcepts.map((e) => e.toString()).toList()
        : <String>[];

    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .map((e) => GeneratedAssessmentItem.fromJson(
                e is Map<String, dynamic> ? e : jsonDecode(e.toString())))
            .toList()
        : <GeneratedAssessmentItem>[];

    return GeneratedLesson(
      title: (json['title'] ?? '').toString().trim(),
      description: (json['description'] ?? '').toString().trim(),
      estimatedMinutes: (json['estimated_minutes'] as num?)?.toInt() ?? 15,
      concepts: concepts,
      items: items,
    );
  }

  /// JSON Schema for generating a complete lesson with items.
  static const Map<String, dynamic> jsonSchema = {
    'type': 'object',
    'properties': {
      'title': {'type': 'string'},
      'description': {'type': 'string'},
      'estimated_minutes': {'type': 'integer'},
      'concepts': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'items': {
        'type': 'array',
        'items': GeneratedAssessmentItem.jsonSchema,
      },
    },
    'required': ['title', 'description', 'estimated_minutes', 'items'],
  };
}


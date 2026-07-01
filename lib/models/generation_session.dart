import 'dart:convert';

/// Tracks the state of a multi-prompt lesson generation session.
/// Each phase feeds its output into the next prompt so the AI maintains
/// continuity in terminology, difficulty progression, and style.
class GenerationSession {
  final String id;
  final DateTime createdAt;
  final String subject;
  final String targetAudience;
  final int durationMinutes;
  final String difficulty;
  final String contentFocus;

  /// Phase 1 output — lesson plan with content manifest & terminology glossary.
  final Map<String, dynamic>? lessonPlan;

  /// Phase 2a output — generated terms (accumulated across batches).
  final List<Map<String, dynamic>> terms;

  /// Phase 2b output — generated concepts (accumulated across batches).
  final List<Map<String, dynamic>> concepts;

  /// Phase 2c output — generated MCQs (accumulated across batches).
  final List<Map<String, dynamic>> mcqs;

  /// Phase 3 output — review summary + any revised items.
  final Map<String, dynamic>? reviewResult;

  /// Current step in the pipeline.
  final GenerationPhase currentPhase;

  /// Optional error message from the last operation.
  final String? errorMessage;

  const GenerationSession({
    required this.id,
    required this.createdAt,
    required this.subject,
    required this.targetAudience,
    required this.durationMinutes,
    required this.difficulty,
    required this.contentFocus,
    this.lessonPlan,
    this.terms = const [],
    this.concepts = const [],
    this.mcqs = const [],
    this.reviewResult,
    this.currentPhase = GenerationPhase.planning,
    this.errorMessage,
  });

  // ---------------------------------------------------------------------------
  // Computed helpers
  // ---------------------------------------------------------------------------

  /// Total number of terms expected from the plan manifest.
  int get expectedTermCount =>
      _manifestList('terms').length;

  /// Total number of concepts expected from the plan manifest.
  int get expectedConceptCount =>
      _manifestList('concepts').length;

  /// Total number of MCQs expected from the plan manifest.
  int get expectedMcqCount =>
      _manifestList('mcqs').length;

  /// Whether all terms in the manifest have been generated.
  bool get allTermsGenerated => terms.length >= expectedTermCount;

  /// Whether all concepts in the manifest have been generated.
  bool get allConceptsGenerated => concepts.length >= expectedConceptCount;

  /// Whether all MCQs in the manifest have been generated.
  bool get allMcqsGenerated => mcqs.length >= expectedMcqCount;

  /// Flat list of all generated content for assembly / review.
  List<Map<String, dynamic>> get allContent => [...terms, ...concepts, ...mcqs];

  /// Human-readable label for [currentPhase].
  String get phaseLabel => currentPhase.label;

  /// Number of assembled MCQs that need manual review (answer mismatch).
  int get needsReviewCount {
    if (currentPhase != GenerationPhase.complete) return 0;
    return assemble()['questions']
        .where((q) => q['_needs_review'] == true)
        .length as int;
  }

  /// Zero-based step index (for steppers).
  int get phaseIndex => currentPhase.index;

  /// Total number of steps.
  static int get totalPhases => GenerationPhase.values.length;

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'id': id,
        'created_at': createdAt.toIso8601String(),
        'subject': subject,
        'target_audience': targetAudience,
        'duration_minutes': durationMinutes,
        'difficulty': difficulty,
        'content_focus': contentFocus,
        'lesson_plan': lessonPlan,
        'terms': terms,
        'concepts': concepts,
        'mcqs': mcqs,
        'review_result': reviewResult,
        'current_phase': currentPhase.name,
      };

  factory GenerationSession.fromJson(Map<String, dynamic> json) {
    return GenerationSession(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      subject: json['subject'] as String,
      targetAudience: json['target_audience'] as String,
      durationMinutes: json['duration_minutes'] as int,
      difficulty: json['difficulty'] as String,
      contentFocus: json['content_focus'] as String,
      lessonPlan: json['lesson_plan'] as Map<String, dynamic>?,
      terms: _castList(json['terms']),
      concepts: _castList(json['concepts']),
      mcqs: _castList(json['mcqs']),
      reviewResult: json['review_result'] as Map<String, dynamic>?,
      currentPhase: GenerationPhase.values.firstWhere(
        (p) => p.name == json['current_phase'],
        orElse: () => GenerationPhase.planning,
      ),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory GenerationSession.fromJsonString(String source) =>
      GenerationSession.fromJson(
          jsonDecode(source) as Map<String, dynamic>);

  // ---------------------------------------------------------------------------
  // Assembly — merge all generated content into the app's import format
  // ---------------------------------------------------------------------------

  /// Produces the final lesson JSON that the existing import pipeline accepts.
  /// Maps phased prompt output fields to the import service's expected fields.
  Map<String, dynamic> assemble() {
    final plan = lessonPlan?['lesson_plan'] as Map<String, dynamic>? ?? {};

    return {
      'title': plan['title'] ?? subject,
      'description': plan['description'] ?? '',
      'estimated_duration_minutes': plan['estimated_duration_minutes'] ?? durationMinutes,
      'difficulty_level': plan['difficulty'] ?? difficulty,
      'tags': plan['key_terminology'] ?? <String>[],
      'terms': _assembleTerms(),
      'concepts': _assembleConcepts(),
      'questions': _assembleMcqs(),
    };
  }

  /// Map term fields: title→term, content→definition, example stays.
  List<Map<String, dynamic>> _assembleTerms() {
    final revised = _revisedContentMap();
    return terms.map((t) {
      final source = revised[t['title']] ?? t;
      return {
        'id': source['id'] ?? '',
        'term': source['title'] ?? source['term'] ?? '',
        'definition': source['content'] ?? source['definition'] ?? '',
        'example': source['example'] ?? '',
        if (source['emoji'] != null) 'emoji': source['emoji'],
      };
    }).toList();
  }

  /// Map concept fields: title→concept_text, content→example_text.
  List<Map<String, dynamic>> _assembleConcepts() {
    final revised = _revisedContentMap();
    return concepts.map((c) {
      final source = revised[c['title']] ?? c;
      return {
        'id': source['id'] ?? '',
        'concept_text': source['title'] ?? source['concept_text'] ?? '',
        'example_text': source['content'] ?? source['example_text'] ?? '',
        if (source['emoji'] != null) 'emoji': source['emoji'],
      };
    }).toList();
  }

  /// Map MCQ fields: correct_answer (text)→correct_answer (index).
  List<Map<String, dynamic>> _assembleMcqs() {
    final revised = _revisedContentMap();
    return mcqs.map((q) {
      final source = revised[q['question']] ?? q;
      final options = source['options'] is List
          ? List<String>.from(source['options'])
          : <String>[];
      final correctText = source['correct_answer']?.toString() ?? '';

      // Convert text answer to index with fallback matching
      var correctIndex = _resolveCorrectIndex(correctText, options);

      final result = <String, dynamic>{
        'id': source['id'] ?? '',
        'question': source['question'] ?? source['question_text'] ?? '',
        'options': options,
        'correct_answer': correctIndex ?? 0,
        'explanation': source['explanation'] ?? '',
      };

      // Flag for review if answer didn't match
      if (correctIndex == null) {
        result['_needs_review'] = true;
        result['_review_reason'] =
            'correct_answer "$correctText" did not match any option';
      }

      // Cross-check: duplicate options
      final uniqueOptions = options.map((o) => o.trim().toLowerCase()).toSet();
      if (uniqueOptions.length < options.length) {
        result['_needs_review'] = true;
        result['_review_reason'] =
            (result['_review_reason'] ?? '') +
            (result['_review_reason'] != null ? '; ' : '') +
            'duplicate options detected';
      }

      // Cross-check: missing explanation
      if ((result['explanation'] as String).trim().isEmpty) {
        result['_needs_review'] = true;
        result['_review_reason'] =
            (result['_review_reason'] ?? '') +
            (result['_review_reason'] != null ? '; ' : '') +
            'missing explanation';
      }

      return result;
    }).toList();
  }

  /// Resolve a text answer to its 0-based index in [options].
  /// Returns `null` if no match is found (caller should flag for review).
  static int? _resolveCorrectIndex(String correctText, List<String> options) {
    // 1. Exact match
    final exact = options.indexOf(correctText);
    if (exact >= 0) return exact;

    // 2. Case-insensitive / trimmed match
    final normalized = correctText.trim().toLowerCase();
    final ciMatch = options.indexWhere(
      (o) => o.trim().toLowerCase() == normalized,
    );
    if (ciMatch >= 0) return ciMatch;

    // 3. Substring containment (handles minor formatting differences)
    final containsMatch = options.indexWhere(
      (o) =>
          o.trim().toLowerCase().contains(normalized) ||
          normalized.contains(o.trim().toLowerCase()),
    );
    if (containsMatch >= 0) return containsMatch;

    // No match — return null so caller can flag for review
    return null;
  }

  Map<String, Map<String, dynamic>> _revisedContentMap() {
    if (reviewResult == null) return {};
    final revised = reviewResult!['revised_content'];
    if (revised is! List) return {};
    final map = <String, Map<String, dynamic>>{};
    for (final item in revised) {
      if (item is Map<String, dynamic>) {
        final key = item['title'] ?? item['question'] ?? '';
        if (key.toString().isNotEmpty) {
          map[key.toString()] = item;
        }
      }
    }
    return map;
  }

  List<Map<String, dynamic>> _manifestList(String key) {
    final manifest = lessonPlan?['content_manifest'];
    if (manifest is! Map<String, dynamic>) return [];
    final list = manifest[key];
    if (list is! List) return [];
    return List<Map<String, dynamic>>.from(list);
  }

  static List<Map<String, dynamic>> _castList(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  GenerationSession copyWith({
    String? id,
    DateTime? createdAt,
    String? subject,
    String? targetAudience,
    int? durationMinutes,
    String? difficulty,
    String? contentFocus,
    Map<String, dynamic>? lessonPlan,
    List<Map<String, dynamic>>? terms,
    List<Map<String, dynamic>>? concepts,
    List<Map<String, dynamic>>? mcqs,
    Map<String, dynamic>? reviewResult,
    GenerationPhase? currentPhase,
    String? errorMessage,
  }) {
    return GenerationSession(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      subject: subject ?? this.subject,
      targetAudience: targetAudience ?? this.targetAudience,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      difficulty: difficulty ?? this.difficulty,
      contentFocus: contentFocus ?? this.contentFocus,
      lessonPlan: lessonPlan ?? this.lessonPlan,
      terms: terms ?? this.terms,
      concepts: concepts ?? this.concepts,
      mcqs: mcqs ?? this.mcqs,
      reviewResult: reviewResult ?? this.reviewResult,
      currentPhase: currentPhase ?? this.currentPhase,
      errorMessage: errorMessage,
    );
  }
}

/// Possible phases in the multi-prompt generation pipeline.
enum GenerationPhase {
  planning('Create Plan'),
  generatingTerms('Generate Terms'),
  generatingConcepts('Generate Concepts'),
  generatingMcqs('Generate MCQs'),
  reviewing('Review & Revise'),
  complete('Complete');

  const GenerationPhase(this.label);
  final String label;
}

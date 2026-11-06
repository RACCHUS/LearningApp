/// Haladyna-compliant option structure separating correctness from misconceptions.
class AssessmentOptionCore {
  final String text;
  final bool isCorrect;
  final String? rationale;
  final String? misconception;

  const AssessmentOptionCore({
    required this.text,
    required this.isCorrect,
    this.rationale,
    this.misconception,
  });

  factory AssessmentOptionCore.fromJson(Map<String, dynamic> json) {
    return AssessmentOptionCore(
      text: json['text'] as String? ?? '',
      isCorrect: json['is_correct'] as bool? ?? false,
      rationale: json['rationale'] as String?,
      misconception: json['misconception'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'is_correct': isCorrect,
      if (rationale != null) 'rationale': rationale,
      if (misconception != null) 'misconception': misconception,
    };
  }
}

/// Core assessment item model with source excerpt citation requirement.
class AssessmentItemCore {
  final String id;
  final String stem;
  final List<AssessmentOptionCore> options;
  final String? explanation;
  final String? conceptSlug;
  final String? sourceRef;
  final int expectedSeconds;

  const AssessmentItemCore({
    required this.id,
    required this.stem,
    required this.options,
    this.explanation,
    this.conceptSlug,
    this.sourceRef,
    this.expectedSeconds = 60,
  });

  factory AssessmentItemCore.fromJson(Map<String, dynamic> json) {
    return AssessmentItemCore(
      id: json['id'] as String? ?? '',
      stem: json['stem'] as String? ?? json['question'] as String? ?? '',
      options: ((json['options'] as List?) ?? [])
          .map((e) => AssessmentOptionCore.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      explanation: json['explanation'] as String?,
      conceptSlug: json['concept_slug'] as String?,
      sourceRef: json['source_ref'] as String?,
      expectedSeconds: json['expected_seconds'] as int? ?? 60,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'stem': stem,
      'options': options.map((o) => o.toJson()).toList(),
      if (explanation != null) 'explanation': explanation,
      if (conceptSlug != null) 'concept_slug': conceptSlug,
      if (sourceRef != null) 'source_ref': sourceRef,
      'expected_seconds': expectedSeconds,
    };
  }
}


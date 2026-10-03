enum AssessmentInteractionType {
  singleChoice,
  multiSelect,
  orderedResponse,
  matching,
  matrixGrid,
  numericEntry,
  cloze,
  codeOutput;

  static AssessmentInteractionType fromString(String value) {
    switch (value) {
      case 'single_choice':
      case 'singleChoice':
        return AssessmentInteractionType.singleChoice;
      case 'multi_select':
      case 'multiSelect':
        return AssessmentInteractionType.multiSelect;
      case 'ordered_response':
      case 'orderedResponse':
        return AssessmentInteractionType.orderedResponse;
      case 'matching':
        return AssessmentInteractionType.matching;
      case 'matrix_grid':
      case 'matrixGrid':
        return AssessmentInteractionType.matrixGrid;
      case 'numeric_entry':
      case 'numericEntry':
        return AssessmentInteractionType.numericEntry;
      case 'cloze':
        return AssessmentInteractionType.cloze;
      case 'code_output':
      case 'codeOutput':
        return AssessmentInteractionType.codeOutput;
      default:
        return AssessmentInteractionType.singleChoice;
    }
  }

  String toDbString() {
    switch (this) {
      case AssessmentInteractionType.singleChoice:
        return 'single_choice';
      case AssessmentInteractionType.multiSelect:
        return 'multi_select';
      case AssessmentInteractionType.orderedResponse:
        return 'ordered_response';
      case AssessmentInteractionType.matching:
        return 'matching';
      case AssessmentInteractionType.matrixGrid:
        return 'matrix_grid';
      case AssessmentInteractionType.numericEntry:
        return 'numeric_entry';
      case AssessmentInteractionType.cloze:
        return 'cloze';
      case AssessmentInteractionType.codeOutput:
        return 'code_output';
    }
  }
}

class AssessmentItemConcept {
  final String assessmentItemId;
  final String conceptId;
  final String role; // 'primary' | 'supporting'
  final double weight;

  const AssessmentItemConcept({
    required this.assessmentItemId,
    required this.conceptId,
    this.role = 'primary',
    this.weight = 1.0,
  });

  factory AssessmentItemConcept.fromJson(Map<String, dynamic> json) {
    return AssessmentItemConcept(
      assessmentItemId: json['assessment_item_id'] as String? ?? '',
      conceptId: json['concept_id'] as String,
      role: json['role'] as String? ?? 'primary',
      weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'assessment_item_id': assessmentItemId,
      'concept_id': conceptId,
      'role': role,
      'weight': weight,
    };
  }
}

class AssessmentItem {
  final String id;
  final String? lessonId;
  final String? stimulusId;
  final AssessmentInteractionType interactionType;
  final String prompt;
  final Map<String, dynamic> responseSpec;
  final Map<String, dynamic> scoringSpec;
  final String? explanation;
  final String difficulty;
  final String? cognitiveLevel;
  final Map<String, dynamic> metadata;
  final String? userId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<AssessmentItemConcept> concepts;

  const AssessmentItem({
    required this.id,
    this.lessonId,
    this.stimulusId,
    required this.interactionType,
    required this.prompt,
    this.responseSpec = const {},
    this.scoringSpec = const {},
    this.explanation,
    this.difficulty = 'intermediate',
    this.cognitiveLevel,
    this.metadata = const {},
    this.userId,
    required this.createdAt,
    required this.updatedAt,
    this.concepts = const [],
  });

  factory AssessmentItem.fromJson(Map<String, dynamic> json) {
    final rawConcepts = json['concepts'] as List?;
    final conceptsList = rawConcepts != null
        ? rawConcepts
            .map((c) => AssessmentItemConcept.fromJson((c as Map).cast<String, dynamic>()))
            .toList()
        : <AssessmentItemConcept>[];

    return AssessmentItem(
      id: json['id'] as String,
      lessonId: json['lesson_id'] as String?,
      stimulusId: json['stimulus_id'] as String?,
      interactionType: AssessmentInteractionType.fromString(
        json['interaction_type'] as String? ?? 'single_choice',
      ),
      prompt: json['prompt'] as String? ?? '',
      responseSpec:
          (json['response_spec'] as Map?)?.cast<String, dynamic>() ?? const {},
      scoringSpec:
          (json['scoring_spec'] as Map?)?.cast<String, dynamic>() ?? const {},
      explanation: json['explanation'] as String?,
      difficulty: json['difficulty'] as String? ?? 'intermediate',
      cognitiveLevel: json['cognitive_level'] as String?,
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
      userId: json['user_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      concepts: conceptsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lesson_id': lessonId,
      'stimulus_id': stimulusId,
      'interaction_type': interactionType.toDbString(),
      'prompt': prompt,
      'response_spec': responseSpec,
      'scoring_spec': scoringSpec,
      'explanation': explanation,
      'difficulty': difficulty,
      'cognitive_level': cognitiveLevel,
      'metadata': metadata,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (concepts.isNotEmpty)
        'concepts': concepts.map((c) => c.toJson()).toList(),
    };
  }

  AssessmentItem copyWith({
    String? id,
    String? lessonId,
    String? stimulusId,
    AssessmentInteractionType? interactionType,
    String? prompt,
    Map<String, dynamic>? responseSpec,
    Map<String, dynamic>? scoringSpec,
    String? explanation,
    String? difficulty,
    String? cognitiveLevel,
    Map<String, dynamic>? metadata,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<AssessmentItemConcept>? concepts,
  }) {
    return AssessmentItem(
      id: id ?? this.id,
      lessonId: lessonId ?? this.lessonId,
      stimulusId: stimulusId ?? this.stimulusId,
      interactionType: interactionType ?? this.interactionType,
      prompt: prompt ?? this.prompt,
      responseSpec: responseSpec ?? this.responseSpec,
      scoringSpec: scoringSpec ?? this.scoringSpec,
      explanation: explanation ?? this.explanation,
      difficulty: difficulty ?? this.difficulty,
      cognitiveLevel: cognitiveLevel ?? this.cognitiveLevel,
      metadata: metadata ?? this.metadata,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      concepts: concepts ?? this.concepts,
    );
  }
}

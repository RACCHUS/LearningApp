enum KnowledgeConceptStatus {
  active,
  deprecated,
  merged;

  static KnowledgeConceptStatus fromString(String value) {
    return KnowledgeConceptStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => KnowledgeConceptStatus.active,
    );
  }
}

enum ConceptRelationType {
  prerequisite,
  partOf,
  relatedTo,
  contrastsWith,
  appliesTo;

  static ConceptRelationType fromString(String value) {
    switch (value) {
      case 'prerequisite':
        return ConceptRelationType.prerequisite;
      case 'part_of':
        return ConceptRelationType.partOf;
      case 'related_to':
        return ConceptRelationType.relatedTo;
      case 'contrasts_with':
        return ConceptRelationType.contrastsWith;
      case 'applies_to':
        return ConceptRelationType.appliesTo;
      default:
        return ConceptRelationType.relatedTo;
    }
  }

  String toDbString() {
    switch (this) {
      case ConceptRelationType.prerequisite:
        return 'prerequisite';
      case ConceptRelationType.partOf:
        return 'part_of';
      case ConceptRelationType.relatedTo:
        return 'related_to';
      case ConceptRelationType.contrastsWith:
        return 'contrasts_with';
      case ConceptRelationType.appliesTo:
        return 'applies_to';
    }
  }
}

enum PrerequisiteKind {
  required,
  recommended;

  static PrerequisiteKind fromString(String value) {
    return PrerequisiteKind.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PrerequisiteKind.required,
    );
  }
}

enum LessonConceptRole {
  primary,
  supporting,
  prerequisite,
  mentioned;

  static LessonConceptRole fromString(String value) {
    return LessonConceptRole.values.firstWhere(
      (e) => e.name == value,
      orElse: () => LessonConceptRole.primary,
    );
  }
}

enum ConceptMappingRole {
  primary,
  supporting;

  static ConceptMappingRole fromString(String value) {
    return ConceptMappingRole.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ConceptMappingRole.primary,
    );
  }
}

class KnowledgeConcept {
  final String id;
  final String? fieldId;
  final String name;
  final String? slug;
  final String? description;
  final String? shortDefinition;
  final List<String> aliases;
  final String? emoji;
  final KnowledgeConceptStatus status;
  final String? mergedIntoId;
  final String? createdBy;
  final String? sourceType;
  final String? sourceId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const KnowledgeConcept({
    required this.id,
    this.fieldId,
    required this.name,
    this.slug,
    this.description,
    this.shortDefinition,
    this.aliases = const [],
    this.emoji,
    this.status = KnowledgeConceptStatus.active,
    this.mergedIntoId,
    this.createdBy,
    this.sourceType,
    this.sourceId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory KnowledgeConcept.fromJson(Map<String, dynamic> json) {
    return KnowledgeConcept(
      id: json['id'] as String,
      fieldId: json['field_id'] as String?,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String?,
      description: json['description'] as String?,
      shortDefinition: json['short_definition'] as String?,
      aliases: (json['aliases'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      emoji: json['emoji'] as String?,
      status: KnowledgeConceptStatus.fromString(
        json['status'] as String? ?? 'active',
      ),
      mergedIntoId: json['merged_into_id'] as String?,
      createdBy: json['created_by'] as String?,
      sourceType: json['source_type'] as String?,
      sourceId: json['source_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'field_id': fieldId,
      'name': name,
      'slug': slug,
      'description': description,
      'short_definition': shortDefinition,
      'aliases': aliases,
      'emoji': emoji,
      'status': status.name,
      'merged_into_id': mergedIntoId,
      'created_by': createdBy,
      'source_type': sourceType,
      'source_id': sourceId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  KnowledgeConcept copyWith({
    String? id,
    String? fieldId,
    String? name,
    String? slug,
    String? description,
    String? shortDefinition,
    List<String>? aliases,
    String? emoji,
    KnowledgeConceptStatus? status,
    String? mergedIntoId,
    String? createdBy,
    String? sourceType,
    String? sourceId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return KnowledgeConcept(
      id: id ?? this.id,
      fieldId: fieldId ?? this.fieldId,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      shortDefinition: shortDefinition ?? this.shortDefinition,
      aliases: aliases ?? this.aliases,
      emoji: emoji ?? this.emoji,
      status: status ?? this.status,
      mergedIntoId: mergedIntoId ?? this.mergedIntoId,
      createdBy: createdBy ?? this.createdBy,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ConceptRelation {
  final String fromConceptId;
  final String toConceptId;
  final ConceptRelationType relationType;
  final PrerequisiteKind prerequisiteKind;
  final bool autoInclude;
  final double strength;
  final Map<String, dynamic> metadata;

  const ConceptRelation({
    required this.fromConceptId,
    required this.toConceptId,
    required this.relationType,
    this.prerequisiteKind = PrerequisiteKind.required,
    this.autoInclude = true,
    this.strength = 1.0,
    this.metadata = const {},
  });

  factory ConceptRelation.fromJson(Map<String, dynamic> json) {
    return ConceptRelation(
      fromConceptId: json['from_concept_id'] as String,
      toConceptId: json['to_concept_id'] as String,
      relationType: ConceptRelationType.fromString(
        json['relation_type'] as String? ?? 'related_to',
      ),
      prerequisiteKind: PrerequisiteKind.fromString(
        json['prerequisite_kind'] as String? ?? 'required',
      ),
      autoInclude: json['auto_include'] as bool? ?? true,
      strength: (json['strength'] as num?)?.toDouble() ?? 1.0,
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Map<String, dynamic> toJson() => {
        'from_concept_id': fromConceptId,
        'to_concept_id': toConceptId,
        'relation_type': relationType.toDbString(),
        'prerequisite_kind': prerequisiteKind.name,
        'auto_include': autoInclude,
        'strength': strength,
        'metadata': metadata,
      };
}

class LessonConcept {
  final String lessonId;
  final String conceptId;
  final LessonConceptRole role;
  final double weight;
  final int sortOrder;

  const LessonConcept({
    required this.lessonId,
    required this.conceptId,
    this.role = LessonConceptRole.primary,
    this.weight = 1.0,
    this.sortOrder = 0,
  });

  factory LessonConcept.fromJson(Map<String, dynamic> json) {
    return LessonConcept(
      lessonId: json['lesson_id'] as String,
      conceptId: json['concept_id'] as String,
      role: LessonConceptRole.fromString(json['role'] as String? ?? 'primary'),
      weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'lesson_id': lessonId,
        'concept_id': conceptId,
        'role': role.name,
        'weight': weight,
        'sort_order': sortOrder,
      };
}

class QuestionConcept {
  final String questionId;
  final String conceptId;
  final ConceptMappingRole role;
  final double weight;

  const QuestionConcept({
    required this.questionId,
    required this.conceptId,
    this.role = ConceptMappingRole.primary,
    this.weight = 1.0,
  });

  factory QuestionConcept.fromJson(Map<String, dynamic> json) {
    return QuestionConcept(
      questionId: json['question_id'] as String,
      conceptId: json['concept_id'] as String,
      role: ConceptMappingRole.fromString(json['role'] as String? ?? 'primary'),
      weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'question_id': questionId,
        'concept_id': conceptId,
        'role': role.name,
        'weight': weight,
      };
}

class TermConcept {
  final String termId;
  final String conceptId;
  final ConceptMappingRole role;
  final double weight;

  const TermConcept({
    required this.termId,
    required this.conceptId,
    this.role = ConceptMappingRole.primary,
    this.weight = 1.0,
  });

  factory TermConcept.fromJson(Map<String, dynamic> json) {
    return TermConcept(
      termId: json['term_id'] as String,
      conceptId: json['concept_id'] as String,
      role: ConceptMappingRole.fromString(json['role'] as String? ?? 'primary'),
      weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'term_id': termId,
        'concept_id': conceptId,
        'role': role.name,
        'weight': weight,
      };
}

class FlashcardConcept {
  final String flashcardId;
  final String conceptId;
  final ConceptMappingRole role;
  final double weight;

  const FlashcardConcept({
    required this.flashcardId,
    required this.conceptId,
    this.role = ConceptMappingRole.primary,
    this.weight = 1.0,
  });

  factory FlashcardConcept.fromJson(Map<String, dynamic> json) {
    return FlashcardConcept(
      flashcardId: json['flashcard_id'] as String,
      conceptId: json['concept_id'] as String,
      role: ConceptMappingRole.fromString(json['role'] as String? ?? 'primary'),
      weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'flashcard_id': flashcardId,
        'concept_id': conceptId,
        'role': role.name,
        'weight': weight,
      };
}

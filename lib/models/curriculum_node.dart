enum CurriculumImportance {
  core,
  recommended,
  optional;

  static CurriculumImportance fromString(String value) {
    return CurriculumImportance.values.firstWhere(
      (e) => e.name == value,
      orElse: () => CurriculumImportance.core,
    );
  }
}

enum ConceptRelevance {
  core,
  supporting,
  related;

  static ConceptRelevance fromString(String value) {
    return ConceptRelevance.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ConceptRelevance.core,
    );
  }
}

class CurriculumNode {
  final String id;
  final String targetVersionId;
  final String? parentId;
  final String nodeType;
  final String title;
  final String? code;
  final String? description;
  final int sortOrder;
  final CurriculumImportance importance;
  final double? weight;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CurriculumNode({
    required this.id,
    required this.targetVersionId,
    this.parentId,
    required this.nodeType,
    required this.title,
    this.code,
    this.description,
    this.sortOrder = 0,
    this.importance = CurriculumImportance.core,
    this.weight,
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isRoot => parentId == null;

  factory CurriculumNode.fromJson(Map<String, dynamic> json) {
    return CurriculumNode(
      id: json['id'] as String,
      targetVersionId: json['target_version_id'] as String,
      parentId: json['parent_id'] as String?,
      nodeType: json['node_type'] as String? ?? 'domain',
      title: json['title'] as String? ?? '',
      code: json['code'] as String?,
      description: json['description'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      importance: CurriculumImportance.fromString(
        json['importance'] as String? ?? 'core',
      ),
      weight: (json['weight'] as num?)?.toDouble(),
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
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
      'target_version_id': targetVersionId,
      'parent_id': parentId,
      'node_type': nodeType,
      'title': title,
      'code': code,
      'description': description,
      'sort_order': sortOrder,
      'importance': importance.name,
      'weight': weight,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  CurriculumNode copyWith({
    String? id,
    String? targetVersionId,
    String? parentId,
    String? nodeType,
    String? title,
    String? code,
    String? description,
    int? sortOrder,
    CurriculumImportance? importance,
    double? weight,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CurriculumNode(
      id: id ?? this.id,
      targetVersionId: targetVersionId ?? this.targetVersionId,
      parentId: parentId ?? this.parentId,
      nodeType: nodeType ?? this.nodeType,
      title: title ?? this.title,
      code: code ?? this.code,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      importance: importance ?? this.importance,
      weight: weight ?? this.weight,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class CurriculumNodeCourse {
  final String curriculumNodeId;
  final String courseId;
  final int sortOrder;
  final bool isRequired;

  const CurriculumNodeCourse({
    required this.curriculumNodeId,
    required this.courseId,
    this.sortOrder = 0,
    this.isRequired = true,
  });

  factory CurriculumNodeCourse.fromJson(Map<String, dynamic> json) {
    return CurriculumNodeCourse(
      curriculumNodeId: json['curriculum_node_id'] as String,
      courseId: json['course_id'] as String,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isRequired: json['is_required'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'curriculum_node_id': curriculumNodeId,
        'course_id': courseId,
        'sort_order': sortOrder,
        'is_required': isRequired,
      };
}

class CurriculumNodeModule {
  final String curriculumNodeId;
  final String moduleId;
  final int sortOrder;
  final bool isRequired;

  const CurriculumNodeModule({
    required this.curriculumNodeId,
    required this.moduleId,
    this.sortOrder = 0,
    this.isRequired = true,
  });

  factory CurriculumNodeModule.fromJson(Map<String, dynamic> json) {
    return CurriculumNodeModule(
      curriculumNodeId: json['curriculum_node_id'] as String,
      moduleId: json['module_id'] as String,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isRequired: json['is_required'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'curriculum_node_id': curriculumNodeId,
        'module_id': moduleId,
        'sort_order': sortOrder,
        'is_required': isRequired,
      };
}

class CurriculumNodeLesson {
  final String curriculumNodeId;
  final String lessonId;
  final String? lessonTitle;
  final int sortOrder;
  final bool isRequired;

  const CurriculumNodeLesson({
    required this.curriculumNodeId,
    required this.lessonId,
    this.lessonTitle,
    this.sortOrder = 0,
    this.isRequired = true,
  });

  factory CurriculumNodeLesson.fromJson(Map<String, dynamic> json) {
    String? title;
    final lessonObj = json['lessons'];
    if (lessonObj is Map<String, dynamic>) {
      title = lessonObj['title'] as String?;
    } else if (json['lesson_title'] is String) {
      title = json['lesson_title'] as String;
    }
    return CurriculumNodeLesson(
      curriculumNodeId: json['curriculum_node_id'] as String,
      lessonId: json['lesson_id'] as String,
      lessonTitle: title,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isRequired: json['is_required'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'curriculum_node_id': curriculumNodeId,
        'lesson_id': lessonId,
        if (lessonTitle != null) 'lesson_title': lessonTitle,
        'sort_order': sortOrder,
        'is_required': isRequired,
      };
}

class CurriculumNodeConcept {
  final String curriculumNodeId;
  final String conceptId;
  final ConceptRelevance relevance;
  final double weight;

  const CurriculumNodeConcept({
    required this.curriculumNodeId,
    required this.conceptId,
    this.relevance = ConceptRelevance.core,
    this.weight = 1.0,
  });

  factory CurriculumNodeConcept.fromJson(Map<String, dynamic> json) {
    return CurriculumNodeConcept(
      curriculumNodeId: json['curriculum_node_id'] as String,
      conceptId: json['concept_id'] as String,
      relevance: ConceptRelevance.fromString(
        json['relevance'] as String? ?? 'core',
      ),
      weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'curriculum_node_id': curriculumNodeId,
        'concept_id': conceptId,
        'relevance': relevance.name,
        'weight': weight,
      };
}

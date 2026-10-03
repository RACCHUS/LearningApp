enum LessonBlockType {
  markdown,
  callout,
  code,
  table,
  image,
  formula,
  example,
  practicePrompt;

  static LessonBlockType fromString(String value) {
    switch (value) {
      case 'markdown':
        return LessonBlockType.markdown;
      case 'callout':
        return LessonBlockType.callout;
      case 'code':
        return LessonBlockType.code;
      case 'table':
        return LessonBlockType.table;
      case 'image':
        return LessonBlockType.image;
      case 'formula':
        return LessonBlockType.formula;
      case 'example':
        return LessonBlockType.example;
      case 'practice_prompt':
      case 'practicePrompt':
        return LessonBlockType.practicePrompt;
      default:
        return LessonBlockType.markdown;
    }
  }

  String toDbString() {
    switch (this) {
      case LessonBlockType.markdown:
        return 'markdown';
      case LessonBlockType.callout:
        return 'callout';
      case LessonBlockType.code:
        return 'code';
      case LessonBlockType.table:
        return 'table';
      case LessonBlockType.image:
        return 'image';
      case LessonBlockType.formula:
        return 'formula';
      case LessonBlockType.example:
        return 'example';
      case LessonBlockType.practicePrompt:
        return 'practice_prompt';
    }
  }
}

class LessonBlock {
  final String id;
  final String lessonId;
  final int sortOrder;
  final LessonBlockType blockType;
  final Map<String, dynamic> content;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LessonBlock({
    required this.id,
    required this.lessonId,
    required this.sortOrder,
    required this.blockType,
    this.content = const {},
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory LessonBlock.fromJson(Map<String, dynamic> json) {
    return LessonBlock(
      id: json['id'] as String,
      lessonId: json['lesson_id'] as String,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      blockType: LessonBlockType.fromString(json['block_type'] as String? ?? 'markdown'),
      content: (json['content'] as Map?)?.cast<String, dynamic>() ?? const {},
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
      'lesson_id': lessonId,
      'sort_order': sortOrder,
      'block_type': blockType.toDbString(),
      'content': content,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  LessonBlock copyWith({
    String? id,
    String? lessonId,
    int? sortOrder,
    LessonBlockType? blockType,
    Map<String, dynamic>? content,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LessonBlock(
      id: id ?? this.id,
      lessonId: lessonId ?? this.lessonId,
      sortOrder: sortOrder ?? this.sortOrder,
      blockType: blockType ?? this.blockType,
      content: content ?? this.content,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Learning Target Field junction model
/// Represents multidisciplinary field membership of a learning target.
class LearningTargetField {
  final String targetId;
  final String fieldId;
  final String role; // 'primary', 'supporting', 'interdisciplinary_core', 'elective'
  final int displayOrder;
  final DateTime? createdAt;

  const LearningTargetField({
    required this.targetId,
    required this.fieldId,
    this.role = 'supporting',
    this.displayOrder = 0,
    this.createdAt,
  });

  bool get isPrimary => role == 'primary';
  bool get isSupporting => role == 'supporting';
  bool get isInterdisciplinaryCore => role == 'interdisciplinary_core';

  factory LearningTargetField.fromJson(Map<String, dynamic> json) {
    return LearningTargetField(
      targetId: json['target_id'] as String,
      fieldId: json['field_id'] as String,
      role: json['role'] as String? ?? 'supporting',
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'target_id': targetId,
        'field_id': fieldId,
        'role': role,
        'display_order': displayOrder,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}

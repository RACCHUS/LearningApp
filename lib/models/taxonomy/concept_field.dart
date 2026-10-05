/// Concept Field junction model
/// Binds canonical knowledge concepts to fields of study without ownership.
class ConceptField {
  final String conceptId;
  final String fieldId;
  final String relationship; // 'core_concept', 'foundational_prerequisite', 'applied_domain', 'shared_cross_field'
  final DateTime? createdAt;

  const ConceptField({
    required this.conceptId,
    required this.fieldId,
    this.relationship = 'core_concept',
    this.createdAt,
  });

  bool get isCore => relationship == 'core_concept';
  bool get isPrerequisite => relationship == 'foundational_prerequisite';
  bool get isSharedCrossField => relationship == 'shared_cross_field';

  factory ConceptField.fromJson(Map<String, dynamic> json) {
    return ConceptField(
      conceptId: json['concept_id'] as String,
      fieldId: json['field_id'] as String,
      relationship: json['relationship'] as String? ?? 'core_concept',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'concept_id': conceptId,
        'field_id': fieldId,
        'relationship': relationship,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}

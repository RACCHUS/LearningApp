/// Field Relation model
/// Models lateral and interdisciplinary relationships between internal fields.
class FieldRelation {
  final String fromFieldId;
  final String toFieldId;
  final String relationType; // 'interdisciplinary_parent', 'applied_domain_of', 'shares_foundations', 'cross_disciplinary_partner'
  final String? notes;

  const FieldRelation({
    required this.fromFieldId,
    required this.toFieldId,
    required this.relationType,
    this.notes,
  });

  bool get isSymmetric =>
      relationType == 'shares_foundations' ||
      relationType == 'cross_disciplinary_partner';

  factory FieldRelation.fromJson(Map<String, dynamic> json) {
    return FieldRelation(
      fromFieldId: json['from_field_id'] as String,
      toFieldId: json['to_field_id'] as String,
      relationType: json['relation_type'] as String,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'from_field_id': fromFieldId,
        'to_field_id': toFieldId,
        'relation_type': relationType,
        'notes': notes,
      };
}

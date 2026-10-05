/// Taxonomy Node Lineage model
/// Records decennial version transitions with valid null endpoints and idempotency.
class TaxonomyNodeLineage {
  final String id;
  final String sourceSystem; // 'cip', 'bls_soc'
  final String fromVersion; // e.g. '2010'
  final String? fromCode; // null for newly_introduced
  final String toVersion; // e.g. '2020'
  final String? toCode; // null for deleted
  final String transitionType; // 'unchanged', 'renamed', 'split_into', 'merged_into', 'moved_to', 'deleted', 'newly_introduced'
  final String? notes;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;

  const TaxonomyNodeLineage({
    required this.id,
    required this.sourceSystem,
    required this.fromVersion,
    this.fromCode,
    required this.toVersion,
    this.toCode,
    required this.transitionType,
    this.notes,
    this.metadata = const {},
    this.createdAt,
  });

  factory TaxonomyNodeLineage.fromJson(Map<String, dynamic> json) {
    return TaxonomyNodeLineage(
      id: json['id'] as String,
      sourceSystem: json['source_system'] as String,
      fromVersion: json['from_version'] as String,
      fromCode: json['from_code'] as String?,
      toVersion: json['to_version'] as String,
      toCode: json['to_code'] as String?,
      transitionType: json['transition_type'] as String,
      notes: json['notes'] as String?,
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : const {},
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'source_system': sourceSystem,
        'from_version': fromVersion,
        'from_code': fromCode,
        'to_version': toVersion,
        'to_code': toCode,
        'transition_type': transitionType,
        'notes': notes,
        'metadata': metadata,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}

/// External Classification Occupation Mapping model
/// Represents the raw official qualitative crosswalk between CIP and SOC nodes.
class ExternalClassificationOccupationMapping {
  final String id;
  final String classificationNodeId;
  final String occupationId;
  final String sourceReleaseId;
  final String mappingSource; // e.g. 'nces_bls_crosswalk_2020'
  final String mappingVersion; // e.g. '2020'
  final String mappingKind; // 'official_qualitative', 'advisory_board', 'curated_extension'
  final String? sourceNotes;
  final DateTime? createdAt;

  const ExternalClassificationOccupationMapping({
    required this.id,
    required this.classificationNodeId,
    required this.occupationId,
    required this.sourceReleaseId,
    this.mappingSource = 'nces_bls_crosswalk_2020',
    this.mappingVersion = '2020',
    this.mappingKind = 'official_qualitative',
    this.sourceNotes,
    this.createdAt,
  });

  factory ExternalClassificationOccupationMapping.fromJson(
      Map<String, dynamic> json) {
    return ExternalClassificationOccupationMapping(
      id: json['id'] as String,
      classificationNodeId: json['classification_node_id'] as String,
      occupationId: json['occupation_id'] as String,
      sourceReleaseId: json['source_release_id'] as String,
      mappingSource:
          json['mapping_source'] as String? ?? 'nces_bls_crosswalk_2020',
      mappingVersion: json['mapping_version'] as String? ?? '2020',
      mappingKind:
          json['mapping_kind'] as String? ?? 'official_qualitative',
      sourceNotes: json['source_notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'classification_node_id': classificationNodeId,
        'occupation_id': occupationId,
        'source_release_id': sourceReleaseId,
        'mapping_source': mappingSource,
        'mapping_version': mappingVersion,
        'mapping_kind': mappingKind,
        'source_notes': sourceNotes,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}

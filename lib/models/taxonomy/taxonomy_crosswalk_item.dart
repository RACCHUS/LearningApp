/// Extended taxonomy crosswalk projection models
/// Used by the Canonical Taxonomy & Career Pathway Explorer UI.

enum TaxonomyItemKind {
  occupation,
  cipProgram,
  catalogCluster,
  canonicalField,
}

/// Lightweight CIP program projection crosswalked to an occupation or field.
class CipProgramCrosswalk {
  final String code; // e.g. '11.0701'
  final String title; // e.g. 'Computer Science'
  final String? definition;
  final String mappingKind; // 'official_qualitative', 'advisory_board'

  const CipProgramCrosswalk({
    required this.code,
    required this.title,
    this.definition,
    this.mappingKind = 'official_qualitative',
  });

  factory CipProgramCrosswalk.fromJson(Map<String, dynamic> json) {
    return CipProgramCrosswalk(
      code: json['classification_code'] as String? ??
          json['code'] as String? ??
          '',
      title: json['classification_title'] as String? ??
          json['title'] as String? ??
          '',
      definition: json['definition'] as String?,
      mappingKind: json['mapping_kind'] as String? ?? 'official_qualitative',
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'title': title,
        'definition': definition,
        'mapping_kind': mappingKind,
      };
}

/// Learning Target linked to an occupation via field alignments.
class OccupationTargetLink {
  final String targetId;
  final String targetTitle;
  final String targetSlug;
  final String targetType; // 'career', 'academic_program', 'certification'
  final String fieldRole; // 'primary', 'supporting'
  final String? emoji;

  const OccupationTargetLink({
    required this.targetId,
    required this.targetTitle,
    required this.targetSlug,
    this.targetType = 'career',
    this.fieldRole = 'primary',
    this.emoji,
  });

  bool get isPrimary => fieldRole == 'primary';

  factory OccupationTargetLink.fromJson(Map<String, dynamic> json) {
    return OccupationTargetLink(
      targetId: json['target_id'] as String? ?? json['id'] as String? ?? '',
      targetTitle:
          json['target_title'] as String? ?? json['title'] as String? ?? '',
      targetSlug:
          json['target_slug'] as String? ?? json['slug'] as String? ?? '',
      targetType: json['target_type'] as String? ?? 'career',
      fieldRole: json['field_role'] as String? ?? 'primary',
      emoji: json['emoji'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'target_id': targetId,
        'target_title': targetTitle,
        'target_slug': targetSlug,
        'target_type': targetType,
        'field_role': fieldRole,
        'emoji': emoji,
      };
}

/// Unified search match across the entire taxonomy ontology.
class TaxonomySearchMatch {
  final String id;
  final String code;
  final String title;
  final String? description;
  final TaxonomyItemKind kind;
  final int? jobZone;
  final String? level;
  final String? system; // 'bls_soc', 'onet_soc', 'cip'

  const TaxonomySearchMatch({
    required this.id,
    required this.code,
    required this.title,
    this.description,
    required this.kind,
    this.jobZone,
    this.level,
    this.system,
  });
}

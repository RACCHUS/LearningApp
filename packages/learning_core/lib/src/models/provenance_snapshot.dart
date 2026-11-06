/// The 6 orthogonal provenance properties defined in Learning Science §5
/// and docs/learning_science/07_READINESS_AND_VALIDATION.md.
class ProvenanceSnapshot {
  final String origin;
  final String? originClientId;
  final String visibility;
  final String rightsStatus;
  final String reviewStatus;
  final String sourceAuthority;
  final Map<String, dynamic> versionValidity;

  const ProvenanceSnapshot({
    required this.origin,
    this.originClientId,
    required this.visibility,
    required this.rightsStatus,
    required this.reviewStatus,
    required this.sourceAuthority,
    required this.versionValidity,
  });

  factory ProvenanceSnapshot.fromJson(Map<String, dynamic> json) {
    return ProvenanceSnapshot(
      origin: json['origin'] as String? ?? 'user_import',
      originClientId: json['origin_client_id'] as String?,
      visibility: json['visibility'] as String? ?? 'private',
      rightsStatus: json['rights_status'] as String? ?? 'restricted_or_unknown',
      reviewStatus: json['review_status'] as String? ?? 'unreviewed',
      sourceAuthority:
          json['source_authority'] as String? ?? 'user_supplied_unverified',
      versionValidity:
          (json['version_validity'] as Map?)?.cast<String, dynamic>() ??
              {'status': 'active'},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'origin': origin,
      if (originClientId != null) 'origin_client_id': originClientId,
      'visibility': visibility,
      'rights_status': rightsStatus,
      'review_status': reviewStatus,
      'source_authority': sourceAuthority,
      'version_validity': versionValidity,
    };
  }

  static const officialRegulator = ProvenanceSnapshot(
    origin: 'official_source',
    visibility: 'public_catalog',
    rightsStatus: 'verified_permissive_or_public_domain',
    reviewStatus: 'authoritatively_verified',
    sourceAuthority: 'primary_regulator_or_statute',
    versionValidity: {'status': 'active'},
  );
}


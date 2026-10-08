enum TargetType {
  career,
  academicProgram,
  certification,
  licensureExam,
  standardizedExam,
  curriculumStandard;

  static TargetType fromString(String value) {
    switch (value) {
      case 'career':
        return TargetType.career;
      case 'academic_program':
        return TargetType.academicProgram;
      case 'certification':
        return TargetType.certification;
      case 'licensure_exam':
        return TargetType.licensureExam;
      case 'standardized_exam':
        return TargetType.standardizedExam;
      case 'curriculum_standard':
        return TargetType.curriculumStandard;
      default:
        return TargetType.career;
    }
  }

  String toDbString() {
    switch (this) {
      case TargetType.career:
        return 'career';
      case TargetType.academicProgram:
        return 'academic_program';
      case TargetType.certification:
        return 'certification';
      case TargetType.licensureExam:
        return 'licensure_exam';
      case TargetType.standardizedExam:
        return 'standardized_exam';
      case TargetType.curriculumStandard:
        return 'curriculum_standard';
    }
  }

  String get displayName {
    switch (this) {
      case TargetType.career:
        return 'Career';
      case TargetType.academicProgram:
        return 'Academic Program';
      case TargetType.certification:
        return 'Certification';
      case TargetType.licensureExam:
        return 'Licensure Exam';
      case TargetType.standardizedExam:
        return 'Standardized Exam';
      case TargetType.curriculumStandard:
        return 'Curriculum Standard';
    }
  }
}

enum TargetReviewStatus {
  unreviewed,
  pending,
  approved,
  rejected;

  static TargetReviewStatus fromString(String? value) {
    return TargetReviewStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => TargetReviewStatus.unreviewed,
    );
  }
}

enum TargetStatus {
  draft,
  published,
  archived;

  static TargetStatus fromString(String value) {
    return TargetStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TargetStatus.published,
    );
  }
}

enum TargetVersionStatus {
  draft,
  reviewReady,
  published,
  retired;

  static TargetVersionStatus fromString(String value) {
    switch (value) {
      case 'draft':
        return TargetVersionStatus.draft;
      case 'review_ready':
      case 'reviewReady':
        return TargetVersionStatus.reviewReady;
      case 'published':
        return TargetVersionStatus.published;
      case 'retired':
        return TargetVersionStatus.retired;
      default:
        return TargetVersionStatus.retired;
    }
  }

  String toDbString() {
    switch (this) {
      case TargetVersionStatus.draft:
        return 'draft';
      case TargetVersionStatus.reviewReady:
        return 'review_ready';
      case TargetVersionStatus.published:
        return 'published';
      case TargetVersionStatus.retired:
        return 'retired';
    }
  }
}

class LearningTarget {
  final String id;
  final TargetType targetType;
  final String? fieldId;
  final String title;
  final String slug;
  final String? description;
  final String? providerName;
  final String? institutionName;
  final String? jurisdiction;
  final String? imageUrl;
  final String? emoji;
  final bool isPublic;
  final bool isOfficial;
  final TargetReviewStatus reviewStatus;
  final TargetStatus status;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LearningTarget({
    required this.id,
    required this.targetType,
    this.fieldId,
    required this.title,
    required this.slug,
    this.description,
    this.providerName,
    this.institutionName,
    this.jurisdiction,
    this.imageUrl,
    this.emoji,
    this.isPublic = true,
    this.isOfficial = false,
    this.reviewStatus = TargetReviewStatus.unreviewed,
    this.status = TargetStatus.published,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LearningTarget.fromJson(Map<String, dynamic> json) {
    return LearningTarget(
      id: json['id'] as String,
      targetType: TargetType.fromString(json['target_type'] as String? ?? 'career'),
      fieldId: json['field_id'] as String?,
      title: json['title'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String?,
      providerName: json['provider_name'] as String?,
      institutionName: json['institution_name'] as String?,
      jurisdiction: json['jurisdiction'] as String?,
      imageUrl: json['image_url'] as String?,
      emoji: json['emoji'] as String?,
      isPublic: json['is_public'] as bool? ?? true,
      isOfficial: json['is_official'] as bool? ?? false,
      reviewStatus: TargetReviewStatus.fromString(json['review_status'] as String?),
      status: TargetStatus.fromString(json['status'] as String? ?? 'published'),
      createdBy: json['created_by'] as String?,
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
      'target_type': targetType.toDbString(),
      'field_id': fieldId,
      'title': title,
      'slug': slug,
      'description': description,
      'provider_name': providerName,
      'institution_name': institutionName,
      'jurisdiction': jurisdiction,
      'image_url': imageUrl,
      'emoji': emoji,
      'is_public': isPublic,
      'is_official': isOfficial,
      'review_status': reviewStatus.name,
      'status': status.name,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  LearningTarget copyWith({
    String? id,
    TargetType? targetType,
    String? fieldId,
    String? title,
    String? slug,
    String? description,
    String? providerName,
    String? institutionName,
    String? jurisdiction,
    String? imageUrl,
    String? emoji,
    bool? isPublic,
    bool? isOfficial,
    TargetReviewStatus? reviewStatus,
    TargetStatus? status,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LearningTarget(
      id: id ?? this.id,
      targetType: targetType ?? this.targetType,
      fieldId: fieldId ?? this.fieldId,
      title: title ?? this.title,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      providerName: providerName ?? this.providerName,
      institutionName: institutionName ?? this.institutionName,
      jurisdiction: jurisdiction ?? this.jurisdiction,
      imageUrl: imageUrl ?? this.imageUrl,
      emoji: emoji ?? this.emoji,
      isPublic: isPublic ?? this.isPublic,
      isOfficial: isOfficial ?? this.isOfficial,
      reviewStatus: reviewStatus ?? this.reviewStatus,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Only trusted, published entries should be suggested to other learners.
  bool get isTrustedPublic =>
      isPublic &&
      status == TargetStatus.published &&
      (isOfficial || reviewStatus == TargetReviewStatus.approved);

  /// Source labels distinguish platform verification from community review.
  String get sourceLabel {
    if (isOfficial) return 'Official';
    if (reviewStatus == TargetReviewStatus.approved) {
      return createdBy == null ? 'Catalog' : 'Community · reviewed';
    }
    if (reviewStatus == TargetReviewStatus.pending) return 'Community · pending review';
    if (reviewStatus == TargetReviewStatus.rejected) return 'Private · not approved';
    return 'My draft';
  }

  String get disambiguationTag {
    switch (targetType) {
      case TargetType.licensureExam:
        return jurisdiction != null && jurisdiction!.trim().isNotEmpty
            ? 'Licensure Exam ($jurisdiction)'
            : 'Licensure Exam';
      case TargetType.academicProgram:
        return institutionName != null && institutionName!.trim().isNotEmpty
            ? 'Academic Program ($institutionName)'
            : 'Academic Program';
      case TargetType.certification:
        return providerName != null && providerName!.trim().isNotEmpty
            ? 'Certification ($providerName)'
            : 'Certification';
      case TargetType.career:
        return 'Career';
      case TargetType.standardizedExam:
        return 'Standardized Exam';
      case TargetType.curriculumStandard:
        return jurisdiction != null && jurisdiction!.trim().isNotEmpty
            ? 'Curriculum Standard ($jurisdiction)'
            : 'Curriculum Standard';
    }
  }
}

class TargetVersion {
  final String id;
  final String targetId;
  final String versionCode;
  final String? title;
  final String? description;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final String? sourceUrl;
  final String? sourceTitle;
  final DateTime? sourceRetrievedAt;
  final Map<String, dynamic> metadata;
  final TargetVersionStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TargetVersion({
    required this.id,
    required this.targetId,
    required this.versionCode,
    this.title,
    this.description,
    this.validFrom,
    this.validUntil,
    this.sourceUrl,
    this.sourceTitle,
    this.sourceRetrievedAt,
    this.metadata = const {},
    this.status = TargetVersionStatus.draft,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDraft => status == TargetVersionStatus.draft;
  bool get isReviewReady => status == TargetVersionStatus.reviewReady;
  bool get isPublished => status == TargetVersionStatus.published;
  bool get isRetired => status == TargetVersionStatus.retired;
  bool get isEditable => isDraft;

  factory TargetVersion.fromJson(Map<String, dynamic> json) {
    return TargetVersion(
      id: json['id'] as String,
      targetId: json['target_id'] as String,
      versionCode: json['version_code'] as String? ?? 'v1',
      title: json['title'] as String?,
      description: json['description'] as String?,
      validFrom: json['valid_from'] != null
          ? DateTime.tryParse(json['valid_from'] as String)
          : null,
      validUntil: json['valid_until'] != null
          ? DateTime.tryParse(json['valid_until'] as String)
          : null,
      sourceUrl: json['source_url'] as String?,
      sourceTitle: json['source_title'] as String?,
      sourceRetrievedAt: json['source_retrieved_at'] != null
          ? DateTime.tryParse(json['source_retrieved_at'] as String)
          : null,
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
      status: TargetVersionStatus.fromString(json['status'] as String? ?? 'draft'),
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
      'target_id': targetId,
      'version_code': versionCode,
      'title': title,
      'description': description,
      'valid_from': validFrom?.toIso8601String(),
      'valid_until': validUntil?.toIso8601String(),
      'source_url': sourceUrl,
      'source_title': sourceTitle,
      'source_retrieved_at': sourceRetrievedAt?.toIso8601String(),
      'metadata': metadata,
      'status': status.toDbString(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  TargetVersion copyWith({
    String? id,
    String? targetId,
    String? versionCode,
    String? title,
    String? description,
    DateTime? validFrom,
    DateTime? validUntil,
    String? sourceUrl,
    String? sourceTitle,
    DateTime? sourceRetrievedAt,
    Map<String, dynamic>? metadata,
    TargetVersionStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TargetVersion(
      id: id ?? this.id,
      targetId: targetId ?? this.targetId,
      versionCode: versionCode ?? this.versionCode,
      title: title ?? this.title,
      description: description ?? this.description,
      validFrom: validFrom ?? this.validFrom,
      validUntil: validUntil ?? this.validUntil,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sourceTitle: sourceTitle ?? this.sourceTitle,
      sourceRetrievedAt: sourceRetrievedAt ?? this.sourceRetrievedAt,
      metadata: metadata ?? this.metadata,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

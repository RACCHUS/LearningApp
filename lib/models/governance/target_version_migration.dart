import '../user_concept_state.dart';

/// Represents a single concept mapping between two target versions.
class ConceptTransferDiff {
  final String fromConceptId;
  final String? toConceptId;
  final String mappingType;
  final double transferWeight;
  final String? fromConceptName;
  final String? toConceptName;
  final RetrievalBand? userRetrievalBand;

  const ConceptTransferDiff({
    required this.fromConceptId,
    this.toConceptId,
    required this.mappingType,
    this.transferWeight = 1.0,
    this.fromConceptName,
    this.toConceptName,
    this.userRetrievalBand,
  });

  bool get isRemoved => mappingType == 'removed' || toConceptId == null || transferWeight == 0;
  bool get isDirectMatch => fromConceptId == toConceptId && transferWeight == 1.0;
  bool get isScaled => transferWeight > 0 && transferWeight < 1.0;
  String get percentageLabel => '${(transferWeight * 100).toStringAsFixed(0)}%';

  factory ConceptTransferDiff.fromJson(Map<String, dynamic> json) {
    return ConceptTransferDiff(
      fromConceptId: json['from_concept_id'] as String,
      toConceptId: json['to_concept_id'] as String?,
      mappingType: json['mapping_type'] as String? ?? 'unchanged',
      transferWeight: (json['transfer_weight'] as num?)?.toDouble() ?? 1.0,
      fromConceptName: json['from_concept_name'] as String?,
      toConceptName: json['to_concept_name'] as String?,
      userRetrievalBand: json['user_retrieval_band'] != null
          ? RetrievalBand.fromString(json['user_retrieval_band'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'from_concept_id': fromConceptId,
        'to_concept_id': toConceptId,
        'mapping_type': mappingType,
        'transfer_weight': transferWeight,
        'from_concept_name': fromConceptName,
        'to_concept_name': toConceptName,
        if (userRetrievalBand != null)
          'user_retrieval_band': userRetrievalBand!.toDbString(),
      };
}

/// Evaluation projection showing how mastery and progress transfer across versions.
class TargetVersionMigrationEvaluation {
  final String fromTargetVersionId;
  final String toTargetVersionId;
  final int totalSourceConcepts;
  final int totalTargetConcepts;
  final int mappedConceptsCount;
  final int retainedConceptsCount;
  final int removedConceptsCount;
  final int newConceptsCount;
  final double transferRetentionPct;
  final int userAssessedConceptsCount;
  final double projectedRetainedAssessedCount;
  final List<ConceptTransferDiff> conceptMappings;

  const TargetVersionMigrationEvaluation({
    required this.fromTargetVersionId,
    required this.toTargetVersionId,
    required this.totalSourceConcepts,
    required this.totalTargetConcepts,
    required this.mappedConceptsCount,
    required this.retainedConceptsCount,
    required this.removedConceptsCount,
    required this.newConceptsCount,
    required this.transferRetentionPct,
    required this.userAssessedConceptsCount,
    required this.projectedRetainedAssessedCount,
    this.conceptMappings = const [],
  });

  bool get hasRemovedConcepts => removedConceptsCount > 0;
  bool get hasNewConcepts => newConceptsCount > 0;
  bool get isHighRetention => transferRetentionPct >= 80.0;

  factory TargetVersionMigrationEvaluation.fromJson(Map<String, dynamic> json) {
    return TargetVersionMigrationEvaluation(
      fromTargetVersionId: json['from_target_version_id'] as String,
      toTargetVersionId: json['to_target_version_id'] as String,
      totalSourceConcepts: (json['total_source_concepts'] as num?)?.toInt() ?? 0,
      totalTargetConcepts: (json['total_target_concepts'] as num?)?.toInt() ?? 0,
      mappedConceptsCount: (json['mapped_concepts_count'] as num?)?.toInt() ?? 0,
      retainedConceptsCount: (json['retained_concepts_count'] as num?)?.toInt() ?? 0,
      removedConceptsCount: (json['removed_concepts_count'] as num?)?.toInt() ?? 0,
      newConceptsCount: (json['new_concepts_count'] as num?)?.toInt() ?? 0,
      transferRetentionPct:
          (json['transfer_retention_pct'] as num?)?.toDouble() ?? 100.0,
      userAssessedConceptsCount:
          (json['user_assessed_concepts_count'] as num?)?.toInt() ?? 0,
      projectedRetainedAssessedCount:
          (json['projected_retained_assessed_count'] as num?)?.toDouble() ?? 0.0,
      conceptMappings: (json['concept_mappings'] as List<dynamic>?)
              ?.map((e) => ConceptTransferDiff.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'from_target_version_id': fromTargetVersionId,
        'to_target_version_id': toTargetVersionId,
        'total_source_concepts': totalSourceConcepts,
        'total_target_concepts': totalTargetConcepts,
        'mapped_concepts_count': mappedConceptsCount,
        'retained_concepts_count': retainedConceptsCount,
        'removed_concepts_count': removedConceptsCount,
        'new_concepts_count': newConceptsCount,
        'transfer_retention_pct': transferRetentionPct,
        'user_assessed_concepts_count': userAssessedConceptsCount,
        'projected_retained_assessed_count': projectedRetainedAssessedCount,
        'concept_mappings': conceptMappings.map((e) => e.toJson()).toList(),
      };
}

/// Result of executing a context target version migration.
class UserVersionMigrationResult {
  final bool success;
  final String contextId;
  final String fromVersionCode;
  final String toVersionCode;
  final int transferredConceptsCount;
  final double retainedMasteryPct;

  const UserVersionMigrationResult({
    required this.success,
    required this.contextId,
    required this.fromVersionCode,
    required this.toVersionCode,
    required this.transferredConceptsCount,
    required this.retainedMasteryPct,
  });

  factory UserVersionMigrationResult.fromJson(Map<String, dynamic> json) {
    return UserVersionMigrationResult(
      success: json['success'] as bool? ?? false,
      contextId: json['context_id'] as String,
      fromVersionCode: json['from_version_code'] as String? ?? '',
      toVersionCode: json['to_version_code'] as String? ?? '',
      transferredConceptsCount:
          (json['transferred_concepts_count'] as num?)?.toInt() ?? 0,
      retainedMasteryPct:
          (json['retained_mastery_pct'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'success': success,
        'context_id': contextId,
        'from_version_code': fromVersionCode,
        'to_version_code': toVersionCode,
        'transferred_concepts_count': transferredConceptsCount,
        'retained_mastery_pct': retainedMasteryPct,
      };
}

/// Represents the update availability for an active learning context.
class TargetVersionUpdateInfo {
  final String contextId;
  final String userId;
  final String targetId;
  final String targetTitle;
  final String? targetSlug;
  final String currentVersionId;
  final String currentVersionCode;
  final String? currentVersionTitle;
  final String currentVersionStatus;
  final String? latestVersionId;
  final String? latestVersionCode;
  final String? latestVersionTitle;
  final String? latestVersionStatus;
  final bool isOutdated;
  final bool isRetired;

  const TargetVersionUpdateInfo({
    required this.contextId,
    required this.userId,
    required this.targetId,
    required this.targetTitle,
    this.targetSlug,
    required this.currentVersionId,
    required this.currentVersionCode,
    this.currentVersionTitle,
    required this.currentVersionStatus,
    this.latestVersionId,
    this.latestVersionCode,
    this.latestVersionTitle,
    this.latestVersionStatus,
    required this.isOutdated,
    required this.isRetired,
  });

  bool get needsUpgrade => isOutdated || isRetired;

  String get upgradeReason {
    if (isRetired) {
      return 'Your current edition ($currentVersionCode) has been retired. Upgrade to $latestVersionCode to study the active blueprint.';
    }
    if (isOutdated) {
      return 'A newer official blueprint ($latestVersionCode) is available for $targetTitle.';
    }
    return 'Your curriculum is on the latest official blueprint.';
  }

  factory TargetVersionUpdateInfo.fromJson(Map<String, dynamic> json) {
    return TargetVersionUpdateInfo(
      contextId: json['context_id'] as String,
      userId: json['user_id'] as String,
      targetId: json['target_id'] as String,
      targetTitle: json['target_title'] as String,
      targetSlug: json['target_slug'] as String?,
      currentVersionId: json['current_version_id'] as String,
      currentVersionCode: json['current_version_code'] as String,
      currentVersionTitle: json['current_version_title'] as String?,
      currentVersionStatus: json['current_version_status'] as String? ?? 'published',
      latestVersionId: json['latest_version_id'] as String?,
      latestVersionCode: json['latest_version_code'] as String?,
      latestVersionTitle: json['latest_version_title'] as String?,
      latestVersionStatus: json['latest_version_status'] as String?,
      isOutdated: json['is_outdated'] as bool? ?? false,
      isRetired: json['is_retired'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'context_id': contextId,
        'user_id': userId,
        'target_id': targetId,
        'target_title': targetTitle,
        'target_slug': targetSlug,
        'current_version_id': currentVersionId,
        'current_version_code': currentVersionCode,
        'current_version_title': currentVersionTitle,
        'current_version_status': currentVersionStatus,
        'latest_version_id': latestVersionId,
        'latest_version_code': latestVersionCode,
        'latest_version_title': latestVersionTitle,
        'latest_version_status': latestVersionStatus,
        'is_outdated': isOutdated,
        'is_retired': isRetired,
      };
}

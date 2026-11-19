import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/governance/governance.dart';
import '../services/governance/version_governance_service.dart';

/// Provider for VersionGovernanceService
final versionGovernanceServiceProvider = Provider<VersionGovernanceService>((ref) {
  return VersionGovernanceService();
});

/// Checks if an active learning context is bound to an outdated or retired version
final contextVersionUpdateProvider =
    FutureProvider.family<TargetVersionUpdateInfo?, String>((ref, contextId) async {
  final service = ref.watch(versionGovernanceServiceProvider);
  return service.getContextVersionUpdate(contextId);
});

/// Parameters for evaluating a version migration
class MigrationEvaluationParams {
  final String userId;
  final String fromVersionId;
  final String toVersionId;

  const MigrationEvaluationParams({
    required this.userId,
    required this.fromVersionId,
    required this.toVersionId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MigrationEvaluationParams &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          fromVersionId == other.fromVersionId &&
          toVersionId == other.toVersionId;

  @override
  int get hashCode =>
      userId.hashCode ^ fromVersionId.hashCode ^ toVersionId.hashCode;
}

/// Evaluates progress transfer and concept retention between versions
final migrationEvaluationProvider = FutureProvider.family<
    TargetVersionMigrationEvaluation,
    MigrationEvaluationParams>((ref, params) async {
  final service = ref.watch(versionGovernanceServiceProvider);
  return service.evaluateMigration(
    userId: params.userId,
    fromVersionId: params.fromVersionId,
    toVersionId: params.toVersionId,
  );
});

/// Runs and caches a QA readiness audit report for a target version
final targetVersionAuditProvider =
    FutureProvider.family<TargetVersionAuditReport, String>((ref, versionId) async {
  final service = ref.watch(versionGovernanceServiceProvider);
  return service.auditTargetVersionReadiness(versionId);
});

/// Fetches all staged target versions (draft or review_ready)
final stagedTargetVersionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(versionGovernanceServiceProvider);
  return service.getStagedTargetVersions();
});

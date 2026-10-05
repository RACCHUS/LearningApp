import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/governance/governance.dart';

/// Service managing target version migrations, progress transfers,
/// QA readiness audits, and publication/retirement lifecycle transitions.
class VersionGovernanceService {
  final SupabaseClient? _supabase;

  VersionGovernanceService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient;

  SupabaseClient? get _client {
    if (_supabase != null) return _supabase;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Checks if an active learning context is bound to an outdated or retired TargetVersion.
  ///
  /// Errors intentionally propagate: a governance lookup failure must not be
  /// indistinguishable from "no update available".
  Future<TargetVersionUpdateInfo?> getContextVersionUpdate(String contextId) async {
    final client = _requireClient();
    final res = await client
        .from('v_target_version_updates')
        .select()
        .eq('context_id', contextId)
        .maybeSingle();

    if (res == null) return null;
    return TargetVersionUpdateInfo.fromJson(res);
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw StateError(
        'Version governance requires an initialized Supabase client. '
        'Governance operations must not fall back to fabricated data.',
      );
    }
    return client;
  }

  /// Evaluates progress transfer and concept retention between two versions.
  Future<TargetVersionMigrationEvaluation> evaluateMigration({
    required String userId,
    required String fromVersionId,
    required String toVersionId,
  }) async {
    final client = _requireClient();
    final res = await client.rpc(
      'evaluate_target_version_migration',
      params: {
        'p_user_id': userId,
        'p_from_target_version_id': fromVersionId,
        'p_to_target_version_id': toVersionId,
      },
    );

    if (res is Map<String, dynamic>) {
      return TargetVersionMigrationEvaluation.fromJson(res);
    }
    if (res is Map) {
      return TargetVersionMigrationEvaluation.fromJson(
        res.cast<String, dynamic>(),
      );
    }
    throw StateError('Unexpected response from evaluate_target_version_migration');
  }

  /// Safely migrates a learner's active context to a destination TargetVersion,
  /// preserving historical review items and carrying forward scaled concept evidence.
  Future<UserVersionMigrationResult> migrateUserContext({
    required String userId,
    required String contextId,
    required String toVersionId,
  }) async {
    final client = _requireClient();
    final res = await client.rpc(
      'migrate_user_context_target_version',
      params: {
        'p_user_id': userId,
        'p_context_id': contextId,
        'p_to_target_version_id': toVersionId,
      },
    );

    if (res is Map<String, dynamic>) {
      return UserVersionMigrationResult.fromJson(res);
    }
    if (res is Map) {
      return UserVersionMigrationResult.fromJson(res.cast<String, dynamic>());
    }
    throw StateError('Unexpected response from migrate_user_context_target_version');
  }

  /// Runs the full database QA readiness audit on a target version.
  Future<TargetVersionAuditReport> auditTargetVersionReadiness(
    String targetVersionId,
  ) async {
    final client = _requireClient();
    final res = await client.rpc(
      'audit_target_version_readiness',
      params: {'p_target_version_id': targetVersionId},
    );

    if (res is Map<String, dynamic>) {
      return TargetVersionAuditReport.fromJson(res);
    }
    if (res is Map) {
      return TargetVersionAuditReport.fromJson(res.cast<String, dynamic>());
    }
    throw StateError('Unexpected response from audit_target_version_readiness');
  }

  /// Transitions a draft target version to review_ready status.
  Future<void> stageReview(String targetVersionId) async {
    final client = _requireClient();

    await client
        .from('target_versions')
        .update({
          'status': 'review_ready',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', targetVersionId);
  }

  /// Promotes a review_ready version to immutable published status.
  Future<Map<String, dynamic>> publishVersion(
    String targetVersionId, {
    bool retirePrevious = false,
  }) async {
    final client = _requireClient();
    final res = await client.rpc(
      'publish_target_version',
      params: {
        'p_version_id': targetVersionId,
        'p_retire_previous': retirePrevious,
      },
    );

    if (res is Map<String, dynamic>) return res;
    if (res is Map) return res.cast<String, dynamic>();
    throw StateError('Unexpected response from publish_target_version');
  }

  /// Deprecates and retires an older published target version.
  Future<Map<String, dynamic>> retireVersion(String targetVersionId) async {
    final client = _requireClient();
    final res = await client.rpc(
      'retire_target_version',
      params: {'p_version_id': targetVersionId},
    );

    if (res is Map<String, dynamic>) return res;
    if (res is Map) return res.cast<String, dynamic>();
    throw StateError('Unexpected response from retire_target_version');
  }

  /// Queries all versions currently in draft or review_ready staging.
  Future<List<Map<String, dynamic>>> getStagedTargetVersions() async {
    final client = _requireClient();
    final res = await client
        .from('target_versions')
        .select(
          'id, version_code, title, status, created_at, target_id, '
          'learning_targets(title, target_type)',
        )
        .inFilter('status', ['draft', 'review_ready'])
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(res);
  }

}

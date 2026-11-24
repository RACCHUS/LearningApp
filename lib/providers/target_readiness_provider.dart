import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/governance/site_feature_keys.dart';
import '../models/readiness_coverage.dart';
import '../models/user_concept_state.dart';
import '../services/concept_evidence_service.dart';
import '../services/governance/site_feature_service.dart';
import '../services/target_readiness_service.dart';
import 'learning_context_provider.dart';
import 'site_feature_provider.dart';

/// Reads aggregate held-out check coverage for a target version (D-14).
abstract class ReadinessCoverageApi {
  Future<Map<String, dynamic>?> fetch(String targetVersionId);
}

class SupabaseReadinessCoverageApi implements ReadinessCoverageApi {
  @override
  Future<Map<String, dynamic>?> fetch(String targetVersionId) async {
    final res = await Supabase.instance.client.rpc(
      'get_target_readiness_coverage',
      params: {'p_target_version_id': targetVersionId},
    );
    return res == null ? null : Map<String, dynamic>.from(res as Map);
  }
}

final readinessCoverageApiProvider = Provider<ReadinessCoverageApi>(
  (ref) => SupabaseReadinessCoverageApi(),
);

/// Switch `learning.readiness_coverage_gate` (default OFF).
final readinessCoverageGateEnabledProvider = Provider<bool>((ref) {
  return isSiteFeatureEnabled(
    ref.watch(siteFeatureSnapshotProvider).valueOrNull,
    SiteFeatureKeys.learningReadinessCoverageGate,
    runtimeReady: SiteFeatureRuntime.snapshotEnabled,
  );
});

/// Null while the gate is off: readiness shows exactly as before and nothing
/// is fetched. With the gate on, a failed read fails closed (readiness hidden).
final readinessCoverageProvider =
    FutureProvider.family<ReadinessCoverage?, String>((ref, targetVersionId) async {
  if (!ref.watch(readinessCoverageGateEnabledProvider) || targetVersionId.isEmpty) {
    return null;
  }
  try {
    final json = await ref.watch(readinessCoverageApiProvider).fetch(targetVersionId);
    if (json == null) return const ReadinessCoverage.unavailable();
    return ReadinessCoverage.fromJson(json);
  } catch (_) {
    return const ReadinessCoverage.unavailable();
  }
});

final conceptEvidenceServiceProvider = Provider<ConceptEvidenceService>((ref) {
  return ConceptEvidenceService();
});

final targetReadinessServiceProvider = Provider<TargetReadinessService>((ref) {
  final evidenceService = ref.watch(conceptEvidenceServiceProvider);
  return TargetReadinessService(
    supabase: Supabase.instance.client,
    evidenceService: evidenceService,
  );
});

/// Computes qualitative TargetReadiness for a given targetVersionId.
final targetReadinessProvider =
    FutureProvider.family<TargetReadiness, String>((ref, targetVersionId) async {
  final userId = ref.watch(learnerIdProvider);
  final service = ref.watch(targetReadinessServiceProvider);
  final activeContext = ref.watch(activeLearningContextProvider);

  DateTime? examDate;
  if (activeContext != null) {
    final rawDate = activeContext.scopeConfig['examDate'] ??
        activeContext.scopeConfig['targetDate'];
    if (rawDate is String && rawDate.isNotEmpty) {
      examDate = DateTime.tryParse(rawDate);
    }
  }

  return service.evaluateTargetReadiness(
    userId: userId,
    targetVersionId: targetVersionId,
    examDate: examDate,
  );
});

/// Keyed independently from the existing target-wide readiness provider.
/// Only a caller that explicitly selects a configured exam part may use it.
typedef ExamPartReadinessKey = ({String targetVersionId, String examPartKey});

final examPartReadinessProvider = FutureProvider.autoDispose
    .family<TargetReadiness, ExamPartReadinessKey>((ref, key) async {
  final userId = ref.watch(learnerIdProvider);
  final service = ref.watch(targetReadinessServiceProvider);
  return service.evaluateTargetReadiness(
    userId: userId,
    targetVersionId: key.targetVersionId,
    examPartKey: key.examPartKey,
  );
});

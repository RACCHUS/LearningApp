import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/governance/site_feature_keys.dart';
import '../models/objective_readiness.dart';
import '../models/readiness_coverage.dart';
import '../models/user_concept_state.dart';
import '../services/concept_evidence_service.dart';
import '../services/planning/readiness_projection.dart';
import '../services/governance/site_feature_service.dart';
import '../services/target_readiness_service.dart';
import 'daily_goal_provider.dart';
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
    FutureProvider.family<ReadinessCoverage?, String>((
      ref,
      targetVersionId,
    ) async {
      if (!ref.watch(readinessCoverageGateEnabledProvider) ||
          targetVersionId.isEmpty) {
        return null;
      }
      try {
        final json = await ref
            .watch(readinessCoverageApiProvider)
            .fetch(targetVersionId);
        if (json == null) return const ReadinessCoverage.unavailable();
        return ReadinessCoverage.fromJson(json);
      } catch (_) {
        return const ReadinessCoverage.unavailable();
      }
    });

/// Reads readiness by objective for a target version (plan v1.2 §8.7).
abstract class ObjectiveReadinessApi {
  Future<Map<String, dynamic>?> fetch(String targetVersionId);
}

class SupabaseObjectiveReadinessApi implements ObjectiveReadinessApi {
  @override
  Future<Map<String, dynamic>?> fetch(String targetVersionId) async {
    final res = await Supabase.instance.client.rpc(
      'get_target_objective_readiness',
      params: {'p_target_version_id': targetVersionId},
    );
    return res == null ? null : Map<String, dynamic>.from(res as Map);
  }
}

final objectiveReadinessApiProvider = Provider<ObjectiveReadinessApi>(
  (ref) => SupabaseObjectiveReadinessApi(),
);

/// Switch `learning.objective_readiness_view` (default OFF).
final objectiveReadinessViewEnabledProvider = Provider<bool>((ref) {
  return isSiteFeatureEnabled(
    ref.watch(siteFeatureSnapshotProvider).valueOrNull,
    SiteFeatureKeys.learningObjectiveReadinessView,
    runtimeReady: SiteFeatureRuntime.snapshotEnabled,
  );
});

/// Null while the switch is off or when the view can't be read: the card is
/// then simply not shown (it adds detail; nothing else depends on it).
final objectiveReadinessProvider =
    FutureProvider.family<TargetObjectiveReadiness?, String>((
      ref,
      targetVersionId,
    ) async {
      if (!ref.watch(objectiveReadinessViewEnabledProvider) ||
          targetVersionId.isEmpty) {
        return null;
      }
      try {
        final json = await ref
            .watch(objectiveReadinessApiProvider)
            .fetch(targetVersionId);
        return json == null ? null : TargetObjectiveReadiness.fromJson(json);
      } catch (_) {
        return null;
      }
    });

/// Reads per-objective study-time estimates (plan v1.2 §8.5 item 4, §8.7).
abstract class StudyEstimatesApi {
  Future<Map<String, dynamic>?> fetch(String targetVersionId);
}

class SupabaseStudyEstimatesApi implements StudyEstimatesApi {
  @override
  Future<Map<String, dynamic>?> fetch(String targetVersionId) async {
    final res = await Supabase.instance.client.rpc(
      'get_target_study_estimates',
      params: {'p_target_version_id': targetVersionId},
    );
    return res == null ? null : Map<String, dynamic>.from(res as Map);
  }
}

final studyEstimatesApiProvider = Provider<StudyEstimatesApi>(
  (ref) => SupabaseStudyEstimatesApi(),
);

/// Switch `learning.readiness_projection` (default OFF).
final readinessProjectionEnabledProvider = Provider<bool>((ref) {
  return isSiteFeatureEnabled(
    ref.watch(siteFeatureSnapshotProvider).valueOrNull,
    SiteFeatureKeys.learningReadinessProjection,
    runtimeReady: SiteFeatureRuntime.snapshotEnabled,
  );
});

/// Active study minutes in the last 28 days (UTC days), from the learner's
/// own progress rows. Null for guests or when it can't be read.
final recentStudyMinutesProvider = FutureProvider<int?>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return null;
  final since = DateTime.now().toUtc().subtract(const Duration(days: 27));
  final from =
      '${since.year.toString().padLeft(4, '0')}-'
      '${since.month.toString().padLeft(2, '0')}-${since.day.toString().padLeft(2, '0')}';
  try {
    final rows = await Supabase.instance.client
        .from('learner_activity_progress')
        .select('active_seconds')
        .eq('user_id', userId)
        .gte('reporting_date_utc', from);
    var seconds = 0;
    for (final r in rows as List) {
      final s = (r as Map)['active_seconds'];
      if (s is num) seconds += s.toInt();
    }
    return seconds ~/ 60;
  } catch (_) {
    return null;
  }
});

/// Projected finish for a target version. Null while the switch is off, when
/// readiness by objective or the estimates can't be read, or when nothing in
/// the target has an estimate: the section is then simply not shown.
final readinessProjectionProvider =
    FutureProvider.family<ReadinessProjection?, String>((
      ref,
      targetVersionId,
    ) async {
      if (!ref.watch(readinessProjectionEnabledProvider) ||
          targetVersionId.isEmpty) {
        return null;
      }
      // Every dependency is watched before the first await, so a change to any
      // of them (a new exam date, daily goal or status) recomputes the projection.
      final viewFuture = ref.watch(
        objectiveReadinessProvider(targetVersionId).future,
      );
      final goalFuture = ref.watch(dailyGoalMinutesProvider.future);
      final recentFuture = ref.watch(recentStudyMinutesProvider.future);
      final api = ref.watch(studyEstimatesApiProvider);
      final context = ref.watch(activeLearningContextProvider);
      DateTime? examDate;
      if (context != null && context.targetVersionId == targetVersionId) {
        final raw =
            context.scopeConfig['examDate'] ??
            context.scopeConfig['targetDate'];
        if (raw is String && raw.isNotEmpty) examDate = DateTime.tryParse(raw);
      }
      final view = await viewFuture;
      if (view == null) return null;
      Map<String, StudyEstimate>? estimates;
      try {
        final json = await api.fetch(targetVersionId);
        estimates = json == null ? null : parseStudyEstimates(json);
      } catch (_) {
        return null;
      }
      if (estimates == null) return null;
      final dailyGoal = await goalFuture;
      int? recent;
      try {
        recent = await recentFuture;
      } catch (_) {
        recent = null;
      }
      return projectReadiness(
        view: view,
        estimates: estimates,
        dailyGoalMinutes: dailyGoal,
        now: DateTime.now(),
        examDate: examDate,
        recentMinutes28Days: recent,
      );
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
final targetReadinessProvider = FutureProvider.family<TargetReadiness, String>((
  ref,
  targetVersionId,
) async {
  final userId = ref.watch(learnerIdProvider);
  final service = ref.watch(targetReadinessServiceProvider);
  final activeContext = ref.watch(activeLearningContextProvider);

  DateTime? examDate;
  if (activeContext != null) {
    final rawDate =
        activeContext.scopeConfig['examDate'] ??
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

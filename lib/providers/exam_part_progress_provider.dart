import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/assessment_engine/exam_reference_manifest.dart';
import '../models/assessment/diagnostic_assessment.dart';
import '../models/user_concept_state.dart';
import '../services/assessment/exam_part_curriculum_scope.dart';
import '../services/assessment/exam_part_next_action_engine.dart';
import 'diagnostic_assessment_provider.dart';
import 'learning_context_provider.dart';
import 'target_readiness_provider.dart';

typedef ExamPartProfileKey = ({String targetId, String targetVersionId});
typedef ExamPartProgressKey = ({
  String targetId,
  String targetVersionId,
  String examPartKey,
  String learnerId,
});

/// Only published, exact target-owned version metadata can advertise parts.
/// This is catalog configuration, not authorization of official exam rules.
class ExamPartProfileService {
  final SupabaseClient _supabase;
  ExamPartProfileService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<ExamPreparationProfile?> load(ExamPartProfileKey key) async {
    final version = await _supabase
        .from('target_versions')
        .select('id, target_id, status, metadata')
        .eq('id', key.targetVersionId)
        .maybeSingle();
    if (version == null ||
        version['id'] != key.targetVersionId ||
        version['target_id'] != key.targetId ||
        version['status'] != 'published') {
      throw StateError('Exam part list is unavailable for this target version.');
    }
    final raw = version['metadata'];
    if (raw is! Map) return null;
    return ExamPreparationProfile.fromTargetVersionMetadata(
      targetVersionId: key.targetVersionId,
      metadata: Map<String, dynamic>.from(raw),
    );
  }
}

final examPartProfileServiceProvider = Provider<ExamPartProfileService>((ref) {
  return ExamPartProfileService();
});

final examPartProfileProvider = FutureProvider.autoDispose
    .family<ExamPreparationProfile?, ExamPartProfileKey>((ref, key) {
  return ref.watch(examPartProfileServiceProvider).load(key);
});

class ExamPartProgressSnapshot {
  final ExamPartProgressKey key;
  final String rootNodeId;
  final TargetReadiness knowledge;
  final DiagnosticAvailability diagnostic;
  final ExamPartNextStep nextStep;

  const ExamPartProgressSnapshot({
    required this.key,
    required this.rootNodeId,
    required this.knowledge,
    required this.diagnostic,
    required this.nextStep,
  });

  /// No canonical per-part historical practice-attempt store exists yet.
  /// In particular, don't interpret global user_concept_state as exam results.
  bool get hasVerifiedPartAttemptHistory => false;
}

final examPartProgressProvider = FutureProvider.autoDispose
    .family<ExamPartProgressSnapshot, ExamPartProgressKey>((ref, key) async {
  final currentLearner = ref.watch(learnerIdProvider);
  if (key.learnerId != currentLearner) {
    throw StateError('Cannot access another learner’s scoped progress.');
  }
  final profile = await ref.watch(examPartProfileProvider((
    targetId: key.targetId,
    targetVersionId: key.targetVersionId,
  )).future);
  final part = profile?.findPart(key.examPartKey);
  if (part == null || !part.hasScopeRootCandidate) {
    throw StateError('Selected exam part is not configured for this version.');
  }

  // Independently resolve the actual descendant tree; metadata alone
  // cannot authorize an exam-part read or result.
  final scope = await ExamPartCurriculumScopeResolver().resolve(
    targetVersionId: key.targetVersionId,
    examPartKey: key.examPartKey,
  );
  if (scope.rootNodeId != part.curriculumRootNodeId) {
    throw StateError('Exam part curriculum root changed during this read.');
  }
  final knowledge = await ref.watch(examPartReadinessProvider((
    targetVersionId: key.targetVersionId,
    examPartKey: key.examPartKey,
  )).future);
  final diagnostic = await ref.watch(examPartDiagnosticAvailabilityProvider((
    targetId: key.targetId,
    targetVersionId: key.targetVersionId,
    examPartKey: key.examPartKey,
  )).future);
  if (knowledge.targetVersionId != key.targetVersionId ||
      diagnostic.targetVersionId != key.targetVersionId ||
      ref.read(learnerIdProvider) != key.learnerId) {
    throw StateError('Scoped progress identity changed during loading.');
  }

  return ExamPartProgressSnapshot(
    key: key,
    rootNodeId: scope.rootNodeId,
    knowledge: knowledge,
    diagnostic: diagnostic,
    nextStep: const ExamPartNextActionEngine().recommend(
      readiness: knowledge,
      diagnostic: diagnostic,
    ),
  );
});

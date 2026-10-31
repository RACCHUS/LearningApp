import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_concept_state.dart';
import '../services/concept_evidence_service.dart';
import '../services/target_readiness_service.dart';
import 'learning_context_provider.dart';

final conceptEvidenceServiceProvider = Provider<ConceptEvidenceService>((ref) {
  return ConceptEvidenceService(supabase: Supabase.instance.client);
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
  return service.evaluateTargetReadiness(
    userId: userId,
    targetVersionId: targetVersionId,
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

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

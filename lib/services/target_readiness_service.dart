import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_concept_state.dart';
import 'concept_evidence_service.dart';

/// Evaluates learner readiness for a Learning Target Version per spec §9.
///
/// Formula:
/// Readiness = (Σ_{c ∈ coreConcepts} ConceptReadiness(c) * Weight(c)) / (Σ_{c ∈ coreConcepts} Weight(c))
///
/// Exclusively produces qualitative readiness bands:
/// - Strong coverage
/// - Developing
/// - Needs reinforcement
/// - Not yet assessed
///
/// Knowledge readiness is kept strictly distinct from structural completion.
class TargetReadinessService {
  final SupabaseClient _supabase;
  final ConceptEvidenceService _evidenceService;

  TargetReadinessService({
    SupabaseClient? supabase,
    ConceptEvidenceService? evidenceService,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _evidenceService = evidenceService ?? ConceptEvidenceService(supabase: supabase);

  /// Computes target readiness for the given target version and user.
  Future<TargetReadiness> evaluateTargetReadiness({
    required String userId,
    required String targetVersionId,
  }) async {
    if (targetVersionId.isEmpty) {
      return TargetReadiness(
        targetVersionId: targetVersionId,
        band: TargetReadinessBand.notYetAssessed,
        score: 0.0,
        totalCoreConcepts: 0,
        assessedConceptsCount: 0,
        bandDistribution: {for (final b in RetrievalBand.values) b: 0},
      );
    }

    try {
      // 1. Get curriculum node IDs for this target version
      final nodesRes = await _supabase
          .from('curriculum_nodes')
          .select('id')
          .eq('target_version_id', targetVersionId);

      final nodeIds = (nodesRes as List).map((n) => n['id'] as String).toList();
      if (nodeIds.isEmpty) {
        return TargetReadiness(
          targetVersionId: targetVersionId,
          band: TargetReadinessBand.notYetAssessed,
          score: 0.0,
          totalCoreConcepts: 0,
          assessedConceptsCount: 0,
          bandDistribution: {for (final b in RetrievalBand.values) b: 0},
        );
      }

      // 2. Fetch core concepts mapped to these nodes
      final conceptsRes = await _supabase
          .from('curriculum_node_concepts')
          .select('concept_id, weight')
          .filter('curriculum_node_id', 'in', nodeIds)
          .eq('relevance', 'core');

      // Deduplicate concepts, preserving the highest weight
      final weightMap = <String, double>{};
      for (final row in conceptsRes as List) {
        final cid = row['concept_id'] as String;
        final w = (row['weight'] as num?)?.toDouble() ?? 1.0;
        if (!weightMap.containsKey(cid) || w > weightMap[cid]!) {
          weightMap[cid] = w;
        }
      }

      final coreConceptList = weightMap.entries
          .map((e) => (conceptId: e.key, weight: e.value))
          .toList();

      if (coreConceptList.isEmpty) {
        return TargetReadiness(
          targetVersionId: targetVersionId,
          band: TargetReadinessBand.notYetAssessed,
          score: 0.0,
          totalCoreConcepts: 0,
          assessedConceptsCount: 0,
          bandDistribution: {for (final b in RetrievalBand.values) b: 0},
        );
      }

      // 3. Fetch user concept states for these core concepts
      final states = userId.isNotEmpty
          ? await _evidenceService.getUserConceptStates(
              userId,
              conceptIds: weightMap.keys.toList(),
            )
          : <String, UserConceptState>{};

      // 4. Evaluate qualitative readiness
      return TargetReadiness.evaluate(
        targetVersionId: targetVersionId,
        coreConcepts: coreConceptList,
        userConceptStates: states,
      );
    } catch (e) {
      debugPrint('⚠️ Error evaluating target readiness for $targetVersionId: $e');
      return TargetReadiness(
        targetVersionId: targetVersionId,
        band: TargetReadinessBand.notYetAssessed,
        score: 0.0,
        totalCoreConcepts: 0,
        assessedConceptsCount: 0,
        bandDistribution: {for (final b in RetrievalBand.values) b: 0},
      );
    }
  }
}

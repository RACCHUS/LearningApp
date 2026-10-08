import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/spaced_repetition.dart';
import '../models/user_concept_state.dart';

/// Implements the Evidence Propagation Contract per Learning Architecture v2 §8.2.
///
/// Every completed learning activity produces a normalized evidenceValue ∈ [0.0, 1.0]:
/// - MCQ / TrueFalse correct: 1.0, incorrect: 0.0
/// - SM-2 Recall Grade: grade >= 3 => 1.0, else 0.0
/// - Rubric / Partial credit: fractional value (0.0 ... 1.0)
///
/// Propagates evidence to all concepts mapped to the content item and updates
/// the user's analytical projection in `user_concept_state`.
class ConceptEvidenceService {
  final SupabaseClient _supabase;

  ConceptEvidenceService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Records retrieval evidence asynchronously for an item without blocking SM-2 or UI.
  Future<void> recordEvidence({
    required String userId,
    required String contentId,
    required ReviewableContentType contentType,
    required double evidenceValue,
    String? lessonId,
  }) async {
    if (userId.isEmpty || contentId.isEmpty) return;

    try {
      final normalizedEvidence = evidenceValue.clamp(0.0, 1.0);
      final mappedConcepts = await _resolveMappedConcepts(
        contentId: contentId,
        contentType: contentType,
        lessonId: lessonId,
      );

      if (mappedConcepts.isEmpty) return;

      await _applyMappedEvidence(
        userId: userId,
        evidenceValue: normalizedEvidence,
        mappedConcepts: mappedConcepts,
      );
    } catch (e) {
      debugPrint('⚠️ Error propagating concept evidence for content $contentId: $e');
    }
  }

  /// Records evidence produced by a canonical v2 assessment item.
  ///
  /// Returns true only when at least one canonical assessment_item_concepts
  /// mapping was resolved and all concept-state upserts completed. Diagnostic
  /// and exam flows can use this to distinguish a report computed in memory
  /// from evidence that actually reached the learner's concept model.
  Future<bool> recordAssessmentItemEvidence({
    required String userId,
    required String assessmentItemId,
    required double evidenceValue,
  }) async {
    if (userId.isEmpty || assessmentItemId.isEmpty) return false;

    try {
      final res = await _supabase
          .from('assessment_item_concepts')
          .select('concept_id, weight')
          .eq('assessment_item_id', assessmentItemId);

      final mappedConcepts = <({String conceptId, double weight})>[];
      for (final row in res as List) {
        mappedConcepts.add((
          conceptId: row['concept_id'] as String,
          weight: (row['weight'] as num?)?.toDouble() ?? 1.0,
        ));
      }

      if (mappedConcepts.isEmpty) return false;

      await _applyMappedEvidence(
        userId: userId,
        evidenceValue: evidenceValue.clamp(0.0, 1.0),
        mappedConcepts: mappedConcepts,
      );
      return true;
    } catch (e) {
      debugPrint(
        '⚠️ Error propagating assessment-item evidence for '
        '$assessmentItemId: $e',
      );
      return false;
    }
  }

  Future<void> _applyMappedEvidence({
    required String userId,
    required double evidenceValue,
    required List<({String conceptId, double weight})> mappedConcepts,
  }) async {
    final now = DateTime.now();

    for (final mapping in mappedConcepts) {
      final conceptId = mapping.conceptId;
      final weight = mapping.weight.clamp(0.0, 1.0);

      final existingRes = await _supabase
          .from('user_concept_state')
          .select()
          .eq('user_id', userId)
          .eq('concept_id', conceptId)
          .maybeSingle();

      final existing =
          existingRes != null ? UserConceptState.fromJson(existingRes) : null;
      final newWeightedTotal = (existing?.weightedTotal ?? 0.0) + weight;
      final newWeightedCorrect =
          (existing?.weightedCorrect ?? 0.0) + (evidenceValue * weight);
      final newEvidenceCount = (existing?.evidenceCount ?? 0) + 1;
      final accuracy = newWeightedTotal > 0
          ? (newWeightedCorrect / newWeightedTotal).clamp(0.0, 1.0)
          : 0.0;

      final computed = UserConceptState.computeBandAndConfidence(
        accuracy: accuracy,
        evidenceCount: newEvidenceCount,
      );

      final updatedState = UserConceptState(
        userId: userId,
        conceptId: conceptId,
        retrievalBand: computed.band,
        confidence: computed.confidence,
        evidenceCount: newEvidenceCount,
        weightedCorrect: newWeightedCorrect,
        weightedTotal: newWeightedTotal,
        lastEvidenceAt: now,
        updatedAt: now,
      );

      await _supabase.from('user_concept_state').upsert(updatedState.toJson());
    }
  }

  /// Resolves mapped concepts and their weights for an item.
  Future<List<({String conceptId, double weight})>> _resolveMappedConcepts({
    required String contentId,
    required ReviewableContentType contentType,
    String? lessonId,
  }) async {
    final results = <({String conceptId, double weight})>[];

    try {
      switch (contentType) {
        case ReviewableContentType.term:
          final res = await _supabase
              .from('term_concepts')
              .select('concept_id, weight')
              .eq('term_id', contentId);
          for (final row in res as List) {
            results.add((
              conceptId: row['concept_id'] as String,
              weight: (row['weight'] as num?)?.toDouble() ?? 1.0,
            ));
          }
          break;

        case ReviewableContentType.question:
        case ReviewableContentType.multipleChoice:
        case ReviewableContentType.trueFalse:
        case ReviewableContentType.fillInBlank:
        case ReviewableContentType.matching:
          final res = await _supabase
              .from('question_concepts')
              .select('concept_id, weight')
              .eq('question_id', contentId);
          for (final row in res as List) {
            results.add((
              conceptId: row['concept_id'] as String,
              weight: (row['weight'] as num?)?.toDouble() ?? 1.0,
            ));
          }
          break;

        case ReviewableContentType.flashcard:
          final res = await _supabase
              .from('flashcard_concepts')
              .select('concept_id, weight')
              .eq('flashcard_id', contentId);
          for (final row in res as List) {
            results.add((
              conceptId: row['concept_id'] as String,
              weight: (row['weight'] as num?)?.toDouble() ?? 1.0,
            ));
          }
          break;

        case ReviewableContentType.concept:
          results.add((conceptId: contentId, weight: 1.0));
          break;
      }

      // If no direct item mappings and lessonId exists, fallback to lesson concepts
      if (results.isEmpty && lessonId != null) {
        final lessonRes = await _supabase
            .from('lesson_concepts')
            .select('concept_id, weight')
            .eq('lesson_id', lessonId);
        for (final row in lessonRes as List) {
          results.add((
            conceptId: row['concept_id'] as String,
            weight: (row['weight'] as num?)?.toDouble() ?? 1.0,
          ));
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error querying concept mappings for $contentId: $e');
    }

    return results;
  }

  /// Get user concept states for a given set of concepts (or all concepts if null)
  Future<Map<String, UserConceptState>> getUserConceptStates(
    String userId, {
    List<String>? conceptIds,
  }) async {
    if (userId.isEmpty) return {};

    try {
      var query = _supabase.from('user_concept_state').select().eq('user_id', userId);

      if (conceptIds != null && conceptIds.isNotEmpty) {
        query = query.filter('concept_id', 'in', conceptIds);
      }

      final res = await query;
      final map = <String, UserConceptState>{};
      for (final row in res as List) {
        final state = UserConceptState.fromJson(row as Map<String, dynamic>);
        map[state.conceptId] = state;
      }
      return map;
    } catch (e) {
      debugPrint('⚠️ Error fetching user concept states: $e');
      return {};
    }
  }
}

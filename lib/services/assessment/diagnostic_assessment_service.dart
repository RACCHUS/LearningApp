import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../models/assessment/diagnostic_assessment.dart';
import '../../models/assessment_item.dart';
import '../../models/user_concept_state.dart';
import '../concept_evidence_service.dart';
import '../saved_study_set_service.dart';
import 'exam_evaluation_service.dart';

class DiagnosticUnavailableException implements Exception {
  final String message;
  const DiagnosticUnavailableException(this.message);

  @override
  String toString() => message;
}

/// Builds diagnostic pre-assessments exclusively from canonical, published
/// v2 assessment content.
///
/// Production diagnostics never invent questions. If a target version does not
/// have enough published assessment coverage, the feature fails closed and the
/// launch affordance stays hidden.
class DiagnosticAssessmentService {
  static const int defaultItemCount = 8;
  static const int minimumItemCount = 6;
  static const int minimumConceptCount = 3;

  final SupabaseClient _supabase;
  final ConceptEvidenceService _evidenceService;
  final SavedStudySetService _studySetService;
  final ExamEvaluationService _evaluationService;

  DiagnosticAssessmentService({
    SupabaseClient? supabase,
    ConceptEvidenceService? evidenceService,
    SavedStudySetService? studySetService,
    ExamEvaluationService? evaluationService,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _evidenceService = evidenceService ??
            ConceptEvidenceService(supabase: supabase),
        _studySetService =
            studySetService ?? SavedStudySetService(supabase: supabase),
        _evaluationService = evaluationService ?? ExamEvaluationService();

  Future<DiagnosticAvailability> getAvailability(
    String targetVersionId,
  ) async {
    final snapshot = await _loadCandidateSnapshot(targetVersionId);
    return DiagnosticAvailability(
      targetVersionId: targetVersionId,
      isPublishedVersion: snapshot.isPublishedVersion,
      availableItemCount: snapshot.items.length,
      representedConceptCount: snapshot.representedConceptIds.length,
      minimumItemCount: minimumItemCount,
      minimumConceptCount: minimumConceptCount,
    );
  }

  Future<List<DiagnosticAssessmentItem>> generatePreAssessment({
    required String targetVersionId,
    int itemCount = defaultItemCount,
  }) async {
    if (itemCount <= 0) {
      throw ArgumentError.value(itemCount, 'itemCount', 'Must be positive.');
    }

    final snapshot = await _loadCandidateSnapshot(targetVersionId);
    if (!snapshot.isPublishedVersion) {
      throw const DiagnosticUnavailableException(
        'Diagnostic pre-assessment is available only for published target versions.',
      );
    }
    if (snapshot.items.length < minimumItemCount ||
        snapshot.representedConceptIds.length < minimumConceptCount) {
      throw DiagnosticUnavailableException(
        'Not enough reviewed assessment coverage is available for this target yet.',
      );
    }

    return _selectRepresentativeItems(
      snapshot.items,
      math.min(itemCount, snapshot.items.length),
    );
  }

  Future<DiagnosticAssessmentReport> evaluateDiagnosticSession({
    required String userId,
    required String targetId,
    required String targetTitle,
    required String targetVersionId,
    required List<DiagnosticAssessmentItem> items,
    required List<DiagnosticAnswerSubmission> submissions,
  }) async {
    if (items.isEmpty) {
      throw StateError('Cannot evaluate an empty diagnostic assessment.');
    }

    final submissionByItem = {
      for (final submission in submissions) submission.itemId: submission,
    };
    if (submissionByItem.length != items.length ||
        items.any((entry) => !submissionByItem.containsKey(entry.item.id))) {
      throw StateError(
        'Diagnostic assessment must contain one response for every item.',
      );
    }

    int correct = 0;
    int partial = 0;
    double totalEarned = 0.0;
    bool evidencePersisted = userId.isNotEmpty;

    final conceptTotals = <String, _ConceptAccumulator>{};

    for (final entry in items) {
      final response = submissionByItem[entry.item.id]!.response;
      final score = _evaluationService.evaluateItemResponse(
        entry.item,
        response,
      );

      if (score.isCorrect) {
        correct++;
      } else if (score.isPartial) {
        partial++;
      }
      totalEarned += score.scoreEarned;

      for (final concept in entry.concepts) {
        final accumulator = conceptTotals.putIfAbsent(
          concept.conceptId,
          () => _ConceptAccumulator(
            conceptId: concept.conceptId,
            conceptName: concept.conceptName,
          ),
        );
        final weight = concept.weight.clamp(0.0, 1.0);
        accumulator.testedItemsCount++;
        accumulator.weightedPossible += weight;
        accumulator.weightedEarned += score.scoreEarned * weight;
      }

      if (userId.isNotEmpty) {
        final persisted = await _evidenceService.recordAssessmentItemEvidence(
          userId: userId,
          assessmentItemId: entry.item.id,
          evidenceValue: score.scoreEarned,
        );
        evidencePersisted = evidencePersisted && persisted;
      }
    }

    final conceptEvaluations = conceptTotals.values.map((accumulator) {
      final ratio = accumulator.weightedPossible > 0
          ? (accumulator.weightedEarned / accumulator.weightedPossible)
              .clamp(0.0, 1.0)
          : 0.0;

      final confidence = accumulator.testedItemsCount >= 5
          ? ConceptConfidence.high
          : accumulator.testedItemsCount >= 2
              ? ConceptConfidence.medium
              : ConceptConfidence.low;

      final band = _conceptEvidenceBand(
        ratio,
        accumulator.testedItemsCount,
      );

      return DiagnosticConceptEvaluation(
        conceptId: accumulator.conceptId,
        conceptName: accumulator.conceptName,
        testedItemsCount: accumulator.testedItemsCount,
        weightedEvidenceEarned: accumulator.weightedEarned,
        weightedEvidencePossible: accumulator.weightedPossible,
        evidenceRatio: ratio,
        evidenceBand: band,
        confidence: confidence,
        isReinforcementPriority:
            band == DiagnosticEvidenceBand.needsReinforcement,
      );
    }).toList()
      ..sort((a, b) => a.conceptName.compareTo(b.conceptName));

    final reinforcementPriorities = conceptEvaluations
        .where((evaluation) => evaluation.isReinforcementPriority)
        .toList()
      ..sort((a, b) => a.evidenceRatio.compareTo(b.evidenceRatio));

    final strongEvidenceConcepts = conceptEvaluations
        .where(
          (evaluation) =>
              evaluation.evidenceBand ==
              DiagnosticEvidenceBand.strongEvidence,
        )
        .toList();

    final overallScore = (totalEarned / items.length).clamp(0.0, 1.0);
    final overallBand = overallScore >= 0.85
        ? DiagnosticEvidenceBand.strongEvidence
        : overallScore >= 0.60
            ? DiagnosticEvidenceBand.developingEvidence
            : DiagnosticEvidenceBand.needsReinforcement;

    return DiagnosticAssessmentReport(
      id: const Uuid().v4(),
      targetId: targetId,
      targetTitle: targetTitle,
      targetVersionId: targetVersionId,
      completedAt: DateTime.now(),
      totalQuestions: items.length,
      correctQuestions: correct,
      partialQuestions: partial,
      overallEvidenceScore: overallScore,
      evidenceBand: overallBand,
      conceptEvaluations: conceptEvaluations,
      reinforcementPriorities: reinforcementPriorities,
      strongEvidenceConcepts: strongEvidenceConcepts,
      evidencePersisted: evidencePersisted,
    );
  }

  Future<DiagnosticAssessmentReport> generateRemedialStudySet({
    required DiagnosticAssessmentReport report,
  }) async {
    if (report.reinforcementPriorities.isEmpty) {
      throw StateError('No reinforcement priorities were identified.');
    }

    final conceptIds = report.reinforcementPriorities
        .map((gap) => gap.conceptId)
        .toSet()
        .toList();
    final title = '${report.targetTitle} — Diagnostic Reinforcement';

    final studySet = await _studySetService.createStudySet(
      title: title,
      description:
          'Created from diagnostic evidence for ${report.targetTitle}. '
          'Focuses on concepts that need reinforcement.',
      conceptIds: conceptIds,
      tags: const ['diagnostic', 'reinforcement'],
    );

    return report.copyWith(
      remedialSetCreated: true,
      remedialSetId: studySet.id,
      remedialSetTitle: studySet.title,
      remedialItemCount: conceptIds.length,
    );
  }

  Future<_CandidateSnapshot> _loadCandidateSnapshot(
    String targetVersionId,
  ) async {
    if (targetVersionId.isEmpty) {
      return const _CandidateSnapshot(
        isPublishedVersion: false,
        items: [],
        representedConceptIds: {},
      );
    }

    final version = await _supabase
        .from('target_versions')
        .select('id, status')
        .eq('id', targetVersionId)
        .maybeSingle();
    final isPublished = version != null && version['status'] == 'published';
    if (!isPublished) {
      return const _CandidateSnapshot(
        isPublishedVersion: false,
        items: [],
        representedConceptIds: {},
      );
    }

    final nodeRows = await _supabase
        .from('curriculum_nodes')
        .select('id')
        .eq('target_version_id', targetVersionId);
    final nodeIds = (nodeRows as List)
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .toList();
    if (nodeIds.isEmpty) {
      return const _CandidateSnapshot(
        isPublishedVersion: true,
        items: [],
        representedConceptIds: {},
      );
    }

    final nodeConceptRows = await _supabase
        .from('curriculum_node_concepts')
        .select('concept_id, weight, relevance')
        .inFilter('curriculum_node_id', nodeIds)
        .eq('relevance', 'core');

    final coreConceptWeights = <String, double>{};
    for (final row in nodeConceptRows as List) {
      final conceptId = row['concept_id']?.toString();
      if (conceptId == null || conceptId.isEmpty) continue;
      final weight = (row['weight'] as num?)?.toDouble() ?? 1.0;
      final current = coreConceptWeights[conceptId];
      if (current == null || weight > current) {
        coreConceptWeights[conceptId] = weight;
      }
    }
    if (coreConceptWeights.isEmpty) {
      return const _CandidateSnapshot(
        isPublishedVersion: true,
        items: [],
        representedConceptIds: {},
      );
    }

    final itemRows = await _supabase
        .from('assessment_items')
        .select('*, assessment_stimuli(*)')
        .eq('origin_target_version_id', targetVersionId);

    final assessmentItems = (itemRows as List)
        .map(
          (row) =>
              AssessmentItem.fromJson((row as Map).cast<String, dynamic>()),
        )
        .where(_isSupportedDiagnosticItem)
        .toList();

    if (assessmentItems.isEmpty) {
      return const _CandidateSnapshot(
        isPublishedVersion: true,
        items: [],
        representedConceptIds: {},
      );
    }

    final itemIds = assessmentItems.map((item) => item.id).toList();
    final itemConceptRows = await _supabase
        .from('assessment_item_concepts')
        .select('assessment_item_id, concept_id, role, weight')
        .inFilter('assessment_item_id', itemIds);

    final conceptIds = <String>{};
    final rawByItem = <String, List<Map<String, dynamic>>>{};
    for (final raw in itemConceptRows as List) {
      final row = (raw as Map).cast<String, dynamic>();
      final itemId = row['assessment_item_id']?.toString();
      final conceptId = row['concept_id']?.toString();
      if (itemId == null ||
          conceptId == null ||
          !coreConceptWeights.containsKey(conceptId)) {
        continue;
      }
      rawByItem.putIfAbsent(itemId, () => []).add(row);
      conceptIds.add(conceptId);
    }

    if (conceptIds.isEmpty) {
      return const _CandidateSnapshot(
        isPublishedVersion: true,
        items: [],
        representedConceptIds: {},
      );
    }

    final conceptRows = await _supabase
        .from('knowledge_concepts')
        .select('id, name')
        .inFilter('id', conceptIds.toList());
    final conceptNames = <String, String>{
      for (final raw in conceptRows as List)
        if (raw['id'] != null)
          raw['id'].toString():
              (raw['name']?.toString().trim().isNotEmpty ?? false)
                  ? raw['name'].toString()
                  : 'Concept',
    };

    final candidates = <DiagnosticAssessmentItem>[];
    final represented = <String>{};

    for (final item in assessmentItems) {
      final mappings = rawByItem[item.id] ?? const [];
      if (mappings.isEmpty) continue;

      final refs = mappings.map((row) {
        final conceptId = row['concept_id'].toString();
        represented.add(conceptId);
        final itemWeight = (row['weight'] as num?)?.toDouble() ?? 1.0;
        final targetWeight = coreConceptWeights[conceptId] ?? 1.0;
        return DiagnosticConceptRef(
          conceptId: conceptId,
          conceptName: conceptNames[conceptId] ?? 'Concept',
          role: row['role']?.toString() ?? 'primary',
          weight: (itemWeight * targetWeight).clamp(0.0, 1.0),
        );
      }).toList()
        ..sort((a, b) {
          if (a.role == b.role) return b.weight.compareTo(a.weight);
          if (a.role == 'primary') return -1;
          if (b.role == 'primary') return 1;
          return 0;
        });

      candidates.add(
        DiagnosticAssessmentItem(
          item: item,
          concepts: refs,
        ),
      );
    }

    candidates.sort((a, b) {
      final conceptCmp =
          a.primaryConcept.conceptName.compareTo(b.primaryConcept.conceptName);
      if (conceptCmp != 0) return conceptCmp;
      final difficultyCmp =
          _difficultyRank(a.item.difficulty).compareTo(
        _difficultyRank(b.item.difficulty),
      );
      if (difficultyCmp != 0) return difficultyCmp;
      return a.item.id.compareTo(b.item.id);
    });

    return _CandidateSnapshot(
      isPublishedVersion: true,
      items: candidates,
      representedConceptIds: represented,
    );
  }

  List<DiagnosticAssessmentItem> _selectRepresentativeItems(
    List<DiagnosticAssessmentItem> candidates,
    int count,
  ) {
    final buckets = <String, List<DiagnosticAssessmentItem>>{};
    for (final item in candidates) {
      buckets
          .putIfAbsent(item.primaryConcept.conceptId, () => [])
          .add(item);
    }

    final conceptIds = buckets.keys.toList()..sort();
    final selected = <DiagnosticAssessmentItem>[];
    final selectedIds = <String>{};

    while (selected.length < count) {
      var addedThisRound = false;
      for (final conceptId in conceptIds) {
        final bucket = buckets[conceptId]!;
        final next = bucket.cast<DiagnosticAssessmentItem?>().firstWhere(
              (item) => item != null && !selectedIds.contains(item.item.id),
              orElse: () => null,
            );
        if (next == null) continue;
        selected.add(next);
        selectedIds.add(next.item.id);
        addedThisRound = true;
        if (selected.length == count) break;
      }
      if (!addedThisRound) break;
    }

    return selected;
  }

  bool _isSupportedDiagnosticItem(AssessmentItem item) {
    final type = item.interactionType;
    final supported = type == AssessmentInteractionType.singleChoice ||
        type == AssessmentInteractionType.multiSelect;
    if (!supported) return false;

    switch (type) {
      case AssessmentInteractionType.singleChoice:
        final options = item.responseSpec['options'] as List?;
        final correct = item.scoringSpec['correct_index'];
        return options != null &&
            options.length >= 2 &&
            correct is num &&
            correct.toInt() >= 0 &&
            correct.toInt() < options.length;
      case AssessmentInteractionType.multiSelect:
        final options = item.responseSpec['options'] as List?;
        final correct = item.scoringSpec['correct_indices'] as List?;
        return options != null &&
            options.length >= 2 &&
            correct != null &&
            correct.isNotEmpty;
      case AssessmentInteractionType.orderedResponse:
        final values = item.responseSpec['items'] as List?;
        final order = item.scoringSpec['correct_order'] as List?;
        return values != null &&
            values.length >= 2 &&
            order != null &&
            order.length == values.length;
      case AssessmentInteractionType.matching:
        final pairs = item.scoringSpec['correct_pairs'] as Map?;
        return pairs != null && pairs.isNotEmpty;
      default:
        return false;
    }
  }

  DiagnosticEvidenceBand _conceptEvidenceBand(double ratio, int itemCount) {
    if (ratio >= 0.85 && itemCount >= 2) {
      return DiagnosticEvidenceBand.strongEvidence;
    }
    if (ratio >= 0.60) {
      return DiagnosticEvidenceBand.developingEvidence;
    }
    return DiagnosticEvidenceBand.needsReinforcement;
  }

  int _difficultyRank(String difficulty) => switch (difficulty.toLowerCase()) {
        'beginner' => 0,
        'intermediate' => 1,
        'advanced' => 2,
        _ => 1,
      };
}

class _ConceptAccumulator {
  final String conceptId;
  final String conceptName;
  int testedItemsCount = 0;
  double weightedEvidenceEarned = 0.0;
  double weightedEvidencePossible = 0.0;

  _ConceptAccumulator({
    required this.conceptId,
    required this.conceptName,
  });
}

class _CandidateSnapshot {
  final bool isPublishedVersion;
  final List<DiagnosticAssessmentItem> items;
  final Set<String> representedConceptIds;

  const _CandidateSnapshot({
    required this.isPublishedVersion,
    required this.items,
    required this.representedConceptIds,
  });
}

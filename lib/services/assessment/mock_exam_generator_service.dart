import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/assessment_engine/mock_exam_blueprint.dart';
import '../../models/assessment_engine/mock_exam_session.dart';
import '../../models/assessment_item.dart';
import 'exam_part_curriculum_scope.dart';

/// Generates practice-only sets from target curriculum constraints.
/// Official exam fidelity requires separate sourced validation (EXM-03).
class MockExamGeneratorService {
  final SupabaseClient _supabase;
  final Random _random;

  static const renderablePracticeTypes = <AssessmentInteractionType>{
    AssessmentInteractionType.singleChoice,
    AssessmentInteractionType.multiSelect,
    AssessmentInteractionType.orderedResponse,
    AssessmentInteractionType.matching,
  };

  MockExamGeneratorService({
    SupabaseClient? supabase,
    Random? random,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _random = random ?? Random();

  /// Loads curriculum-based practice constraints for a target version.
  Future<MockExamBlueprint> loadBlueprint(
    String targetVersionId, {
    String? examPartKey,
  }) async {
    final versionRes = await _supabase
        .from('target_versions')
        .select('id, version_code, title, metadata')
        .eq('id', targetVersionId)
        .maybeSingle();

    if (versionRes == null) {
      throw StateError('Target version not found: $targetVersionId');
    }

    // A requested part must resolve against THIS version's typed profile.
    // Invalid roots never silently expand to the whole target.
    final partScope = examPartKey == null
        ? null
        : await ExamPartCurriculumScopeResolver(client: _supabase).resolve(
            targetVersionId: targetVersionId,
            examPartKey: examPartKey,
          );

    final versionMeta =
        (versionRes['metadata'] as Map?)?.cast<String, dynamic>() ?? const {};
    final examCode = versionMeta['exam_code'] as String? ??
        versionRes['version_code'] as String? ??
        'EXAM';
    final title =
        versionRes['title'] as String? ?? 'Certification Practice Exam';
    // Legacy passing_score/scale and time_limit_minutes lack verified per-rule
    // provenance. Never promote them to official claims in practice mode.
    // 90 minutes is an explicitly practice-only fallback countdown.
    final configuredPracticeMinutes =
        (versionMeta['practice_time_limit_minutes'] as num?)?.toInt();
    final timeLimit = configuredPracticeMinutes != null && configuredPracticeMinutes > 0
        ? configuredPracticeMinutes
        : 90;
    final defaultQuestionCount =
        (versionMeta['default_question_count'] as num?)?.toInt() ?? 50;

    final difficultyDistributionRaw =
        (versionMeta['difficulty_distribution'] as Map?)
            ?.cast<String, dynamic>();
    final difficultyDistribution = difficultyDistributionRaw == null
        ? const <String, double>{
            'beginner': 0.20,
            'intermediate': 0.60,
            'advanced': 0.20,
          }
        : difficultyDistributionRaw.map(
            (key, value) => MapEntry(key, (value as num).toDouble()),
          );

    final allowedRaw = (versionMeta['allowed_interaction_types'] as List?)
        ?.map((value) => value.toString())
        .toSet();
    final allowedInteractionTypes = allowedRaw == null || allowedRaw.isEmpty
        ? const <AssessmentInteractionType>{
            AssessmentInteractionType.singleChoice,
            AssessmentInteractionType.multiSelect,
            AssessmentInteractionType.orderedResponse,
            AssessmentInteractionType.matching,
          }
        : AssessmentInteractionType.values
            .where((type) => allowedRaw.contains(type.toDbString()))
            .toSet()
            .intersection(renderablePracticeTypes);

    if (allowedInteractionTypes.isEmpty) {
      throw StateError(
        'Target version $targetVersionId declares no supported assessment interaction types.',
      );
    }

    final maxStimulusItemsRatio =
        ((versionMeta['max_stimulus_items_ratio'] as num?)?.toDouble() ?? 0.25)
            .clamp(0.0, 1.0);

    final domainNodesRes = await _supabase
        .from('curriculum_nodes')
        .select('id, code, title, weight, sort_order')
        .eq('target_version_id', targetVersionId)
        .eq('node_type', 'domain')
        .order('sort_order', ascending: true);

    final domainList = <DomainWeightConstraint>[];
    for (final row in (domainNodesRes as List? ?? [])) {
      if (partScope != null && !partScope.nodeIds.contains(row['id'])) {
        continue;
      }
      final weight = (row['weight'] as num?)?.toDouble() ?? 0.0;
      domainList.add(
        DomainWeightConstraint(
          domainId: row['id'] as String,
          domainCode: row['code'] as String? ?? '',
          domainTitle: row['title'] as String? ?? 'Domain',
          weight: weight,
        ),
      );
    }

    if (domainList.isEmpty) {
      throw StateError(
        'Target version $targetVersionId has no domain blueprint nodes.',
      );
    }

    // An entirely unweighted blueprint is treated uniformly. Mixed weighted /
    // unweighted domains keep their declared values and are normalized later.
    if (domainList.every((domain) => domain.weight <= 0.0)) {
      final uniformWeight = 1.0 / domainList.length;
      for (int i = 0; i < domainList.length; i++) {
        domainList[i] = DomainWeightConstraint(
          domainId: domainList[i].domainId,
          domainCode: domainList[i].domainCode,
          domainTitle: domainList[i].domainTitle,
          weight: uniformWeight,
        );
      }
    }

    return MockExamBlueprint(
      targetVersionId: targetVersionId,
      examPartKey: examPartKey,
      curriculumRootNodeId: partScope?.rootNodeId,
      examCode: examCode,
      title: title,
      timeLimitMinutes: timeLimit,
      officialPassingScore: null,
      officialScoreScale: null,
      defaultQuestionCount: defaultQuestionCount,
      domainWeights: domainList,
      difficultyDistribution: difficultyDistribution,
      allowedInteractionTypes: allowedInteractionTypes,
      maxStimulusItemsRatio: maxStimulusItemsRatio,
      metadata: versionMeta,
    );
  }

  /// Returns only a mapped, declared practice domain. Never guesses a domain.
  static String? validPracticeDomain(String? domainId, Set<String> allowedIds) {
    return domainId != null && allowedIds.contains(domainId) ? domainId : null;
  }

  /// Refuses partial sets instead of silently displaying a full-count practice exam.
  static void requireExactPracticeCount(int requestedCount, int actualCount) {
    if (requestedCount != actualCount) {
      throw StateError('Only $actualCount of $requestedCount requested practice items '
          'have valid domain mappings and satisfy selection constraints. '
          'Choose a smaller practice set or add reviewed items.');
    }
  }

  /// Generates a mock exam constrained by domain weights, allowed interaction
  /// formats, difficulty distribution, and the configured shared-stimulus cap.
  Future<MockExamSession> generateExamSession({
    required String targetVersionId,
    int? questionCount,
    String? examPartKey,
    MockExamBlueprint? preloadedBlueprint,
  }) async {
    final blueprint = preloadedBlueprint ??
        await loadBlueprint(targetVersionId, examPartKey: examPartKey);
    if (blueprint.targetVersionId != targetVersionId ||
        blueprint.examPartKey != examPartKey ||
        (examPartKey != null && blueprint.curriculumRootNodeId == null)) {
      throw StateError('Preloaded exam blueprint does not match requested part.');
    }
    if (preloadedBlueprint != null && examPartKey != null) {
      final verified = await ExamPartCurriculumScopeResolver(client: _supabase)
          .resolve(targetVersionId: targetVersionId, examPartKey: examPartKey);
      if (blueprint.curriculumRootNodeId != verified.rootNodeId ||
          blueprint.domainWeights.isEmpty ||
          blueprint.domainWeights.any(
            (domain) => !verified.nodeIds.contains(domain.domainId),
          )) {
        throw StateError('Preloaded exam blueprint is outside selected part.');
      }
    }
    final totalQuestions = questionCount ?? blueprint.defaultQuestionCount;
    if (totalQuestions <= 0) {
      throw ArgumentError.value(
        totalQuestions,
        'questionCount',
        'Question count must be positive.',
      );
    }
    if (blueprint.domainWeights.isEmpty) {
      throw StateError('Cannot generate an exam without domain weights.');
    }

    final domainQuotas = blueprint.computeDomainQuotas(totalQuestions);

    final itemsRes = await _supabase
        .from('assessment_items')
        .select('*, assessment_stimuli(*)')
        .eq('origin_target_version_id', targetVersionId);

    final allItems = (itemsRes as List? ?? [])
        .map(
          (row) =>
              AssessmentItem.fromJson((row as Map).cast<String, dynamic>()),
        )
        .where(
          (item) =>
              blueprint.allowedInteractionTypes.contains(item.interactionType) &&
              renderablePracticeTypes.contains(item.interactionType),
        )
        .toList();

    if (allItems.isEmpty) {
      throw StateError(
        'No assessment items satisfy the blueprint interaction constraints.',
      );
    }

    final domainItemsMap = <String, List<AssessmentItem>>{};
    final itemDomainMap = <String, String>{};
    final itemConceptMap = <String, List<String>>{};

    for (final domain in blueprint.domainWeights) {
      domainItemsMap[domain.domainId] = [];
    }

    final objectiveNodesRes = await _supabase
        .from('curriculum_nodes')
        .select('id, parent_id, code')
        .eq('target_version_id', targetVersionId)
        .eq('node_type', 'objective');

    final objectiveToDomain = <String, String>{};
    for (final obj in (objectiveNodesRes as List? ?? [])) {
      final parentId = obj['parent_id'] as String?;
      if (parentId != null) {
        objectiveToDomain[obj['id'] as String] = parentId;
      }
    }

    final objectiveIds = objectiveToDomain.keys.toList();
    final conceptToDomain = <String, String>{};
    final ambiguousConceptIds = <String>{};
    if (objectiveIds.isNotEmpty) {
      final objectiveConceptsRes = await _supabase
          .from('curriculum_node_concepts')
          .select('concept_id, curriculum_node_id')
          .inFilter('curriculum_node_id', objectiveIds);

      for (final row in (objectiveConceptsRes as List? ?? [])) {
        final conceptId = row['concept_id'] as String;
        final objectiveId = row['curriculum_node_id'] as String;
        final domainId = objectiveToDomain[objectiveId];
        if (domainId != null && !ambiguousConceptIds.contains(conceptId)) {
          final previousDomain = conceptToDomain[conceptId];
          if (previousDomain != null && previousDomain != domainId) {
            conceptToDomain.remove(conceptId);
            ambiguousConceptIds.add(conceptId);
          } else {
            conceptToDomain[conceptId] = domainId;
          }
        }
      }
    }

    final ambiguousItemIds = <String>{};
    final itemIds = allItems.map((item) => item.id).toList();
    if (itemIds.isNotEmpty) {
      final itemConceptsRes = await _supabase
          .from('assessment_item_concepts')
          .select('assessment_item_id, concept_id')
          .inFilter('assessment_item_id', itemIds);

      for (final row in (itemConceptsRes as List? ?? [])) {
        final itemId = row['assessment_item_id'] as String;
        final conceptId = row['concept_id'] as String;
        itemConceptMap.putIfAbsent(itemId, () => []).add(conceptId);

        final domainId = conceptToDomain[conceptId];
        if (domainId == null || ambiguousItemIds.contains(itemId)) continue;
        final previousDomain = itemDomainMap[itemId];
        if (previousDomain != null && previousDomain != domainId) {
          itemDomainMap.remove(itemId);
          ambiguousItemIds.add(itemId);
        } else {
          itemDomainMap[itemId] = domainId;
        }
      }
    }

    // Exclude unmapped and ambiguous items rather than silently borrowing the
    // highest-weight domain or fabricating domain evidence.
    final validDomainIds = domainItemsMap.keys.toSet();
    for (final item in allItems) {
      final domainId = validPracticeDomain(itemDomainMap[item.id], validDomainIds);
      if (domainId == null) continue;
      domainItemsMap[domainId]!.add(item);
    }

    final selectedItems = <AssessmentItem>[];
    final selectedIds = <String>{};
    final maxStimulusItems =
        (totalQuestions * blueprint.maxStimulusItemsRatio).floor();
    int selectedStimulusItems = 0;

    bool hasStimulus(AssessmentItem item) =>
        item.stimulusId != null || item.stimulus != null;

    bool canSelect(AssessmentItem item) {
      if (selectedIds.contains(item.id)) return false;
      if (hasStimulus(item) && selectedStimulusItems >= maxStimulusItems) {
        return false;
      }
      return true;
    }

    void selectItem(AssessmentItem item) {
      selectedItems.add(item);
      selectedIds.add(item.id);
      if (hasStimulus(item)) selectedStimulusItems++;
    }

    for (final domain in blueprint.domainWeights) {
      final quota = domainQuotas[domain.domainId] ?? 0;
      if (quota <= 0) continue;

      final available =
          List<AssessmentItem>.from(domainItemsMap[domain.domainId] ?? const [])
            ..shuffle(_random);
      final difficultyQuotas = blueprint.computeDifficultyQuotas(quota);

      for (final difficultyEntry in difficultyQuotas.entries) {
        var needed = difficultyEntry.value;
        for (final item in available) {
          if (needed <= 0) break;
          if (!canSelect(item)) continue;
          if (item.difficulty.toLowerCase() !=
              difficultyEntry.key.toLowerCase()) {
            continue;
          }
          selectItem(item);
          needed--;
        }
      }

      final domainSelected = selectedItems
          .where((item) => itemDomainMap[item.id] == domain.domainId)
          .length;
      var remainingForDomain = quota - domainSelected;
      if (remainingForDomain > 0) {
        for (final item in available) {
          if (remainingForDomain <= 0) break;
          if (!canSelect(item)) continue;
          selectItem(item);
          remainingForDomain--;
        }
      }
    }

    // Rebalance domain shortages while preferentially filling global difficulty
    // deficits. The stimulus cap remains a hard constraint.
    var remainingShortfall = totalQuestions - selectedItems.length;
    if (remainingShortfall > 0) {
      final desiredDifficulty =
          blueprint.computeDifficultyQuotas(totalQuestions);
      final currentDifficulty = <String, int>{};
      for (final item in selectedItems) {
        final key = item.difficulty.toLowerCase();
        currentDifficulty[key] = (currentDifficulty[key] ?? 0) + 1;
      }

      final spareItems =
          allItems.where((item) =>
              validPracticeDomain(itemDomainMap[item.id], validDomainIds) != null &&
              !selectedIds.contains(item.id)).toList()
            ..shuffle(_random);

      for (final entry in desiredDifficulty.entries) {
        var needed =
            entry.value - (currentDifficulty[entry.key.toLowerCase()] ?? 0);
        if (needed <= 0) continue;

        for (final item in spareItems) {
          if (remainingShortfall <= 0 || needed <= 0) break;
          if (!canSelect(item)) continue;
          if (item.difficulty.toLowerCase() != entry.key.toLowerCase()) {
            continue;
          }
          selectItem(item);
          remainingShortfall--;
          needed--;
        }
      }

      if (remainingShortfall > 0) {
        for (final item in spareItems) {
          if (remainingShortfall <= 0) break;
          if (!canSelect(item)) continue;
          selectItem(item);
          remainingShortfall--;
        }
      }
    }

    requireExactPracticeCount(totalQuestions, selectedItems.length);
    selectedItems.shuffle(_random);

    final finalItemDomainMap = <String, String>{};
    for (final item in selectedItems) {
      final domainId = validPracticeDomain(itemDomainMap[item.id], validDomainIds);
      if (domainId == null) {
        throw StateError('Practice item ${item.id} has no validated domain mapping.');
      }
      final domain = blueprint.domainWeights.firstWhere(
        (candidate) => candidate.domainId == domainId,
      );
      finalItemDomainMap[item.id] = domain.domainCode;
    }

    final selectedConceptMap = <String, List<String>>{
      for (final item in selectedItems)
        item.id: itemConceptMap[item.id] ?? const <String>[],
    };

    final sessionId =
        'exam_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(99999)}';

    return MockExamSession(
      id: sessionId,
      blueprint: blueprint,
      items: selectedItems,
      itemDomainMap: finalItemDomainMap,
      itemConceptMap: selectedConceptMap,
      startedAt: DateTime.now(),
      timeLimit: blueprint.timeLimit,
      status: ExamSessionStatus.inProgress,
    );
  }
}

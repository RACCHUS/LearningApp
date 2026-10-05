import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/assessment_engine/mock_exam_blueprint.dart';
import '../../models/assessment_engine/mock_exam_session.dart';
import '../../models/assessment_item.dart';

/// Generates mock examination sessions governed by authoritative blueprint constraints.
class MockExamGeneratorService {
  final SupabaseClient _supabase;
  final Random _random;

  MockExamGeneratorService({
    SupabaseClient? supabase,
    Random? random,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _random = random ?? Random();

  /// Loads the official blueprint constraint model for a given target version.
  Future<MockExamBlueprint> loadBlueprint(String targetVersionId) async {
    // 1. Fetch target version record
    final versionRes = await _supabase
        .from('target_versions')
        .select('id, version_code, title, metadata')
        .eq('id', targetVersionId)
        .maybeSingle();

    final versionMeta = (versionRes?['metadata'] as Map?)?.cast<String, dynamic>() ?? {};
    final examCode = versionMeta['exam_code'] as String? ?? versionRes?['version_code'] as String? ?? 'EXAM';
    final title = versionRes?['title'] as String? ?? 'Certification Practice Exam';
    final passingScore = (versionMeta['passing_score'] as num?)?.toInt() ?? 750;
    final scale = versionMeta['scale'] as String? ?? '100-900';
    final timeLimit = (versionMeta['time_limit_minutes'] as num?)?.toInt() ?? 90;

    // 2. Fetch domain curriculum nodes with their weights
    final domainNodesRes = await _supabase
        .from('curriculum_nodes')
        .select('id, code, title, weight, sort_order')
        .eq('target_version_id', targetVersionId)
        .eq('node_type', 'domain')
        .order('sort_order', ascending: true);

    final domainList = <DomainWeightConstraint>[];
    for (final row in (domainNodesRes as List? ?? [])) {
      final w = (row['weight'] as num?)?.toDouble() ?? 0.0;
      domainList.add(DomainWeightConstraint(
        domainId: row['id'] as String,
        domainCode: row['code'] as String? ?? '',
        domainTitle: row['title'] as String? ?? 'Domain',
        weight: w,
      ));
    }

    // Fallback: If no weights declared, distribute uniformly
    if (domainList.isNotEmpty && domainList.every((d) => d.weight <= 0.0)) {
      final uniformW = 1.0 / domainList.length;
      for (int i = 0; i < domainList.length; i++) {
        domainList[i] = DomainWeightConstraint(
          domainId: domainList[i].domainId,
          domainCode: domainList[i].domainCode,
          domainTitle: domainList[i].domainTitle,
          weight: uniformW,
        );
      }
    }

    return MockExamBlueprint(
      targetVersionId: targetVersionId,
      examCode: examCode,
      title: title,
      timeLimitMinutes: timeLimit,
      officialPassingScore: passingScore,
      officialScoreScale: scale,
      domainWeights: domainList,
      metadata: versionMeta,
    );
  }

  /// Generates a complete mock exam session conforming to blueprint weights and difficulty distributions.
  Future<MockExamSession> generateExamSession({
    required String targetVersionId,
    int? questionCount,
    MockExamBlueprint? preloadedBlueprint,
  }) async {
    final blueprint = preloadedBlueprint ?? await loadBlueprint(targetVersionId);
    final totalQuestions = questionCount ?? blueprint.defaultQuestionCount;
    final domainQuotas = blueprint.computeDomainQuotas(totalQuestions);

    // 1. Fetch all eligible assessment items for this target version
    final itemsRes = await _supabase
        .from('assessment_items')
        .select('*, assessment_stimuli(*)')
        .eq('origin_target_version_id', targetVersionId);

    final allItems = (itemsRes as List? ?? [])
        .map((row) => AssessmentItem.fromJson((row as Map).cast<String, dynamic>()))
        .toList();

    // 2. Fetch item-to-domain mapping through objectives & concepts
    // Objective nodes -> Concepts -> Assessment Items
    final domainItemsMap = <String, List<AssessmentItem>>{};
    final itemDomainMap = <String, String>{};
    final itemConceptMap = <String, List<String>>{};

    for (final domain in blueprint.domainWeights) {
      domainItemsMap[domain.domainId] = [];
    }

    // Build lookup for curriculum structure
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

    // Fetch objective concepts
    final objIds = objectiveToDomain.keys.toList();
    final conceptToDomain = <String, String>{};
    if (objIds.isNotEmpty) {
      final objConceptsRes = await _supabase
          .from('curriculum_node_concepts')
          .select('concept_id, curriculum_node_id')
          .filter('curriculum_node_id', 'in', objIds);

      for (final row in (objConceptsRes as List? ?? [])) {
        final cid = row['concept_id'] as String;
        final objId = row['curriculum_node_id'] as String;
        final domainId = objectiveToDomain[objId];
        if (domainId != null) {
          conceptToDomain[cid] = domainId;
        }
      }
    }

    // Fetch item concepts
    final itemIds = allItems.map((i) => i.id).toList();
    if (itemIds.isNotEmpty) {
      final itemConceptsRes = await _supabase
          .from('assessment_item_concepts')
          .select('assessment_item_id, concept_id')
          .filter('assessment_item_id', 'in', itemIds);

      for (final row in (itemConceptsRes as List? ?? [])) {
        final iid = row['assessment_item_id'] as String;
        final cid = row['concept_id'] as String;
        itemConceptMap.putIfAbsent(iid, () => []).add(cid);

        if (!itemDomainMap.containsKey(iid) && conceptToDomain.containsKey(cid)) {
          final domainId = conceptToDomain[cid]!;
          itemDomainMap[iid] = domainId;
        }
      }
    }

    // Categorize items into domain buckets
    for (final item in allItems) {
      var domainId = itemDomainMap[item.id];
      if (domainId == null || !domainItemsMap.containsKey(domainId)) {
        // Fallback: assign to the domain with the highest weight
        domainId = blueprint.domainWeights.isNotEmpty ? blueprint.domainWeights.first.domainId : 'default';
        itemDomainMap[item.id] = domainId;
      }
      domainItemsMap.putIfAbsent(domainId, () => []).add(item);
    }

    // 3. Constraint-based sampling with graceful deficit rebalancing
    final selectedItems = <AssessmentItem>[];
    int remainingShortfall = 0;

    for (final domain in blueprint.domainWeights) {
      final quota = domainQuotas[domain.domainId] ?? 0;
      final available = domainItemsMap[domain.domainId] ?? [];
      available.shuffle(_random);

      if (available.length <= quota) {
        selectedItems.addAll(available);
        remainingShortfall += (quota - available.length);
      } else {
        selectedItems.addAll(available.take(quota));
      }
    }

    // Rebalance shortfall if any domain lacked items
    if (remainingShortfall > 0) {
      final alreadySelectedIds = selectedItems.map((i) => i.id).toSet();
      final spareItems = allItems.where((i) => !alreadySelectedIds.contains(i.id)).toList();
      spareItems.shuffle(_random);
      selectedItems.addAll(spareItems.take(remainingShortfall));
    }

    // Randomize final presentation sequence
    selectedItems.shuffle(_random);

    // Map domain codes for selected items
    final finalItemDomainMap = <String, String>{};
    for (final item in selectedItems) {
      final dId = itemDomainMap[item.id];
      final domain = blueprint.domainWeights.firstWhere(
        (d) => d.domainId == dId,
        orElse: () => blueprint.domainWeights.first,
      );
      finalItemDomainMap[item.id] = domain.domainCode;
    }

    final sessionId = 'exam_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(99999)}';

    return MockExamSession(
      id: sessionId,
      blueprint: blueprint,
      items: selectedItems,
      itemDomainMap: finalItemDomainMap,
      itemConceptMap: itemConceptMap,
      startedAt: DateTime.now(),
      timeLimit: blueprint.timeLimit,
      status: ExamSessionStatus.inProgress,
    );
  }
}

import '../../models/fast_plan_result.dart';
import '../../models/learning_strategy.dart';
import '../../models/overview_outline.dart';
import '../../models/scope.dart';

/// Exception thrown when any client-side coverage or planner call attempts to
/// inspect protected `simulation_only` items or answer keys (`SAFE-01`).
class ProtectedSimulationBankAccessException implements Exception {
  final String message;
  final String? offendingItemId;

  const ProtectedSimulationBankAccessException(
    this.message, {
    this.offendingItemId,
  });

  @override
  String toString() =>
      'ProtectedSimulationBankAccessException: $message'
      '${offendingItemId != null ? ' (item: $offendingItemId)' : ''}';
}

/// Result of resolving curriculum and blueprint coverage for a [ResolvedScope].
class ScopeCoverageBundle {
  final List<OfficialDomainBlueprint> officialDomains;
  final Map<String, CoverageRecord> recordsByActivityId;
  final List<String> unmappedActivityIds;

  const ScopeCoverageBundle({
    required this.officialDomains,
    required this.recordsByActivityId,
    required this.unmappedActivityIds,
  });
}

/// Read-only service that maps [ScopedLearningActivity] candidates to official
/// blueprint domains, concepts, and prerequisites (`TEL-02B`, `SAFE-01`).
class ContentCoverageService {
  const ContentCoverageService();

  /// Canonical CLEP Introductory Psychology lesson-to-domain mappings derived
  /// from `content/clep_introductory_psychology.yaml`.
  static const Map<String, List<String>> _clepPsychSlugOrTitleDomains = {
    'history-and-approaches': ['1.0'],
    'history and approaches': ['1.0'],
    'research-methods': ['1.0', '13.0'],
    'research methods': ['1.0', '13.0'],
    'statistics-and-ethics': ['13.0', '1.0'],
    'statistics, tests, and measurements': ['13.0'],
    'statistics and ethics': ['13.0', '1.0'],
    'neurons-and-neurotransmitters': ['2.0'],
    'neurons and neurotransmitters': ['2.0'],
    'brain-structure-and-function': ['2.0'],
    'brain structure and function': ['2.0'],
    'biological bases of behavior': ['2.0'],
    'sensation-and-perception': ['3.0'],
    'sensation and perception': ['3.0'],
    'states-of-consciousness': ['4.0'],
    'states of consciousness': ['4.0'],
    'classical-conditioning': ['5.0'],
    'classical conditioning': ['5.0'],
    'operant-and-observational-learning': ['5.0'],
    'operant and observational learning': ['5.0'],
    'learning': ['5.0'],
    'memory': ['6.0'],
    'thinking-language-and-intelligence': ['6.0', '13.0'],
    'thinking, language, and intelligence': ['6.0', '13.0'],
    'cognition': ['6.0'],
    'motivation': ['7.0'],
    'emotion-and-stress': ['7.0'],
    'emotion and stress': ['7.0'],
    'motivation and emotion': ['7.0'],
    'lifespan-development-early': ['8.0'],
    'lifespan development: early': ['8.0'],
    'lifespan-development-adolescence-adulthood': ['8.0'],
    'lifespan development: adolescence and adulthood': ['8.0'],
    'developmental psychology': ['8.0'],
    'personality-theories': ['9.0'],
    'personality theories': ['9.0'],
    'personality': ['9.0'],
    'psychological-disorders-part-1': ['10.0'],
    'psychological disorders (part 1)': ['10.0'],
    'psychological-disorders-part-2': ['10.0'],
    'psychological disorders (part 2)': ['10.0'],
    'psychological disorders': ['10.0'],
    'treatment-of-psychological-disorders': ['11.0'],
    'treatment of psychological disorders': ['11.0'],
    'social-thinking-and-influence': ['12.0'],
    'social thinking and influence': ['12.0'],
    'social-relations-and-group-behavior': ['12.0'],
    'social relations and group behavior': ['12.0'],
    'social psychology': ['12.0'],
  };

  /// Enforces the `SAFE-01` security boundary: client-side coverage and planning
  /// must never inspect `simulation_only` items, protected stems, or scoring keys.
  void validateAssessmentItemMetadata(
    Iterable<Map<String, dynamic>> itemMetadataRows,
  ) {
    for (final row in itemMetadataRows) {
      final itemId = row['id']?.toString() ?? row['slug']?.toString();
      final deliveryMode = row['delivery_mode']?.toString().toLowerCase();
      if (deliveryMode == 'simulation_only') {
        throw ProtectedSimulationBankAccessException(
          'Client-side coverage/planner cannot read simulation_only assessment items.',
          offendingItemId: itemId,
        );
      }
      if (row.containsKey('correct_answer') ||
          row.containsKey('answer_key') ||
          row.containsKey('simulation_stem') ||
          row.containsKey('protected_options')) {
        throw ProtectedSimulationBankAccessException(
          'Client-side coverage/planner cannot inspect protected scoring keys or stems.',
          offendingItemId: itemId,
        );
      }
    }
  }

  /// Builds deterministic [CoverageRecord] mappings for all activities in [scope].
  ScopeCoverageBundle buildCoverageForScope({
    required ResolvedScope scope,
    List<OfficialDomainBlueprint> officialDomains =
        clepPsychologyOfficialDomains,
    List<SnapshotNode> curriculumNodes = const [],
    Map<String, List<String>> explicitActivityDomains = const {},
    Map<String, List<String>> explicitActivityPrerequisites = const {},
    Map<String, DepthTier> explicitActivityDepthTiers = const {},
    Map<String, int> formativeItemCountsByActivity = const {},
    Iterable<Map<String, dynamic>>? rawAssessmentMetadataToValidate,
  }) {
    if (rawAssessmentMetadataToValidate != null) {
      validateAssessmentItemMetadata(rawAssessmentMetadataToValidate);
    }

    final domainById = {
      for (final domain in officialDomains) domain.domainId: domain,
    };

    final nodeById = {
      for (final node in curriculumNodes) node.id: node,
    };

    final recordsByActivityId = <String, CoverageRecord>{};
    final unmappedActivityIds = <String>[];

    for (var i = 0; i < scope.orderedActivities.length; i++) {
      final activity = scope.orderedActivities[i];
      final candidateDomains = <String>{};

      // 1. Explicit domain overrides (used in tests and custom target manifests)
      final explicit = explicitActivityDomains[activity.activityId];
      if (explicit != null && explicit.isNotEmpty) {
        candidateDomains.addAll(explicit.where(domainById.containsKey));
      }

      // 2. Snapshot curriculum node code (e.g. '1.0'..'13.0')
      if (candidateDomains.isEmpty && activity.curriculumNodeId != null) {
        final nodeId = activity.curriculumNodeId!;
        if (domainById.containsKey(nodeId)) {
          candidateDomains.add(nodeId);
        } else {
          final resolvedDomain = _resolveDomainFromNode(
            nodeId,
            nodeById,
            domainById,
          );
          if (resolvedDomain != null) {
            candidateDomains.add(resolvedDomain);
          }
        }
      }

      // 3. Canonical slug/title lookup for CLEP Psychology
      if (candidateDomains.isEmpty) {
        final normalizedId = activity.activityId.trim().toLowerCase();
        final normalizedTitle = activity.title.trim().toLowerCase();
        if (_clepPsychSlugOrTitleDomains.containsKey(normalizedId)) {
          candidateDomains.addAll(
            _clepPsychSlugOrTitleDomains[normalizedId]!.where(
              domainById.containsKey,
            ),
          );
        } else if (_clepPsychSlugOrTitleDomains.containsKey(normalizedTitle)) {
          candidateDomains.addAll(
            _clepPsychSlugOrTitleDomains[normalizedTitle]!.where(
              domainById.containsKey,
            ),
          );
        } else {
          for (final entry in _clepPsychSlugOrTitleDomains.entries) {
            if (normalizedTitle.contains(entry.key) ||
                normalizedId.contains(entry.key)) {
              candidateDomains.addAll(
                entry.value.where(domainById.containsKey),
              );
              break;
            }
          }
        }
      }

      // Sort mapped domains by descending normalizedModelWeight, then lexicographic domainId
      final sortedDomains = candidateDomains.toList()
        ..sort((a, b) {
          final da = domainById[a]!;
          final db = domainById[b]!;
          final weightCmp = db.normalizedModelWeight.compareTo(
            da.normalizedModelWeight,
          );
          if (weightCmp != 0) return weightCmp;
          return a.compareTo(b);
        });

      final String? primaryDomainId = sortedDomains.isNotEmpty
          ? sortedDomains.first
          : null;
      final OfficialDomainBlueprint? primaryDomain = primaryDomainId != null
          ? domainById[primaryDomainId]
          : null;
      final secondaryDomains = sortedDomains.length > 1
          ? sortedDomains.sublist(1)
          : const <String>[];

      final isUnmapped = primaryDomainId == null;
      if (isUnmapped) {
        unmappedActivityIds.add(activity.activityId);
      }

      final depthTier =
          explicitActivityDepthTiers[activity.activityId] ??
          _depthTierFromScopeRole(activity.role);

      final prereqs =
          explicitActivityPrerequisites[activity.activityId] ??
          const <String>[];

      recordsByActivityId[activity.activityId] = CoverageRecord(
        activityId: activity.activityId,
        activityTitle: activity.title,
        activitySlug: activity.activityId,
        canonicalOrderIndex: i,
        estimatedMinutes: activity.estimatedMinutes,
        estimateQuality: activity.estimateQuality,
        primaryDepthTier: depthTier,
        primaryDomainId: primaryDomainId,
        primaryDomainTitle: primaryDomain?.title,
        primaryDomainNormalizedWeight:
            primaryDomain?.normalizedModelWeight ?? 0.0,
        secondaryDomainIds: List<String>.unmodifiable(secondaryDomains),
        allDomainIds: List<String>.unmodifiable(sortedDomains),
        prerequisiteActivityIds: List<String>.unmodifiable(prereqs),
        formativeItemCount:
            formativeItemCountsByActivity[activity.activityId] ?? 0,
        unmappedOrAmbiguous: isUnmapped,
      );
    }

    return ScopeCoverageBundle(
      officialDomains: officialDomains,
      recordsByActivityId: Map<String, CoverageRecord>.unmodifiable(
        recordsByActivityId,
      ),
      unmappedActivityIds: List<String>.unmodifiable(unmappedActivityIds),
    );
  }

  String? _resolveDomainFromNode(
    String startNodeId,
    Map<String, SnapshotNode> nodeById,
    Map<String, OfficialDomainBlueprint> domainById,
  ) {
    final visited = <String>{};
    String? currentId = startNodeId;
    while (currentId != null && !visited.contains(currentId)) {
      visited.add(currentId);
      final node = nodeById[currentId];
      if (node == null) break;
      final code = node.code?.trim();
      if (code != null && domainById.containsKey(code)) {
        return code;
      }
      if (domainById.containsKey(node.id)) {
        return node.id;
      }
      currentId = node.parentId;
    }
    return null;
  }

  DepthTier _depthTierFromScopeRole(ScopeRole role) {
    switch (role) {
      case ScopeRole.core:
        return DepthTier.core;
      case ScopeRole.supporting:
        return DepthTier.support;
      case ScopeRole.related:
        return DepthTier.enrichment;
    }
  }
}

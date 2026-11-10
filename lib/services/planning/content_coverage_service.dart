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
  /// from `content/clep_introductory_psychology.yaml` (all 25 authored lessons + slugs).
  static const Map<String, List<String>> _clepPsychSlugOrTitleDomains = {
    // Domain 1.0: History, Approaches, and Methods
    'historical foundations and modern perspectives in psychology': ['1.0'],
    'historical-foundations-and-modern-perspectives-in-psychology': ['1.0'],
    'history-and-approaches': ['1.0'],
    'history and approaches': ['1.0'],
    'scientific methods: experiments, correlations, and ethical standards': [
      '1.0',
      '13.0',
    ],
    'scientific-methods-experiments-correlations-and-ethical-standards': [
      '1.0',
      '13.0',
    ],
    'research-methods': ['1.0', '13.0'],
    'research methods': ['1.0', '13.0'],
    'statistics-and-ethics': ['13.0', '1.0'],
    'statistics and ethics': ['13.0', '1.0'],

    // Domain 2.0: Biological Bases of Behavior
    'the neuron and electrochemical communication': ['2.0'],
    'the-neuron-and-electrochemical-communication': ['2.0'],
    'neurons-and-neurotransmitters': ['2.0'],
    'neurons and neurotransmitters': ['2.0'],
    'brain architecture and hemispheric specialization': ['2.0'],
    'brain-architecture-and-hemispheric-specialization': ['2.0'],
    'brain-structure-and-function': ['2.0'],
    'brain structure and function': ['2.0'],
    'biological bases of behavior': ['2.0'],

    // Domain 3.0: Sensation and Perception
    'sensory reception, transduction, and thresholds': ['3.0'],
    'sensory-reception-transduction-and-thresholds': ['3.0'],
    'visual anatomy, color theories, and perceptual organization': ['3.0'],
    'visual-anatomy-color-theories-and-perceptual-organization': ['3.0'],
    'sensation-and-perception': ['3.0'],
    'sensation and perception': ['3.0'],

    // Domain 4.0: States of Consciousness
    'sleep architecture and biological rhythms': ['4.0'],
    'sleep-architecture-and-biological-rhythms': ['4.0'],
    'sleep disorders, theories of dreaming, and psychoactive drugs': ['4.0'],
    'sleep-disorders-theories-of-dreaming-and-psychoactive-drugs': ['4.0'],
    'states-of-consciousness': ['4.0'],
    'states of consciousness': ['4.0'],

    // Domain 5.0: Learning
    'classical conditioning: principles and extinction': ['5.0'],
    'classical-conditioning-principles-and-extinction': ['5.0'],
    'classical-conditioning': ['5.0'],
    'classical conditioning': ['5.0'],
    'operant conditioning: reinforcement, schedules, and observational learning':
        ['5.0'],
    'operant-conditioning-reinforcement-schedules-and-observational-learning': [
      '5.0',
    ],
    'operant-and-observational-learning': ['5.0'],
    'operant and observational learning': ['5.0'],
    'learning': ['5.0'],

    // Domain 6.0: Cognition
    'memory systems: encoding, storage, and retrieval': ['6.0'],
    'memory-systems-encoding-storage-and-retrieval': ['6.0'],
    'memory': ['6.0'],
    'problem solving, cognitive biases, and language acquisition': [
      '6.0',
      '13.0',
    ],
    'problem-solving-cognitive-biases-and-language-acquisition': [
      '6.0',
      '13.0',
    ],
    'thinking-language-and-intelligence': ['6.0', '13.0'],
    'thinking, language, and intelligence': ['6.0', '13.0'],
    'cognition': ['6.0'],

    // Domain 7.0: Motivation and Emotion
    'theories of motivation and motivational drives': ['7.0'],
    'theories-of-motivation-and-motivational-drives': ['7.0'],
    'motivation': ['7.0'],
    "theories of emotion, stress, and selye's gas": ['7.0'],
    'theories-of-emotion-stress-and-selyes-gas': ['7.0'],
    'emotion-and-stress': ['7.0'],
    'emotion and stress': ['7.0'],
    'motivation and emotion': ['7.0'],

    // Domain 8.0: Developmental Psychology Across the Lifespan
    'cognitive and motor development across childhood': ['8.0'],
    'cognitive-and-motor-development-across-childhood': ['8.0'],
    'lifespan-development-early': ['8.0'],
    'lifespan development: early': ['8.0'],
    'attachment, parenting styles, and psychosocial moral development': ['8.0'],
    'attachment-parenting-styles-and-psychosocial-moral-development': ['8.0'],
    'lifespan-development-adolescence-adulthood': ['8.0'],
    'lifespan development: adolescence and adulthood': ['8.0'],
    'developmental psychology': ['8.0'],
    'developmental psychology across the lifespan': ['8.0'],

    // Domain 9.0: Personality
    'psychodynamic and humanistic perspectives on personality': ['9.0'],
    'psychodynamic-and-humanistic-perspectives-on-personality': ['9.0'],
    'trait perspectives, social-cognitive theory, and personality testing': [
      '9.0',
    ],
    'trait-perspectives-social-cognitive-theory-and-personality-testing': [
      '9.0',
    ],
    'personality-theories': ['9.0'],
    'personality theories': ['9.0'],
    'personality': ['9.0'],

    // Domain 10.0: Psychological Disorders and Health
    'psychological disorders: classification, anxiety, ocd, and trauma': [
      '10.0',
    ],
    'psychological-disorders-classification-anxiety-ocd-and-trauma': ['10.0'],
    'psychological-disorders-part-1': ['10.0'],
    'psychological disorders (part 1)': ['10.0'],
    'depressive, bipolar, schizophrenic, and personality pathology': ['10.0'],
    'depressive-bipolar-schizophrenic-and-personality-pathology': ['10.0'],
    'psychological-disorders-part-2': ['10.0'],
    'psychological disorders (part 2)': ['10.0'],
    'psychological disorders': ['10.0'],
    'psychological disorders and health': ['10.0'],

    // Domain 11.0: Treatment of Psychological Disorders
    'psychological therapies: insight, behavior, and cognitive approaches': [
      '11.0',
    ],
    'psychological-therapies-insight-behavior-and-cognitive-approaches': [
      '11.0',
    ],
    'biomedical therapies, psychopharmacology, and treatment outcomes': [
      '11.0',
    ],
    'biomedical-therapies-psychopharmacology-and-treatment-outcomes': ['11.0'],
    'treatment-of-psychological-disorders': ['11.0'],
    'treatment of psychological disorders': ['11.0'],

    // Domain 12.0: Social Psychology
    'social thinking: attribution, cognitive dissonance, and obedience': [
      '12.0',
    ],
    'social-thinking-attribution-cognitive-dissonance-and-obedience': ['12.0'],
    'social-thinking-and-influence': ['12.0'],
    'social thinking and influence': ['12.0'],
    'group influence, prejudice, and the bystander effect': ['12.0'],
    'group-influence-prejudice-and-the-bystander-effect': ['12.0'],
    'social-relations-and-group-behavior': ['12.0'],
    'social relations and group behavior': ['12.0'],
    'social psychology': ['12.0'],

    // Domain 13.0: Statistics, Tests, and Measurement
    'statistical measures, psychometric standards, and intelligence assessment':
        ['13.0', '1.0'],
    'statistical-measures-psychometric-standards-and-intelligence-assessment': [
      '13.0',
      '1.0',
    ],
    'statistics, tests, and measurements': ['13.0'],
    'statistics, tests, and measurement': ['13.0'],
  };

  /// Canonical CLEP Introductory Psychology concept-slug-to-domain mappings
  /// from `content/clep_introductory_psychology.yaml`.
  static const Map<String, String> clepPsychConceptDomains = {
    'psyc-structuralism': '1.0',
    'psyc-functionalism': '1.0',
    'psyc-contemporary-perspectives': '1.0',
    'psyc-experimental-methodology': '1.0',
    'psyc-correlational-research': '1.0',
    'psyc-neuron-structure': '2.0',
    'psyc-neurotransmitters': '2.0',
    'psyc-brain-structures': '2.0',
    'psyc-hemispheric-specialization': '2.0',
    'psyc-sensory-thresholds': '3.0',
    'psyc-signal-detection': '3.0',
    'psyc-visual-auditory-systems': '3.0',
    'psyc-perceptual-organization': '3.0',
    'psyc-circadian-rhythms': '4.0',
    'psyc-sleep-stages': '4.0',
    'psyc-sleep-disorders-dreams': '4.0',
    'psyc-psychoactive-drugs': '4.0',
    'psyc-classical-conditioning': '5.0',
    'psyc-biological-constraints': '5.0',
    'psyc-operant-conditioning': '5.0',
    'psyc-observational-learning': '5.0',
    'psyc-memory-models': '6.0',
    'psyc-memory-systems-forgetting': '6.0',
    'psyc-problem-solving-biases': '6.0',
    'psyc-language-development': '6.0',
    'psyc-motivation-theories': '7.0',
    'psyc-hunger-physiology': '7.0',
    'psyc-emotion-theories': '7.0',
    'psyc-stress-gas': '7.0',
    'psyc-prenatal-infant-development': '8.0',
    'psyc-cognitive-development-stages': '8.0',
    'psyc-attachment-parenting': '8.0',
    'psyc-psychosocial-moral-development': '8.0',
    'psyc-freudian-psychodynamics': '9.0',
    'psyc-humanistic-personality': '9.0',
    'psyc-big-five-traits': '9.0',
    'psyc-social-cognitive-assessment': '9.0',
    'psyc-disorder-classification': '10.0',
    'psyc-anxiety-ocd-ptsd': '10.0',
    'psyc-mood-bipolar-disorders': '10.0',
    'psyc-schizophrenia-personality': '10.0',
    'psyc-psychotherapy-modalities': '11.0',
    'psyc-cognitive-behavioral-therapy': '11.0',
    'psyc-biomedical-pharmacology': '11.0',
    'psyc-treatment-efficacy-meta-analysis': '11.0',
    'psyc-attribution-dissonance': '12.0',
    'psyc-conformity-obedience': '12.0',
    'psyc-group-dynamics': '12.0',
    'psyc-prejudice-altruism': '12.0',
    'psyc-descriptive-inferential-statistics': '13.0',
    'psyc-psychometric-reliability-validity': '13.0',
    'psyc-intelligence-theories-measurement': '13.0',
  };

  /// Enforces the `SAFE-01` security boundary: client-side coverage and planning
  /// must never inspect `simulation_only` / `simulation_exam` items, protected stems,
  /// or scoring keys (`scoring_spec`, `correct_index`, `correct_answer`, `answer_key`).
  void validateAssessmentItemMetadata(
    Iterable<Map<String, dynamic>> itemMetadataRows,
  ) {
    for (final row in itemMetadataRows) {
      final itemId = row['id']?.toString() ?? row['slug']?.toString();
      final nestedMeta = row['metadata'] is Map
          ? Map<String, dynamic>.from(row['metadata'] as Map)
          : const <String, dynamic>{};

      String? readLower(String key) =>
          (row[key] ?? nestedMeta[key])?.toString().trim().toLowerCase();

      final deliveryMode = readLower('delivery_mode');
      final bank = readLower('bank') ?? readLower('item_bank');
      final itemRole = readLower('item_role');
      final exposure = readLower('exposure');
      final rawProtected = row['is_protected'] ?? nestedMeta['is_protected'];
      final isProtected =
          rawProtected == true ||
          rawProtected?.toString().trim().toLowerCase() == 'true';

      if (deliveryMode == 'simulation_only' ||
          bank == 'simulation_exam' ||
          itemRole == 'summative_simulation' ||
          exposure == 'timed_exam_only' ||
          isProtected) {
        throw ProtectedSimulationBankAccessException(
          'Client-side coverage/planner cannot read protected simulation_exam or simulation_only assessment items.',
          offendingItemId: itemId,
        );
      }

      const forbiddenKeys = <String>{
        'correct_answer',
        'answer_key',
        'scoring_spec',
        'correct_index',
        'simulation_stem',
        'protected_options',
      };
      if (forbiddenKeys.any(
        (k) => row.containsKey(k) || nestedMeta.containsKey(k),
      )) {
        throw ProtectedSimulationBankAccessException(
          'Client-side coverage/planner cannot inspect protected scoring keys or stems.',
          offendingItemId: itemId,
        );
      }
    }
  }

  /// Resolves an official blueprint domain ID for a curriculum node ID or code.
  String? resolveDomainForNodeId(
    String? nodeId, {
    List<SnapshotNode> curriculumNodes = const [],
    List<OfficialDomainBlueprint> officialDomains =
        clepPsychologyOfficialDomains,
  }) {
    if (nodeId == null || nodeId.trim().isEmpty) return null;
    final domainById = {
      for (final domain in officialDomains) domain.domainId: domain,
    };
    final nodeById = {
      for (final node in curriculumNodes) node.id: node,
    };
    return _resolveDomainFromNode(nodeId.trim(), nodeById, domainById);
  }

  /// Resolves official blueprint domain IDs for a concept ID or slug.
  Set<String> resolveDomainForConcept(
    String? conceptIdOrSlug, {
    List<OfficialDomainBlueprint> officialDomains =
        clepPsychologyOfficialDomains,
    Map<String, String> conceptDomainOverrides = const {},
  }) {
    if (conceptIdOrSlug == null || conceptIdOrSlug.trim().isEmpty) {
      return const <String>{};
    }
    final validDomains = {
      for (final d in officialDomains) d.domainId,
    };
    final normalized = conceptIdOrSlug.trim().toLowerCase();
    final matched = conceptDomainOverrides[conceptIdOrSlug] ??
        conceptDomainOverrides[normalized] ??
        clepPsychConceptDomains[normalized];
    if (matched != null && validDomains.contains(matched)) {
      return {matched};
    }
    return const <String>{};
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

      // 2. Snapshot curriculum node hierarchy / code (e.g. '1.0'..'13.0' or objective '1.1'..'13.1')
      if (candidateDomains.isEmpty && activity.curriculumNodeId != null) {
        final nodeId = activity.curriculumNodeId!.trim();
        final resolvedDomain = _resolveDomainFromNode(
          nodeId,
          nodeById,
          domainById,
        );
        if (resolvedDomain != null) {
          candidateDomains.add(resolvedDomain);
        }
      }

      // 3. Canonical slug/title lookup for CLEP Psychology (also enriches multi-domain interdisciplinary lessons)
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
      } else if (candidateDomains.isEmpty) {
        final titlePrefixMatch = _leadingObjectivePrefixPattern.firstMatch(
          normalizedTitle,
        );
        if (titlePrefixMatch != null) {
          final parentDomain = '${titlePrefixMatch.group(1)}.0';
          if (domainById.containsKey(parentDomain)) {
            candidateDomains.add(parentDomain);
          }
        }
        if (candidateDomains.isEmpty) {
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

  static final RegExp _objectiveCodePattern = RegExp(r'^(\d+)\.\d+$');
  static final RegExp _leadingObjectivePrefixPattern = RegExp(r'^(\d+)\.\d+\b');

  String? _normalizeDomainCodeCandidate(
    String? rawCode,
    Map<String, OfficialDomainBlueprint> domainById,
  ) {
    if (rawCode == null || rawCode.trim().isEmpty) return null;
    final trimmed = rawCode.trim();
    if (domainById.containsKey(trimmed)) {
      return trimmed;
    }
    final match = _objectiveCodePattern.firstMatch(trimmed);
    if (match != null) {
      final parentCode = '${match.group(1)}.0';
      if (domainById.containsKey(parentCode)) {
        return parentCode;
      }
    }
    return null;
  }

  String? _resolveDomainFromNode(
    String startNodeId,
    Map<String, SnapshotNode> nodeById,
    Map<String, OfficialDomainBlueprint> domainById,
  ) {
    final directCode = _normalizeDomainCodeCandidate(startNodeId, domainById);
    if (directCode != null) return directCode;

    final visited = <String>{};
    String? currentId = startNodeId;
    while (currentId != null && !visited.contains(currentId)) {
      visited.add(currentId);
      final node = nodeById[currentId];
      if (node == null) break;

      final fromCode = _normalizeDomainCodeCandidate(node.code, domainById);
      if (fromCode != null) return fromCode;

      final fromId = _normalizeDomainCodeCandidate(node.id, domainById);
      if (fromId != null) return fromId;

      // Match by domain title if code is absent
      final normalizedNodeTitle = node.title.trim().toLowerCase();
      for (final domain in domainById.values) {
        if (domain.title.trim().toLowerCase() == normalizedNodeTitle) {
          return domain.domainId;
        }
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

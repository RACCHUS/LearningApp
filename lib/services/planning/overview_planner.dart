import '../../models/learning_strategy.dart';
import '../../models/overview_outline.dart';

/// Projected view of a single [OverviewFamily] at a specific [OverviewDurationPreset].
class OverviewProjectedFamily {
  final OverviewFamily family;
  final OverviewDurationPreset preset;
  final List<OfficialDomainBlueprint> officialDomains;
  final String takeaway;
  final String? expandedExplanation;
  final List<String> keyDistinctions;
  final String? commonMisconception;
  final String? realWorldApplication;
  final String? connectionNotes;
  final List<OverviewVocabularyCard> vocabularyCards;
  final List<OverviewComprehensionCheck> comprehensionChecks;

  const OverviewProjectedFamily({
    required this.family,
    required this.preset,
    required this.officialDomains,
    required this.takeaway,
    this.expandedExplanation,
    this.keyDistinctions = const [],
    this.commonMisconception,
    this.realWorldApplication,
    this.connectionNotes,
    this.vocabularyCards = const [],
    this.comprehensionChecks = const [],
  });

  bool get showsFifteenMinuteDepth =>
      preset == OverviewDurationPreset.fifteenMinutes ||
      preset == OverviewDurationPreset.thirtyMinutes;

  bool get showsThirtyMinuteDepth =>
      preset == OverviewDurationPreset.thirtyMinutes;
}

/// Pure, immutable projection of an [OverviewOutline] for a chosen duration preset.
class OverviewPlanView {
  final OverviewOutline outline;
  final OverviewDurationPreset preset;
  final List<OverviewProjectedFamily> projectedFamilies;
  final List<OverviewVocabularyCard> allVisibleVocabularyCards;
  final List<OverviewComprehensionCheck> allVisibleComprehensionChecks;
  final List<String> omittedOrDeferredNotes;
  final OverviewProvenance provenance;

  const OverviewPlanView({
    required this.outline,
    required this.preset,
    required this.projectedFamilies,
    required this.allVisibleVocabularyCards,
    required this.allVisibleComprehensionChecks,
    required this.omittedOrDeferredNotes,
    required this.provenance,
  });

  int get familyCount => projectedFamilies.length;
  int get officialDomainCount => outline.officialDomains.length;
}

/// Pure service that projects an [OverviewOutline] at 5, 15, or 30 minutes (`TEL-03`).
///
/// Guarantees read-only invariance: projecting or inspecting an overview
/// never mutates any database, cache, context, or learner evidence state.
class OverviewPlanner {
  const OverviewPlanner();

  static final Map<String, OverviewOutline> _registeredOutlines = {
    clepPsychologyOverviewOutline.id.toLowerCase():
        clepPsychologyOverviewOutline,
    clepPsychologyOverviewOutline.targetId.toLowerCase():
        clepPsychologyOverviewOutline,
    clepPsychologyOverviewOutline.targetSlug.toLowerCase():
        clepPsychologyOverviewOutline,
    clepPsychologyOverviewOutline.title.toLowerCase():
        clepPsychologyOverviewOutline,
    'clep_introductory_psychology': clepPsychologyOverviewOutline,
    'a0000000-0000-0000-0000-000000000001': clepPsychologyOverviewOutline,
    '00000000-0000-4000-8000-000000000101': clepPsychologyOverviewOutline,
  };

  /// Looks up a reviewed [OverviewOutline] by target ID, target slug, or outline ID.
  OverviewOutline? findOutlineForTarget(String? targetSlugOrId) {
    if (targetSlugOrId == null || targetSlugOrId.trim().isEmpty) {
      return null;
    }
    return _registeredOutlines[targetSlugOrId.trim().toLowerCase()];
  }

  /// Projects [outline] at [preset] using progressive depth over the same
  /// single authored outline (`TEL-02A`, `TEL-03`).
  OverviewPlanView project({
    required OverviewOutline outline,
    OverviewDurationPreset preset = OverviewDurationPreset.fifteenMinutes,
  }) {
    final domainById = {
      for (final domain in outline.officialDomains) domain.domainId: domain,
    };

    final sortedFamilies = List<OverviewFamily>.from(outline.families)
      ..sort((a, b) => a.order.compareTo(b.order));

    final include15m =
        preset == OverviewDurationPreset.fifteenMinutes ||
        preset == OverviewDurationPreset.thirtyMinutes;
    final include30m = preset == OverviewDurationPreset.thirtyMinutes;

    final projectedFamilies = <OverviewProjectedFamily>[];
    final allVocabulary = <OverviewVocabularyCard>[];
    final allChecks = <OverviewComprehensionCheck>[];

    for (final family in sortedFamilies) {
      final mappedDomains = family.officialDomainIds
          .map((id) => domainById[id])
          .whereType<OfficialDomainBlueprint>()
          .toList();

      final visibleVocab = include15m
          ? List<OverviewVocabularyCard>.unmodifiable(family.vocabularyCards)
          : const <OverviewVocabularyCard>[];
      final visibleChecks = include30m
          ? List<OverviewComprehensionCheck>.unmodifiable(
              family.comprehensionChecks,
            )
          : const <OverviewComprehensionCheck>[];

      allVocabulary.addAll(visibleVocab);
      allChecks.addAll(visibleChecks);

      projectedFamilies.add(
        OverviewProjectedFamily(
          family: family,
          preset: preset,
          officialDomains: List<OfficialDomainBlueprint>.unmodifiable(
            mappedDomains,
          ),
          takeaway: family.fiveMinuteTakeaway,
          expandedExplanation: include15m
              ? family.fifteenMinuteExplanation
              : null,
          keyDistinctions: include15m
              ? List<String>.unmodifiable(family.keyDistinctions)
              : const [],
          commonMisconception: include15m ? family.commonMisconception : null,
          realWorldApplication: include30m
              ? family.thirtyMinuteRealWorldApplication
              : null,
          connectionNotes: include30m
              ? family.thirtyMinuteConnectionNotes
              : null,
          vocabularyCards: visibleVocab,
          comprehensionChecks: visibleChecks,
        ),
      );
    }

    return OverviewPlanView(
      outline: outline,
      preset: preset,
      projectedFamilies: List<OverviewProjectedFamily>.unmodifiable(
        projectedFamilies,
      ),
      allVisibleVocabularyCards: List<OverviewVocabularyCard>.unmodifiable(
        allVocabulary,
      ),
      allVisibleComprehensionChecks:
          List<OverviewComprehensionCheck>.unmodifiable(allChecks),
      omittedOrDeferredNotes: List<String>.unmodifiable(
        outline.omittedOrDeferredNotes,
      ),
      provenance: outline.provenance,
    );
  }
}

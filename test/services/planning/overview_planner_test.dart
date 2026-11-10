import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_strategy.dart';
import 'package:learning_pwa/models/overview_outline.dart';
import 'package:learning_pwa/services/planning/overview_planner.dart';

void main() {
  const planner = OverviewPlanner();

  group('TEL-02A & TEL-03 OverviewPlanner and CLEP Psychology Pilot Outline', () {
    test(
      'CLEP Introductory Psychology outline maps all 13 official domains across 7 reviewed topic families',
      () {
        final outline = planner.findOutlineForTarget(
          'clep-introductory-psychology',
        );
        expect(outline, isNotNull);
        expect(outline!.families.length, 7);
        expect(outline.officialDomains.length, 13);

        final coveredByFamilies = outline.families
            .expand((f) => f.officialDomainIds)
            .toSet();
        final allOfficialIds = outline.officialDomains
            .map((d) => d.domainId)
            .toSet();
        expect(coveredByFamilies, equals(allOfficialIds));

        // Normalized internal model weights sum to 1.0000 (within rounding tolerance)
        final weightSum = outline.officialDomains.fold<double>(
          0.0,
          (sum, d) => sum + d.normalizedModelWeight,
        );
        expect(weightSum, closeTo(1.0, 0.001));
      },
    );

    test(
      'Progressive depth presets (5m, 15m, 30m) project over the same single authored outline',
      () {
        const outline = clepPsychologyOverviewOutline;

        final view5 = planner.project(
          outline: outline,
          preset: OverviewDurationPreset.fiveMinutes,
        );
        final view15 = planner.project(
          outline: outline,
          preset: OverviewDurationPreset.fifteenMinutes,
        );
        final view30 = planner.project(
          outline: outline,
          preset: OverviewDurationPreset.thirtyMinutes,
        );

        // Same 7 families in identical order across all 3 presets
        expect(
          view5.projectedFamilies.map((f) => f.family.id).toList(),
          equals(view15.projectedFamilies.map((f) => f.family.id).toList()),
        );
        expect(
          view15.projectedFamilies.map((f) => f.family.id).toList(),
          equals(view30.projectedFamilies.map((f) => f.family.id).toList()),
        );

        // 5-min preset shows takeaways only (no vocab cards, misconceptions, or checks)
        expect(view5.allVisibleVocabularyCards, isEmpty);
        expect(view5.allVisibleComprehensionChecks, isEmpty);
        expect(
          view5.projectedFamilies.every((f) => f.expandedExplanation == null),
          isTrue,
        );

        // 15-min preset adds explanations, key distinctions, misconceptions, and vocab cards
        expect(view15.allVisibleVocabularyCards, isNotEmpty);
        expect(
          view15.projectedFamilies.every((f) => f.expandedExplanation != null),
          isTrue,
        );
        expect(
          view15.projectedFamilies.every((f) => f.commonMisconception != null),
          isTrue,
        );
        expect(view15.allVisibleComprehensionChecks, isEmpty);

        // 30-min preset adds real-world applications, connection notes, and optional checks
        expect(view30.allVisibleVocabularyCards, isNotEmpty);
        expect(view30.allVisibleComprehensionChecks, isNotEmpty);
        expect(
          view30.projectedFamilies.every((f) => f.realWorldApplication != null),
          isTrue,
        );
      },
    );

    test(
      'Provenance includes OpenStax Psychology 2e CC BY 4.0 attribution and honest unverified_placeholder SHA-256 disclosure',
      () {
        final prov = clepPsychologyOverviewOutline.provenance;
        expect(prov.openTextbookAttribution, contains('OpenStax Psychology 2e'));
        expect(prov.openTextbookLicense, contains('CC BY 4.0'));
        expect(
          prov.verificationLevel,
          SourceVerificationLevel.unverifiedPlaceholder,
        );
        expect(prov.verificationDisclosure, contains('hash_unavailable'));
      },
    );
  });
}

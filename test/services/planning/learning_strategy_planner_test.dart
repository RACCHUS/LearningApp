import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/fast_plan_result.dart';
import 'package:learning_pwa/models/lesson_block.dart';
import 'package:learning_pwa/models/learning_strategy.dart';
import 'package:learning_pwa/models/overview_outline.dart';
import 'package:learning_pwa/models/scope.dart';
import 'package:learning_pwa/services/next_action_engine.dart';
import 'package:learning_pwa/services/planning/content_coverage_service.dart';
import 'package:learning_pwa/services/planning/learning_strategy_planner.dart';

void main() {
  const coverageService = ContentCoverageService();
  const planner = LearningStrategyPlanner(coverageService: coverageService);
  final fixedAsOf = DateTime.utc(2026, 11, 10, 12, 0, 0);

  ResolvedScope buildFullClepScope({
    EstimateQuality defaultQuality = EstimateQuality.authored,
  }) {
    const canonicalLessons = <(String id, String title, String domain, int mins)>[
      ('l01-history', 'History and Approaches', '1.0', 15),
      ('l02-methods', 'Research Methods', '1.0', 20),
      ('l03-neurons', 'Neurons and Neurotransmitters', '2.0', 15),
      ('l04-brain', 'Brain Structure and Function', '2.0', 20),
      ('l05-sensation', 'Sensation and Perception', '3.0', 15),
      ('l06-consciousness', 'States of Consciousness', '4.0', 15),
      ('l07-classical', 'Classical Conditioning', '5.0', 15),
      ('l08-operant', 'Operant and Observational Learning', '5.0', 20),
      ('l09-memory', 'Memory', '6.0', 15),
      ('l10-thinking', 'Thinking, Language, and Intelligence', '6.0', 20),
      ('l11-motivation', 'Motivation', '7.0', 15),
      ('l12-emotion', 'Emotion and Stress', '7.0', 15),
      ('l13-dev-early', 'Lifespan Development: Early', '8.0', 15),
      ('l14-dev-adult', 'Lifespan Development: Adolescence and Adulthood', '8.0', 15),
      ('l15-personality', 'Personality Theories', '9.0', 15),
      ('l16-disorders-1', 'Psychological Disorders (Part 1)', '10.0', 15),
      ('l17-disorders-2', 'Psychological Disorders (Part 2)', '10.0', 15),
      ('l18-treatment', 'Treatment of Psychological Disorders', '11.0', 15),
      ('l19-social-1', 'Social Thinking and Influence', '12.0', 15),
      ('l20-social-2', 'Social Relations and Group Behavior', '12.0', 15),
      ('l21-stats', 'Statistics, Tests, and Measurements', '13.0', 15),
    ];

    return ResolvedScope(
      contextId: 'ctx-clep-psych',
      resolvedAt: fixedAsOf,
      orderedActivities: [
        for (var i = 0; i < canonicalLessons.length; i++)
          ScopedLearningActivity(
            activityId: canonicalLessons[i].$1,
            kind: ScopedActivityKind.lesson,
            title: canonicalLessons[i].$2,
            curriculumNodeId: canonicalLessons[i].$3,
            curriculumOrder: i,
            activityOrder: i,
            estimatedDuration: Duration(minutes: canonicalLessons[i].$4),
            estimateQuality: defaultQuality,
          ),
      ],
    );
  }

  group('TEL-04 Golden Fixtures (fast_v1_1)', () {
    test(
      'BREADTH-01: 13 blueprint domains represent all 13 in first breadth pass before second lessons in same domain',
      () {
        final scope = buildFullClepScope();
        final coverage = coverageService.buildCoverageForScope(scope: scope);

        final result = planner.plan(
          scope: scope,
          coverage: coverage,
          asOf: fixedAsOf,
        );

        expect(result.policyVersion, FastPlanResult.currentPolicyVersion);
        expect(result.fullOrderedCandidates.length, 21);

        // First 13 scheduled activities must cover all 13 official domains
        // before any domain gets a second depth-pass lesson.
        final first13 = result.fullOrderedCandidates.take(13).toList();
        final first13Domains = first13
            .map((c) => c.primaryDomainId)
            .whereType<String>()
            .toSet();

        expect(first13Domains.length, 13);
        expect(
          first13.every(
            (c) => c.actionClass == FastCandidateActionClass.recommended,
          ),
          isTrue,
        );
        expect(
          first13.every(
            (c) => c.reasonCodes.contains(FastReasonCodes.breadthCoverage),
          ),
          isTrue,
        );

        // Highest-weight domain (1.0: 0.1133) leads the breadth pass
        expect(first13.first.primaryDomainId, '1.0');
        expect(first13.first.activityId, 'l01-history');

        // Remaining 8 lessons belong to the depth pass (deprioritized after breadth)
        final depthPass = result.fullOrderedCandidates.skip(13).toList();
        expect(depthPass.length, 8);
        expect(
          depthPass.every(
            (c) => c.actionClass == FastCandidateActionClass.deprioritized,
          ),
          isTrue,
        );
      },
    );

    test(
      'PREREQ-01: Highest-weight lesson depending on unfinished lower-weight prerequisite schedules prerequisite first with explicit dependency rationale',
      () {
        final scope = buildFullClepScope();
        final coverage = coverageService.buildCoverageForScope(
          scope: scope,
          explicitActivityPrerequisites: const {
            // Highest-weight lesson l01-history (Domain 1.0) depends on lower-weight l21-stats (Domain 13.0)
            'l01-history': ['l21-stats'],
          },
        );

        final result = planner.plan(
          scope: scope,
          coverage: coverage,
          asOf: fixedAsOf,
        );

        final ids = result.fullOrderedCandidates
            .map((c) => c.activityId)
            .toList();
        final statsIdx = ids.indexOf('l21-stats');
        final historyIdx = ids.indexOf('l01-history');

        expect(statsIdx, isNonNegative);
        expect(historyIdx, isNonNegative);
        expect(statsIdx, lessThan(historyIdx));
        expect(statsIdx, 0);

        final statsCandidate = result.fullOrderedCandidates[statsIdx];
        expect(
          statsCandidate.reasonCodes,
          contains(FastReasonCodes.prerequisiteRequired),
        );
        expect(
          statsCandidate.userFacingRationale,
          contains('History and Approaches'),
        );
      },
    );

    test(
      'EVIDENCE-01: Self-reported familiarity or FSRS history never bypasses a domain or marks it competent; unassessed domain stays notAssessed',
      () {
        final scope = buildFullClepScope();
        final coverage = coverageService.buildCoverageForScope(scope: scope);

        final result = planner.plan(
          scope: scope,
          coverage: coverage,
          asOf: fixedAsOf,
          domainEvidence: const {
            // Domain 1.0 has self-reported familiarity and FSRS history, but 0 independent attempts
            '1.0': EvidenceSummary(
              subjectKey: '1.0',
              statusLabel: EvidenceStatusLabel.independentEvidenceAvailable,
              independentAttemptCount: 0,
              hasSelfReportedFamiliarity: true,
              hasFsrsSchedulingHistory: true,
            ),
            // Domain 2.0 has no assessment at all
            '2.0': EvidenceSummary(
              subjectKey: '2.0',
              statusLabel: EvidenceStatusLabel.notAssessed,
            ),
          },
        );

        final dom1 = result.domainCoverage.firstWhere(
          (d) => d.domainId == '1.0',
        );
        final dom2 = result.domainCoverage.firstWhere(
          (d) => d.domainId == '2.0',
        );

        // Neither domain is bypassed; both still have breadth representatives scheduled
        expect(dom1.breadthRepresentativeActivityId, isNotNull);
        expect(dom2.breadthRepresentativeActivityId, isNotNull);
        expect(dom1.evidenceStatus, EvidenceStatusLabel.notAssessed);
        expect(dom2.evidenceStatus, EvidenceStatusLabel.notAssessed);

        // No candidate has any bypass classification
        expect(
          result.fullOrderedCandidates.any(
            (c) => c.actionClass.wireValue == 'supported_bypass',
          ),
          isFalse,
        );
      },
    );

    test(
      'COVERAGE-01: Domain lacking mapped lessons stays visible in domainCoverage as coverage_missing without inventing activities',
      () {
        // Omit Domain 4.0 ('l06-consciousness') from scope
        final fullScope = buildFullClepScope();
        final filteredActivities = fullScope.orderedActivities
            .where((a) => a.activityId != 'l06-consciousness')
            .toList();
        final scopeWithoutDom4 = ResolvedScope(
          contextId: fullScope.contextId,
          resolvedAt: fixedAsOf,
          orderedActivities: filteredActivities,
        );

        final coverage = coverageService.buildCoverageForScope(
          scope: scopeWithoutDom4,
        );
        final result = planner.plan(
          scope: scopeWithoutDom4,
          coverage: coverage,
          asOf: fixedAsOf,
        );

        expect(result.domainCoverage.length, 13);
        final dom4 = result.domainCoverage.firstWhere(
          (d) => d.domainId == '4.0',
        );
        expect(dom4.isCoverageMissing, isTrue);
        expect(dom4.mappedActivityIds, isEmpty);
        expect(dom4.breadthRepresentativeActivityId, isNull);
        // Planner must not invent fake activities
        expect(
          result.fullOrderedCandidates.length,
          filteredActivities.length,
        );
      },
    );

    test(
      'BUDGET-01: Known 20-minute budget with at least one defaultEstimate lesson marks budget feasibility provisional and discloses known subtotal and unreached domains',
      () {
        final fullScope = buildFullClepScope(
          defaultQuality: EstimateQuality.authored,
        );
        // Replace first activity with a defaultEstimate (unknown exact time) lesson
        final modified = List<ScopedLearningActivity>.from(
          fullScope.orderedActivities,
        );
        modified[0] = ScopedLearningActivity(
          activityId: modified[0].activityId,
          kind: modified[0].kind,
          title: modified[0].title,
          curriculumNodeId: modified[0].curriculumNodeId,
          curriculumOrder: modified[0].curriculumOrder,
          activityOrder: modified[0].activityOrder,
          estimatedDuration: const Duration(minutes: 15),
          estimateQuality: EstimateQuality.defaultEstimate,
        );

        final scope = ResolvedScope(
          contextId: fullScope.contextId,
          resolvedAt: fixedAsOf,
          orderedActivities: modified,
        );
        final coverage = coverageService.buildCoverageForScope(scope: scope);

        final result = planner.plan(
          scope: scope,
          coverage: coverage,
          asOf: fixedAsOf,
          optionalTotalMinutes: 20,
        );

        expect(
          result.budgetFeasibility,
          BudgetFeasibilityStatus.provisionalUnknownTime,
        );
        expect(result.remainingUnknownTimeCount, 1);
        expect(result.knownDurationSubtotalMinutes, greaterThan(0));
        expect(result.provisionalBudgetSchedule.length, 1);
        expect(result.unreachedDomainIdsInBudget.length, 12);
      },
    );

    test(
      'RESUME-01: Learner halfway through a deprioritized lesson keeps ResumeActivity as primary while Fast recommendation is surfaced as secondary',
      () {
        final scope = buildFullClepScope();
        final coverage = coverageService.buildCoverageForScope(scope: scope);
        final fastPlan = planner.plan(
          scope: scope,
          coverage: coverage,
          asOf: fixedAsOf,
        );

        // Learner is halfway through 'l20-social-2' (a deprioritized depth lesson)
        const resumeAction = ResumeActivity(
          activity: LessonActivity(
            lessonId: 'l20-social-2',
            title: 'Social Relations and Group Behavior',
          ),
          itemIndex: 3,
        );

        final presentation = planner.resolvePresentation(
          primaryAction: resumeAction,
          fastPlan: fastPlan,
          activeStrategy: PersistedLearningStrategy.fast,
        );

        expect(presentation.primaryAction, same(resumeAction));
        expect(presentation.hasSecondaryFastAlternative, isTrue);
        final secActivity =
            presentation.secondaryFastAction!.activity as LessonActivity;
        expect(secActivity.lessonId, 'l01-history');
        expect(presentation.secondaryFastRationale, isNotNull);
      },
    );

    test(
      'ORDER-01: Identical versioned inputs, ties, and asOf produce identical ordered IDs and reason codes across repeat calls',
      () {
        final scope = buildFullClepScope();
        final coverage = coverageService.buildCoverageForScope(scope: scope);

        final run1 = planner.plan(
          scope: scope,
          coverage: coverage,
          asOf: fixedAsOf,
        );
        final run2 = planner.plan(
          scope: scope,
          coverage: coverage,
          asOf: fixedAsOf,
        );

        expect(
          run1.fullOrderedCandidates.map((c) => c.activityId).toList(),
          equals(run2.fullOrderedCandidates.map((c) => c.activityId).toList()),
        );
        for (var i = 0; i < run1.fullOrderedCandidates.length; i++) {
          expect(
            run1.fullOrderedCandidates[i].reasonCodes,
            equals(run2.fullOrderedCandidates[i].reasonCodes),
          );
          expect(
            run1.fullOrderedCandidates[i].userFacingRationale,
            equals(run2.fullOrderedCandidates[i].userFacingRationale),
          );
        }
      },
    );

    test(
      'SAFE-01: Attempting to pass simulation_only items or protected answer keys to coverage/planner throws ProtectedSimulationBankAccessException',
      () {
        final scope = buildFullClepScope();

        expect(
          () => coverageService.buildCoverageForScope(
            scope: scope,
            rawAssessmentMetadataToValidate: const [
              {
                'id': 'sim-item-001',
                'delivery_mode': 'simulation_only',
              },
            ],
          ),
          throwsA(isA<ProtectedSimulationBankAccessException>()),
        );

        expect(
          () => coverageService.validateAssessmentItemMetadata(const [
            {
              'id': 'formative-item-001',
              'delivery_mode': 'practice',
              'correct_answer': 'B',
            },
          ]),
          throwsA(isA<ProtectedSimulationBankAccessException>()),
        );
      },
    );
  });

  group('TEL-02B Primitives: EstimateQuality & DepthTier backward compatibility', () {
    test(
      'ScopedLearningActivity.fromJson defaults missing estimate_quality or non-positive minutes to EstimateQuality.defaultEstimate',
      () {
        final legacyJson = {
          'activity_id': 'lesson-legacy-1',
          'kind': 'lesson',
          'title': 'Legacy Cached Lesson',
          'estimated_minutes': 15,
        };
        final decodedLegacy = ScopedLearningActivity.fromJson(legacyJson);
        expect(decodedLegacy.estimateQuality, EstimateQuality.defaultEstimate);

        final invalidMinutesJson = {
          'activity_id': 'lesson-invalid-mins',
          'kind': 'lesson',
          'title': 'Invalid Minutes Lesson',
          'estimated_minutes': -5,
          'estimate_quality': 'authored',
        };
        final decodedInvalid = ScopedLearningActivity.fromJson(
          invalidMinutesJson,
        );
        expect(decodedInvalid.estimateQuality, EstimateQuality.defaultEstimate);
        expect(decodedInvalid.estimatedMinutes, 10);

        final authoredJson = {
          'activity_id': 'lesson-authored',
          'kind': 'lesson',
          'title': 'Authored Lesson',
          'estimated_minutes': 25,
          'estimate_quality': 'authored',
        };
        final decodedAuthored = ScopedLearningActivity.fromJson(authoredJson);
        expect(decodedAuthored.estimateQuality, EstimateQuality.authored);
        expect(decodedAuthored.estimatedMinutes, 25);
      },
    );

    test('LessonBlock.depthTier reads metadata depth_tier and defaults to core', () {
      final now = DateTime.utc(2026, 11, 10);
      final blockDefault = LessonBlock(
        id: 'b1',
        lessonId: 'l1',
        sortOrder: 0,
        blockType: LessonBlockType.markdown,
        createdAt: now,
        updatedAt: now,
      );
      expect(blockDefault.depthTier, DepthTier.core);

      final blockEnrichment = blockDefault.copyWith(
        metadata: const {'depth_tier': 'enrichment'},
      );
      expect(blockEnrichment.depthTier, DepthTier.enrichment);
    });
  });
}

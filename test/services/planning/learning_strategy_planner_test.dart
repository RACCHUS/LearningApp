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

  group('TEL-04A Fast blueprint selection per exam target', () {
    test('officialDomainsForTarget returns the psychology blueprint only for the psychology target', () {
      for (final key in clepPsychologyTargetKeys) {
        expect(officialDomainsForTarget(key), same(clepPsychologyOfficialDomains));
      }
      expect(
        officialDomainsForTarget(' CLEP-Introductory-Psychology '),
        same(clepPsychologyOfficialDomains),
      );
      expect(officialDomainsForTarget('clep-college-algebra'), isEmpty);
      expect(officialDomainsForTarget('b0000000-0000-0000-0000-000000000002'), isEmpty);
      expect(officialDomainsForTarget(null), isEmpty);
    });

    test(
      'non-psychology targets get no psychology domain mappings and an honest generic Fast plan',
      () {
        final scope = buildFullClepScope();
        final coverage = coverageService.buildCoverageForScope(
          scope: scope,
          officialDomains: officialDomainsForTarget('clep-college-algebra'),
        );

        expect(coverage.officialDomains, isEmpty);
        expect(
          coverage.unmappedActivityIds.toSet(),
          scope.orderedActivities.map((a) => a.activityId).toSet(),
        );
        for (final record in coverage.recordsByActivityId.values) {
          expect(record.primaryDomainId, isNull);
        }
        expect(
          coverageService.resolveDomainForConcept(
            'classical_conditioning',
            officialDomains: const <OfficialDomainBlueprint>[],
          ),
          isEmpty,
        );

        final result = planner.plan(
          scope: scope,
          coverage: coverage,
          asOf: fixedAsOf,
        );
        expect(result.domainCoverage, isEmpty);
        expect(result.usesOfficialBlueprint, isFalse);
        expect(result.fullOrderedCandidates, hasLength(scope.orderedActivities.length));
      },
    );

    test('psychology target keeps its official blueprint coverage', () {
      final scope = buildFullClepScope();
      final coverage = coverageService.buildCoverageForScope(
        scope: scope,
        officialDomains: officialDomainsForTarget('clep-introductory-psychology'),
      );
      expect(coverage.unmappedActivityIds, isEmpty);
      final result = planner.plan(
        scope: scope,
        coverage: coverage,
        asOf: fixedAsOf,
      );
      expect(result.usesOfficialBlueprint, isTrue);
      expect(result.domainCoverage, hasLength(13));
    });
  });

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

        // Actual CLEP Introductory Psychology / College Algebra simulation metadata shape
        expect(
          () => coverageService.validateAssessmentItemMetadata(const [
            {
              'id': 'clep-sim-item-001',
              'metadata': {
                'bank': 'simulation_exam',
                'item_role': 'summative_simulation',
                'is_protected': true,
                'exposure': 'timed_exam_only',
              },
            },
          ]),
          throwsA(isA<ProtectedSimulationBankAccessException>()),
        );

        expect(
          () => coverageService.validateAssessmentItemMetadata(const [
            {
              'id': 'clep-scoring-spec-001',
              'scoring_spec': {'correct_index': 2},
            },
          ]),
          throwsA(isA<ProtectedSimulationBankAccessException>()),
        );
      },
    );

    test(
      'ROLLOUT-01: TelFeatureFlags enables Overview for canonical CLEP UUIDs/slugs and preserves owner-approved exam-target Fast availability',
      () {
        const flags = TelFeatureFlags();
        expect(
          flags.isOverviewEnabledForTarget('clep-introductory-psychology'),
          isTrue,
        );
        expect(
          flags.isOverviewEnabledForTarget(
            '00000000-0000-4000-8000-000000000101',
          ),
          isTrue,
        );
        expect(
          flags.isOverviewEnabledForTarget(
            'a0000000-0000-0000-0000-000000000001',
          ),
          isTrue,
        );
        expect(
          flags.isOverviewEnabledForTarget(
            '00000000-0000-4000-8000-000000000102',
          ),
          isFalse,
        );
        expect(
          flags.isFastEnabledForTarget(
            '00000000-0000-4000-8000-000000000101',
            isExamTarget: true,
          ),
          isTrue,
        );
        expect(
          flags.isFastEnabledForTarget(
            '00000000-0000-4000-8000-000000000101',
            isExamTarget: false,
          ),
          isFalse,
        );
        expect(
          TelFeatureFlags.disabled.isFastEnabledForTarget(
            '00000000-0000-4000-8000-000000000101',
            isExamTarget: true,
          ),
          isFalse,
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

  group('TEL-04A Canonical CLEP Curriculum & Objective Node Mapping', () {
    test(
      'All 25 canonical CLEP Introductory Psychology lesson titles and objective SnapshotNodes (1.1..13.1) map cleanly to the 13 official domains with zero unmapped activities',
      () {
        const canonicalYamlLessons = <(String id, String title, String nodeId, String objectiveCode, String expectedDomain)>[
          ('uuid-01', '1.1 Psychological Perspectives & History', 'node-obj-1-1', '1.1', '1.0'),
          ('uuid-02', '1.2 Research Designs & Ethics', 'node-obj-1-2', '1.2', '1.0'),
          ('uuid-03', '2.1 Neurons & Neurotransmission', 'node-obj-2-1', '2.1', '2.0'),
          ('uuid-04', '2.2 Brain Structure & Endocrine System', 'node-obj-2-2', '2.2', '2.0'),
          ('uuid-05', '2.3 Behavioral Genetics', 'node-obj-2-3', '2.3', '2.0'),
          ('uuid-06', '3.1 Sensory Transduction, Vision & Hearing', 'node-obj-3-1', '3.1', '3.0'),
          ('uuid-07', '3.2 Perceptual Organization & Attention', 'node-obj-3-2', '3.2', '3.0'),
          ('uuid-08', '4.1 Sleep, Dreams & Circadian Rhythms', 'node-obj-4-1', '4.1', '4.0'),
          ('uuid-09', '4.2 Hypnosis & Psychoactive Drugs', 'node-obj-4-2', '4.2', '4.0'),
          ('uuid-10', '5.1 Classical Conditioning', 'node-obj-5-1', '5.1', '5.0'),
          ('uuid-11', '5.2 Operant Conditioning', 'node-obj-5-2', '5.2', '5.0'),
          ('uuid-12', '5.3 Cognitive & Observational Learning', 'node-obj-5-3', '5.3', '5.0'),
          ('uuid-13', '6.1 Memory Systems, Encoding & Forgetting', 'node-obj-6-1', '6.1', '6.0'),
          ('uuid-14', '6.2 Thinking, Heuristics & Language', 'node-obj-6-2', '6.2', '6.0'),
          ('uuid-15', '7.1 Theories of Motivation & Biological Drives', 'node-obj-7-1', '7.1', '7.0'),
          ('uuid-16', '7.2 Theories of Emotion & Stress', 'node-obj-7-2', '7.2', '7.0'),
          ('uuid-17', '8.1 Prenatal, Physical & Cognitive Development', 'node-obj-8-1', '8.1', '8.0'),
          ('uuid-18', '8.2 Social, Moral & Lifespan Development', 'node-obj-8-2', '8.2', '8.0'),
          ('uuid-19', '9.1 Personality Theories & Trait Assessment', 'node-obj-9-1', '9.1', '9.0'),
          ('uuid-20', '10.1 Classification, Anxiety, Mood & Dissociative Disorders', 'node-obj-10-1', '10.1', '10.0'),
          ('uuid-21', '10.2 Schizophrenia, Personality & Neurodevelopmental Disorders', 'node-obj-10-2', '10.2', '10.0'),
          ('uuid-22', '11.1 Psychotherapy & Biomedical Treatments', 'node-obj-11-1', '11.1', '11.0'),
          ('uuid-23', '12.1 Attribution, Attitudes & Conformity', 'node-obj-12-1', '12.1', '12.0'),
          ('uuid-24', '12.2 Group Dynamics, Prejudice, Aggression & Prosocial Behavior', 'node-obj-12-2', '12.2', '12.0'),
          ('uuid-25', '13.1 Descriptive & Inferential Statistics, Psychometrics & Intelligence', 'node-obj-13-1', '13.1', '13.0'),
        ];

        final snapshotNodes = <SnapshotNode>[
          for (var d = 1; d <= 13; d++)
            SnapshotNode(
              id: 'node-dom-$d',
              title: 'Domain $d',
              code: '$d.0',
              nodeType: 'domain',
              sortOrder: d,
            ),
          for (var i = 0; i < canonicalYamlLessons.length; i++)
            SnapshotNode(
              id: canonicalYamlLessons[i].$3,
              parentId:
                  'node-dom-${canonicalYamlLessons[i].$5.split('.').first}',
              title: canonicalYamlLessons[i].$2,
              code: canonicalYamlLessons[i].$4,
              nodeType: 'objective',
              sortOrder: i,
            ),
        ];

        // 1. Verify mapping via objective SnapshotNodes even when titles are generic UUIDs
        final nodeOnlyScope = ResolvedScope(
          contextId: 'ctx-clep-nodes',
          resolvedAt: fixedAsOf,
          orderedActivities: [
            for (var i = 0; i < canonicalYamlLessons.length; i++)
              ScopedLearningActivity(
                activityId: canonicalYamlLessons[i].$1,
                kind: ScopedActivityKind.lesson,
                title: 'Lesson ${i + 1}',
                curriculumNodeId: canonicalYamlLessons[i].$3,
                curriculumOrder: i,
                activityOrder: i,
              ),
          ],
        );

        final nodeCoverage = coverageService.buildCoverageForScope(
          scope: nodeOnlyScope,
          curriculumNodes: snapshotNodes,
        );
        expect(nodeCoverage.unmappedActivityIds, isEmpty);
        for (final item in canonicalYamlLessons) {
          expect(
            nodeCoverage.recordsByActivityId[item.$1]?.primaryDomainId,
            item.$5,
          );
        }

        // 2. Verify mapping via exact YAML titles even when curriculumNodes are absent
        final titleOnlyScope = ResolvedScope(
          contextId: 'ctx-clep-titles',
          resolvedAt: fixedAsOf,
          orderedActivities: [
            for (var i = 0; i < canonicalYamlLessons.length; i++)
              ScopedLearningActivity(
                activityId: canonicalYamlLessons[i].$1,
                kind: ScopedActivityKind.lesson,
                title: canonicalYamlLessons[i].$2,
                curriculumOrder: i,
                activityOrder: i,
              ),
          ],
        );

        final titleCoverage = coverageService.buildCoverageForScope(
          scope: titleOnlyScope,
        );
        expect(titleCoverage.unmappedActivityIds, isEmpty);
        for (final item in canonicalYamlLessons) {
          expect(
            titleCoverage.recordsByActivityId[item.$1]?.primaryDomainId,
            item.$5,
          );
        }

        // 3. Verify Fast plan with completed lessons and domain gap evidence
        final completedFirst13 = titleCoverage.officialDomains
            .map(
              (d) => canonicalYamlLessons
                  .firstWhere((l) => l.$5 == d.domainId)
                  .$1,
            )
            .toSet();

        final planWithGap = planner.plan(
          scope: titleOnlyScope,
          coverage: titleCoverage,
          asOf: fixedAsOf,
          completedActivityIds: completedFirst13,
          domainEvidence: const {
            // Domain 12.0 has low independent evidence (<0.75) -> independentGapEvidence priority in Pass 2
            '12.0': EvidenceSummary(
              subjectKey: '12.0',
              statusLabel: EvidenceStatusLabel.independentEvidenceAvailable,
              independentAttemptCount: 3,
              independentScore: 0.33,
            ),
          },
        );

        expect(planWithGap.topRecommendedActivity, isNotNull);
        expect(planWithGap.topRecommendedActivity!.primaryDomainId, '12.0');
        expect(
          planWithGap.topRecommendedActivity!.reasonCodes,
          contains(FastReasonCodes.independentGapEvidence),
        );
      },
    );
  });
}

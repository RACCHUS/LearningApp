import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/assessment_engine/exam_diagnostic_report.dart';
import 'package:learning_pwa/models/assessment_engine/mock_exam_blueprint.dart';
import 'package:learning_pwa/models/assessment_engine/mock_exam_session.dart';
import 'package:learning_pwa/models/assessment_item.dart';
import 'package:learning_pwa/models/user_concept_state.dart';
import 'package:learning_pwa/services/assessment/exam_evaluation_service.dart';

void main() {
  group('Phase E: ExamEvaluationService & Pedagogical Safeguards Tests', () {
    final now = DateTime.now();

    final domains = [
      const DomainWeightConstraint(
        domainId: 'dom-1',
        domainCode: '1.0',
        domainTitle: 'General Security Concepts',
        weight: 0.50,
      ),
      const DomainWeightConstraint(
        domainId: 'dom-2',
        domainCode: '2.0',
        domainTitle: 'Threats & Vulnerabilities',
        weight: 0.50,
      ),
    ];

    final blueprint = MockExamBlueprint(
      targetVersionId: 'tv-test',
      examCode: 'SY0-701',
      title: 'CompTIA Security+ Blueprint',
      officialPassingScore: 750,
      officialScoreScale: '100-900',
      timeLimitMinutes: 90,
      domainWeights: domains,
    );

    final items = [
      // 1. Single Choice in Domain 1
      AssessmentItem(
        id: 'item-sc-1',
        interactionType: AssessmentInteractionType.singleChoice,
        prompt: 'Which security goal ensures data has not been modified?',
        responseSpec: {
          'options': ['Confidentiality', 'Integrity', 'Availability'],
        },
        scoringSpec: {'correct_index': 1},
        explanation: 'Integrity prevents unauthorized alteration of information.',
        difficulty: 'beginner',
        createdAt: now,
        updatedAt: now,
      ),
      // 2. Multi-Select in Domain 1
      AssessmentItem(
        id: 'item-ms-1',
        interactionType: AssessmentInteractionType.multiSelect,
        prompt: 'Select two core components of AAA:',
        responseSpec: {
          'options': ['Authentication', 'Authorization', 'Anonymity'],
        },
        scoringSpec: {
          'scoring_method': 'all_or_nothing',
          'correct_indices': [0, 1],
        },
        explanation: 'Authentication and Authorization are pillars of AAA.',
        difficulty: 'intermediate',
        createdAt: now,
        updatedAt: now,
      ),
      // 3. Ordered Response in Domain 2
      AssessmentItem(
        id: 'item-or-1',
        interactionType: AssessmentInteractionType.orderedResponse,
        prompt: 'Place incident response phases in chronological sequence:',
        responseSpec: {
          'items': ['Preparation', 'Detection', 'Containment'],
        },
        scoringSpec: {
          'correct_order': [0, 1, 2],
        },
        explanation: 'Standard NIST SP 800-61 sequence.',
        difficulty: 'intermediate',
        createdAt: now,
        updatedAt: now,
      ),
      // 4. Matching in Domain 2
      AssessmentItem(
        id: 'item-match-1',
        interactionType: AssessmentInteractionType.matching,
        prompt: 'Match each protocol with its default port:',
        responseSpec: {
          'left_items': ['HTTPS', 'SSH'],
          'right_items': ['443', '22'],
        },
        scoringSpec: {
          'correct_pairs': {'HTTPS': '443', 'SSH': '22'},
        },
        explanation: 'Standard IANA port assignments.',
        difficulty: 'advanced',
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final service = ExamEvaluationService();

    test('Evaluates perfect exam (100%) and generates correct scaled score and evidence', () {
      final session = MockExamSession(
        id: 'sess-1',
        blueprint: blueprint,
        items: items,
        itemDomainMap: {
          'item-sc-1': '1.0',
          'item-ms-1': '1.0',
          'item-or-1': '2.0',
          'item-match-1': '2.0',
        },
        userResponses: {
          'item-sc-1': 1,
          'item-ms-1': [0, 1],
          'item-or-1': ['Preparation', 'Detection', 'Containment'],
          'item-match-1': {'HTTPS': '443', 'SSH': '22'},
        },
        startedAt: now,
        timeLimit: const Duration(minutes: 90),
        elapsedSeconds: 2400,
        status: ExamSessionStatus.completed,
      );

      final report = service.evaluateExam(session);

      expect(report.readinessEstimate.practiceScorePercentage, equals(100.0));
      expect(report.readinessEstimate.estimatedScaledScore, equals(900));
      expect(report.readinessEstimate.readinessBand, equals(TargetReadinessBand.strongCoverage));
      expect(report.readinessEstimate.correctCount, equals(4));
      expect(report.readinessEstimate.incorrectCount, equals(0));

      // Verify domain diagnostics
      expect(report.domainDiagnostics.length, equals(2));
      for (final diag in report.domainDiagnostics) {
        expect(diag.percentage, equals(100.0));
        expect(diag.evidenceLevel, equals(DomainEvidenceLevel.strongEvidence));
      }

      // Section 15.6 Safeguard Verification: Must NOT claim "Mastered"
      expect(report.readinessEstimate.readinessHeadline.toLowerCase(), isNot(contains('mastered')));
      expect(report.readinessEstimate.readinessSummary.toLowerCase(), isNot(contains('mastered')));

      // Official facts preserved separately
      expect(report.officialFacts.publishedPassingScore, equals(750));
      expect(report.officialFacts.scoreScale, equals('100-900'));
    });

    test('Evaluates exam with missed questions and creates concept remediation recommendations', () {
      final session = MockExamSession(
        id: 'sess-2',
        blueprint: blueprint,
        items: items,
        itemDomainMap: {
          'item-sc-1': '1.0',
          'item-ms-1': '1.0',
          'item-or-1': '2.0',
          'item-match-1': '2.0',
        },
        itemConceptMap: {
          'item-sc-1': ['concept-cia-triad'],
          'item-ms-1': ['concept-aaa-auth'],
          'item-or-1': ['concept-incident-resp'],
          'item-match-1': ['concept-network-ports'],
        },
        userResponses: {
          'item-sc-1': 1, // Correct
          'item-ms-1': [0, 2], // Incorrect
          'item-or-1': ['Containment', 'Preparation', 'Detection'], // Incorrect
          'item-match-1': {'HTTPS': '443', 'SSH': '22'}, // Correct
        },
        startedAt: now,
        timeLimit: const Duration(minutes: 90),
        elapsedSeconds: 3000,
        status: ExamSessionStatus.completed,
      );

      final report = service.evaluateExam(session);

      expect(report.readinessEstimate.practiceScorePercentage, equals(50.0));
      // 100 + (0.5 * 800) = 500
      expect(report.readinessEstimate.estimatedScaledScore, equals(500));
      expect(report.readinessEstimate.readinessBand, equals(TargetReadinessBand.needsReinforcement));
      expect(report.readinessEstimate.correctCount, equals(2));
      expect(report.readinessEstimate.incorrectCount, equals(2));

      // Domain diagnostics should reflect 50% for both domains
      for (final diag in report.domainDiagnostics) {
        expect(diag.percentage, equals(50.0));
        expect(diag.evidenceLevel, equals(DomainEvidenceLevel.needsReinforcement));
      }

      // Remediation recommendations should include the missed concepts
      expect(report.remediationRecommendations.isNotEmpty, isTrue);
      final missedConceptIds = report.remediationRecommendations.map((r) => r.conceptId).toList();
      expect(missedConceptIds, contains('concept-aaa-auth'));
      expect(missedConceptIds, contains('concept-incident-resp'));
    });

    test('Evaluates partial credit in multi-select (SATA)', () {
      final sataItem = AssessmentItem(
        id: 'item-sata-partial',
        interactionType: AssessmentInteractionType.multiSelect,
        prompt: 'Select all three protocols using TLS:',
        responseSpec: {
          'options': ['HTTPS', 'FTPS', 'SMTPS', 'Telnet'],
        },
        scoringSpec: {
          'scoring_method': 'partial_credit',
          'correct_indices': [0, 1, 2],
        },
        difficulty: 'intermediate',
        createdAt: now,
        updatedAt: now,
      );

      final singleItemSession = MockExamSession(
        id: 'sess-sata',
        blueprint: blueprint,
        items: [sataItem],
        itemDomainMap: {'item-sata-partial': '1.0'},
        userResponses: {
          // Selected 2 out of 3 correct, no incorrect
          'item-sata-partial': [0, 1],
        },
        startedAt: now,
        timeLimit: const Duration(minutes: 90),
        status: ExamSessionStatus.completed,
      );

      final report = service.evaluateExam(singleItemSession);

      // Score: 2/3 = ~66.7%
      expect(report.readinessEstimate.partialCount, equals(1));
      expect(report.readinessEstimate.correctCount, equals(0));
      expect(report.readinessEstimate.practiceScorePercentage, closeTo(66.6, 1.0));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/assessment_engine/mock_exam_blueprint.dart';
import 'package:learning_pwa/models/assessment_engine/mock_exam_session.dart';
import 'package:learning_pwa/services/assessment/clep_simulation_service.dart';

void main() {
  group('ClepSimulationService End-to-End Journey & Security Tests', () {
    const algTargetVersionId = 'tv-clep-alg-2026';
    const psychTargetVersionId = 'tv-clep-psy-2026';
    const sampleAttemptId = 'att-alg-11223344-5566-7788';

    // Mock RPC backend simulating authoritative database responses
    late List<Map<String, dynamic>> recordedCalls;

    Future<dynamic> mockRpcTransport(String rpcName, Map<String, dynamic> params) async {
      recordedCalls.add({'rpc': rpcName, 'params': params});

      if (rpcName == 'clep_issue_simulation_exam') {
        final versionId = params['p_target_version_id'] as String?;
        if (versionId == 'invalid-version') {
          throw Exception('Target version not found');
        }
        if (versionId == 'already-attempted') {
          throw Exception('Simulation attempt already exists for this exam version');
        }

        return {
          'attempt_id': sampleAttemptId,
          'target_version_id': versionId,
          'total_questions': 60,
          'time_limit_minutes': 90,
          'issued_at': '2026-11-08T14:00:00.000Z',
          'expires_at': '2026-11-08T15:35:00.000Z',
          'questions': List.generate(60, (index) {
            String domainCode;
            if (index < 15) {
              domainCode = '1.0';
            } else if (index < 30) {
              domainCode = '2.0';
            } else if (index < 48) {
              domainCode = '3.0';
            } else {
              domainCode = '4.0';
            }
            return {
              'id': 'alg-sim-item-${index + 1}',
              'interaction_type': 'single_choice',
              'prompt': 'Question #${index + 1}: Algebraic Operations & Functions',
              'domain_code': domainCode,
              'response_spec': {
                'options': ['Choice A', 'Choice B', 'Choice C', 'Choice D'],
              },
              'metadata': {
                'bank': 'simulation_exam',
                'item_role': 'clep_simulation_pool',
                'domain_code': domainCode,
              },
              'concept_ids': ['concept-${(index % 20) + 1}'],
            };
          }),
        };
      }

      if (rpcName == 'clep_get_active_simulation_attempt') {
        final versionId = params['p_target_version_id'] as String?;
        if (versionId == 'active-version') {
          return {
            'has_active_attempt': true,
            'attempt_id': sampleAttemptId,
            'issued_at': '2026-11-08T14:00:00.000Z',
            'expires_at': '2026-11-08T15:35:00.000Z',
            'seconds_remaining': 2400,
            'total_questions': 60,
          };
        }
        return {'has_active_attempt': false};
      }

      if (rpcName == 'clep_recover_simulation_exam') {
        final versionId = params['p_target_version_id'] as String?;
        return {
          'attempt_id': sampleAttemptId,
          'target_version_id': versionId,
          'total_questions': 60,
          'time_limit_minutes': 90,
          'issued_at': '2026-11-08T14:00:00.000Z',
          'expires_at': '2026-11-08T15:35:00.000Z',
          'seconds_remaining': 2400,
          'is_resumed': true,
          'questions': List.generate(60, (index) {
            final dCode = index < 15 ? '1.0' : (index < 30 ? '2.0' : (index < 48 ? '3.0' : '4.0'));
            return {
              'id': 'alg-sim-item-${index + 1}',
              'interaction_type': 'single_choice',
              'prompt': 'Question #${index + 1}: Algebraic Operations & Functions',
              'domain_code': dCode,
              'response_spec': {
                'options': ['Choice A', 'Choice B', 'Choice C', 'Choice D'],
              },
              'metadata': {
                'bank': 'simulation_exam',
                'item_role': 'clep_simulation_pool',
                'domain_code': dCode,
              },
              'concept_ids': ['concept-${(index % 20) + 1}'],
            };
          }),
        };
      }

      if (rpcName == 'clep_submit_simulation_exam') {
        final attemptId = params['p_attempt_id'] as String?;
        final responses = params['p_responses'] as Map<String, dynamic>?;

        if (attemptId != sampleAttemptId) {
          throw Exception('Simulation attempt not found');
        }
        if (responses == null || responses.isEmpty) {
          throw Exception('Cannot submit empty responses');
        }

        // Return EXACT database contract from clep_submit_simulation_exam:
        // Uses raw_score, accuracy_percentage, readiness_indicator, results with domain_code
        // OMITTING correct_count, percentage, readiness, answered_count
        return {
          'attempt_id': attemptId,
          'target_version_id': algTargetVersionId,
          'raw_score': 48,
          'total_questions': 60,
          'accuracy_percentage': 80.0,
          'time_spent_seconds': 4320,
          'readiness_indicator': 'Competitive Diagnostic Standing',
          'is_calibrated_clep_score': false,
          'scoring_disclaimer': 'Diagnostic score estimate only. Official College Board scaled scores require statistical equating and proprietary form calibration.',
          'results': responses.entries.map((e) {
            final idx = int.tryParse(e.key.replaceAll('alg-sim-item-', '')) ?? 1;
            String domainCode;
            if (idx <= 15) {
              domainCode = '1.0';
            } else if (idx <= 30) {
              domainCode = '2.0';
            } else if (idx <= 48) {
              domainCode = '3.0';
            } else {
              domainCode = '4.0';
            }
            return {
              'id': e.key,
              'answered': true,
              'is_correct': true,
              'user_answer': e.value,
              'domain_code': domainCode,
              'concept_ids': ['concept-1'],
            };
          }).toList(),
        };
      }

      throw UnimplementedError('Unknown RPC: $rpcName');
    }

    setUp(() {
      recordedCalls = [];
    });

    test('issues protected College Algebra simulation session with calculator capability and private answer keys', () async {
      final service = ClepSimulationService(transport: mockRpcTransport);

      final session = await service.issueSimulationExam(
        targetVersionId: algTargetVersionId,
        examCode: 'CLEP-ALG',
        examTitle: 'CLEP College Algebra Examination',
        allowedTools: const {'calculator'},
        domainWeights: const [
          DomainWeightConstraint(domainId: 'd1', domainCode: '1.0', domainTitle: 'Algebraic Operations', weight: 0.25),
          DomainWeightConstraint(domainId: 'd2', domainCode: '2.0', domainTitle: 'Equations and Inequalities', weight: 0.25),
          DomainWeightConstraint(domainId: 'd3', domainCode: '3.0', domainTitle: 'Functions and Their Properties', weight: 0.30),
          DomainWeightConstraint(domainId: 'd4', domainCode: '4.0', domainTitle: 'Number Systems and Operations', weight: 0.20),
        ],
      );

      // 1. Verify RPC call parameters
      expect(recordedCalls.length, equals(1));
      expect(recordedCalls.first['rpc'], equals('clep_issue_simulation_exam'));
      expect(recordedCalls.first['params']['p_target_version_id'], equals(algTargetVersionId));

      // 2. Verify session construction
      expect(session.id, equals(sampleAttemptId));
      expect(session.status, equals(ExamSessionStatus.inProgress));
      expect(session.timeLimit, equals(const Duration(minutes: 90)));
      expect(session.items.length, equals(60));
      expect(session.isProtectedSimulation, isTrue);

      // 3. Tool Policy: Calculator MUST be permitted for College Algebra
      expect(session.blueprint.allowsCalculator, isTrue);
      expect(session.blueprint.allowedTools, contains('calculator'));

      // 4. Privacy Invariant: Scoring keys and explanations MUST be withheld on client items
      for (final item in session.items) {
        expect(item.hasLocalScoringSpec, isFalse, reason: 'Protected keys must never be sent to learner');
        expect(item.explanation, isNull, reason: 'Protected item explanations must remain server-side');
        expect(item.responseSpec['options'], isNotNull);
        expect((item.responseSpec['options'] as List).length, equals(4));
      }
    });

    test('issues Introductory Psychology simulation without calculator tool capability', () async {
      final service = ClepSimulationService(transport: mockRpcTransport);

      final session = await service.issueSimulationExam(
        targetVersionId: psychTargetVersionId,
        examCode: 'CLEP-PSY',
        examTitle: 'CLEP Introductory Psychology Examination',
        allowedTools: const {}, // No calculator for Psychology
      );

      expect(session.blueprint.allowsCalculator, isFalse);
      expect(session.blueprint.allowedTools, isEmpty);
      expect(session.isProtectedSimulation, isTrue);
    });

    test('submits student exam responses against real database contract and receives diagnostic report without leaked keys', () async {
      final service = ClepSimulationService(transport: mockRpcTransport);

      final session = await service.issueSimulationExam(
        targetVersionId: algTargetVersionId,
        examCode: 'CLEP-ALG',
        examTitle: 'CLEP College Algebra Examination',
        allowedTools: const {'calculator'},
        domainWeights: const [
          DomainWeightConstraint(domainId: 'd1', domainCode: '1.0', domainTitle: 'Algebraic Operations', weight: 0.25),
          DomainWeightConstraint(domainId: 'd2', domainCode: '2.0', domainTitle: 'Equations and Inequalities', weight: 0.25),
          DomainWeightConstraint(domainId: 'd3', domainCode: '3.0', domainTitle: 'Functions and Their Properties', weight: 0.30),
          DomainWeightConstraint(domainId: 'd4', domainCode: '4.0', domainTitle: 'Number Systems and Operations', weight: 0.20),
        ],
      );

      // Simulate student answering 60 questions
      final responses = <String, dynamic>{};
      for (int i = 1; i <= 60; i++) {
        responses['alg-sim-item-$i'] = i % 4;
      }
      final answeredSession = session.copyWith(userResponses: responses);

      recordedCalls.clear();
      final result = await service.submitSimulationExam(
        attemptId: sampleAttemptId,
        responses: responses,
      );

      // 1. Verify RPC submission call
      expect(recordedCalls.length, equals(1));
      expect(recordedCalls.first['rpc'], equals('clep_submit_simulation_exam'));
      expect(recordedCalls.first['params']['p_attempt_id'], equals(sampleAttemptId));
      expect(recordedCalls.first['params']['p_responses'], equals(responses));

      // 2. Verify score and readiness mapped from exact database contract fields
      expect(result.attemptId, equals(sampleAttemptId));
      expect(result.rawScore, equals(48));
      expect(result.correctCount, equals(48));
      expect(result.accuracyPercentage, equals(80.0));
      expect(result.percentage, equals(80.0));
      expect(result.readinessIndicator, equals('Competitive Diagnostic Standing'));
      expect(result.readiness, equals('Competitive Diagnostic Standing'));
      expect(result.totalQuestions, equals(60));
      expect(result.answeredCount, equals(60));
      expect(result.timeSpentSeconds, equals(4320));
      expect(result.isCalibratedClepScore, isFalse);
      expect(result.scoringDisclaimer, contains('Diagnostic score estimate only'));

      // 3. Verify item results contain only correctness and user answer, never answer keys
      for (final itemRes in result.itemResults) {
        expect(itemRes['is_correct'], isNotNull);
        expect(itemRes['user_answer'], isNotNull);
        expect(itemRes.containsKey('scoring_spec'), isFalse);
        expect(itemRes.containsKey('correct_index'), isFalse);
        expect(itemRes.containsKey('explanation'), isFalse);
      }

      // 4. Verify conversion into ExamDiagnosticReport with exact 4-domain psychometric breakdown
      final report = result.toDiagnosticReport(answeredSession);
      expect(report.sessionId, equals(sampleAttemptId));
      expect(report.readinessEstimate.practiceScorePercentage, equals(80.0));
      expect(report.readinessEstimate.correctCount, equals(48));
      expect(report.readinessEstimate.totalQuestions, equals(60));
      expect(report.readinessEstimate.unansweredCount, equals(0));
      expect(report.readinessEstimate.readinessHeadline, equals('Competitive Diagnostic Standing'));
      expect(report.domainDiagnostics.length, equals(4));

      // Domain 1.0 (Algebraic operations - 25%): 15 questions
      expect(report.domainDiagnostics[0].domainCode, equals('1.0'));
      expect(report.domainDiagnostics[0].totalQuestions, equals(15));
      expect(report.domainDiagnostics[0].domainWeight, equals(0.25));

      // Domain 2.0 (Equations and inequalities - 25%): 15 questions
      expect(report.domainDiagnostics[1].domainCode, equals('2.0'));
      expect(report.domainDiagnostics[1].totalQuestions, equals(15));
      expect(report.domainDiagnostics[1].domainWeight, equals(0.25));

      // Domain 3.0 (Functions and their properties - 30%): 18 questions
      expect(report.domainDiagnostics[2].domainCode, equals('3.0'));
      expect(report.domainDiagnostics[2].totalQuestions, equals(18));
      expect(report.domainDiagnostics[2].domainWeight, equals(0.30));

      // Domain 4.0 (Number systems and operations - 20%): 12 questions
      expect(report.domainDiagnostics[3].domainCode, equals('4.0'));
      expect(report.domainDiagnostics[3].totalQuestions, equals(12));
      expect(report.domainDiagnostics[3].domainWeight, equals(0.20));

      expect(
        report.domainDiagnostics.fold<int>(0, (sum, d) => sum + d.totalQuestions),
        equals(60),
        reason: 'Sum of domain questions must equal 60 total simulation items',
      );

      // 5. Verify confidentiality in scored items: correctResponse and explanation must remain null
      expect(report.scoredItems.length, equals(60));
      for (final scoredItem in report.scoredItems) {
        expect(scoredItem.correctResponse, isNull, reason: 'Answer keys must never be revealed in simulation reports');
        expect(scoredItem.explanation, isNull, reason: 'Explanations must never be revealed in simulation reports');
      }
    });

    test('rejects empty submission prior to network call', () async {
      final service = ClepSimulationService(transport: mockRpcTransport);

      expect(
        () => service.submitSimulationExam(attemptId: sampleAttemptId, responses: {}),
        throwsA(isA<ClepSimulationException>()),
      );
      expect(recordedCalls, isEmpty, reason: 'Empty submission must fail fast without RPC call');
    });

    test('properly maps server errors to ClepSimulationException', () async {
      final service = ClepSimulationService(transport: mockRpcTransport);

      expect(
        () => service.issueSimulationExam(
          targetVersionId: 'already-attempted',
          examCode: 'CLEP-ALG',
          examTitle: 'College Algebra',
        ),
        throwsA(isA<ClepSimulationException>()),
      );
    });

    test('recovers active in-progress simulation attempt with remaining time', () async {
      final service = ClepSimulationService(transport: mockRpcTransport);

      final session = await service.recoverSimulationExam(
        targetVersionId: algTargetVersionId,
        examCode: 'CLEP-ALG',
        examTitle: 'College Algebra',
        allowedTools: {'calculator'},
      );

      expect(session.id, equals(sampleAttemptId));
      expect(session.isProtectedSimulation, isTrue);
      expect(session.timeLimit.inSeconds, equals(2400));
      expect(session.blueprint.metadata['is_resumed'], isTrue);
      expect(session.items.length, equals(60));
    });

    test('checks active simulation attempt status correctly', () async {
      final service = ClepSimulationService(transport: mockRpcTransport);

      final active = await service.getActiveSimulationAttempt('active-version');
      expect(active.hasActiveAttempt, isTrue);
      expect(active.attemptId, equals(sampleAttemptId));
      expect(active.secondsRemaining, equals(2400));

      final inactive = await service.getActiveSimulationAttempt('inactive-version');
      expect(inactive.hasActiveAttempt, isFalse);
    });

    test('throws ClepSimulationException with MISSING_DOMAIN_CODE when question has no domain_code', () async {
      Future<dynamic> mockBadDomainTransport(String rpcName, Map<String, dynamic> params) async {
        return {
          'attempt_id': 'bad-att-1',
          'target_version_id': 'v1',
          'total_questions': 1,
          'time_limit_minutes': 90,
          'issued_at': '2026-11-08T14:00:00.000Z',
          'questions': [
            {
              'id': 'bad-q-1',
              'interaction_type': 'single_choice',
              'prompt': 'Prompt without domain code',
              'response_spec': {'options': ['A', 'B']},
              'metadata': {},
            }
          ],
        };
      }

      final badService = ClepSimulationService(transport: mockBadDomainTransport);
      expect(
        () => badService.issueSimulationExam(
          targetVersionId: 'v1',
          examCode: 'CLEP-ALG',
          examTitle: 'Algebra',
        ),
        throwsA(predicate((e) =>
            e is ClepSimulationException && e.code == 'MISSING_DOMAIN_CODE')),
      );
    });
  });
}

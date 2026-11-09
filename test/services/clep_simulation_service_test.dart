import 'package:flutter_test/flutter_test.dart';
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
          'questions': List.generate(60, (index) => {
            'id': 'alg-sim-item-${index + 1}',
            'interaction_type': 'single_choice',
            'prompt': 'Question #${index + 1}: Algebraic Operations & Functions',
            'response_spec': {
              'options': ['Choice A', 'Choice B', 'Choice C', 'Choice D'],
            },
            'metadata': {
              'bank': 'simulation_exam',
              'item_role': 'clep_simulation_pool',
            },
            'concept_ids': ['concept-${(index % 20) + 1}'],
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

        // Grade confidentially: 48 correct out of 60 = 80.0%
        return {
          'attempt_id': attemptId,
          'total_questions': 60,
          'answered_count': responses.length,
          'correct_count': 48,
          'percentage': 80.0,
          'readiness': 'Competitive Diagnostic Standing',
          'time_spent_seconds': 4320,
          'results': responses.entries.map((e) => {
            'id': e.key,
            'answered': true,
            'is_correct': true,
            'user_answer': e.value,
            'concept_ids': ['concept-1'],
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
    });

    test('submits student exam responses and receives confidential diagnostic score without leaked keys', () async {
      final service = ClepSimulationService(transport: mockRpcTransport);

      // Simulate student answering 60 questions
      final responses = <String, dynamic>{};
      for (int i = 1; i <= 60; i++) {
        responses['alg-sim-item-$i'] = i % 4;
      }

      final result = await service.submitSimulationExam(
        attemptId: sampleAttemptId,
        responses: responses,
      );

      // 1. Verify RPC submission call
      expect(recordedCalls.length, equals(1));
      expect(recordedCalls.first['rpc'], equals('clep_submit_simulation_exam'));
      expect(recordedCalls.first['params']['p_attempt_id'], equals(sampleAttemptId));
      expect(recordedCalls.first['params']['p_responses'], equals(responses));

      // 2. Verify score and readiness diagnostics
      expect(result.attemptId, equals(sampleAttemptId));
      expect(result.totalQuestions, equals(60));
      expect(result.answeredCount, equals(60));
      expect(result.correctCount, equals(48));
      expect(result.percentage, equals(80.0));
      expect(result.readiness, equals('Competitive Diagnostic Standing'));
      expect(result.timeSpentSeconds, equals(4320));

      // 3. Verify item results contain only correctness and user answer, never answer keys
      for (final itemRes in result.itemResults) {
        expect(itemRes['is_correct'], isNotNull);
        expect(itemRes['user_answer'], isNotNull);
        expect(itemRes.containsKey('scoring_spec'), isFalse);
        expect(itemRes.containsKey('correct_index'), isFalse);
        expect(itemRes.containsKey('explanation'), isFalse);
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
  });
}

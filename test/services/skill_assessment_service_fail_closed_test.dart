import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/skill_assessment_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../test_helpers/fake_supabase_client.dart';

/// Fail-closed behavior of the skill assessment client: it must never invent
/// verification, never call grading/attempt RPCs without a signed-in user,
/// and must surface server failures instead of producing a result.
void main() {
  final user = User(
    id: 'user-1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-11-14T00:00:00Z',
  );

  Map<String, dynamic> attemptRow() => {
        'id': 'attempt-1',
        'assessment_id': 'assess-1',
        'user_id': 'user-1',
        'started_at': DateTime.now()
            .subtract(const Duration(minutes: 3))
            .toIso8601String(),
        'answers': {'q1': 1},
        'skill_assessments': {
          'id': 'assess-1',
          'skill_id': 'skill-1',
          'title': 'Fractions',
        },
      };

  Map<String, dynamic> gradeResponse({bool includeVerified = true}) => {
        'attempt_id': 'attempt-1',
        'score': 0,
        'correct_count': 0,
        'passed': false,
        if (includeVerified) 'is_verified': true,
        'previous_level': 3,
        'new_level': 3,
        'question_results': [
          {
            'question_id': 'q1',
            'question_text': '1/2 + 1/4 = ?',
            'options': ['3/4', '2/6'],
            'user_answer': 1,
            'correct_answer': 0,
            'is_correct': false,
          },
        ],
      };

  late FakeSupabaseClient client;
  late List<String> rpcCalls;

  setUp(() {
    client = FakeSupabaseClient(currentUser: user);
    rpcCalls = [];
  });

  test('a grading response without is_verified is treated as NOT verified',
      () async {
    client.setTableData('assessment_attempts', [attemptRow()]);
    client.rpcHandler = (fn, {params}) {
      rpcCalls.add(fn);
      return gradeResponse(includeVerified: false);
    };

    final result =
        await SkillAssessmentService(supabase: client).completeAssessment('attempt-1');

    expect(rpcCalls, ['submit_and_grade_assessment']);
    expect(result.attempt.isVerified, isFalse);
    expect(result.passed, isFalse);
    expect(result.questionResults.single.isCorrect, isFalse);
  });

  test('score, pass and per-question correctness come only from the server',
      () async {
    client.setTableData('assessment_attempts', [attemptRow()]);
    client.rpcHandler = (fn, {params}) => {
          ...gradeResponse(),
          'score': 40,
          'correct_count': 2,
          'passed': false,
        };

    final result =
        await SkillAssessmentService(supabase: client).completeAssessment('attempt-1');

    expect(result.attempt.score, 40);
    expect(result.attempt.correctCount, 2);
    expect(result.passed, isFalse);
    // totalQuestions is the number of server-graded questions, not a client count.
    expect(result.attempt.totalQuestions, 1);
  });

  test('signed-out learners cannot start or complete an attempt (no RPC sent)',
      () async {
    client = FakeSupabaseClient();
    client.rpcHandler = (fn, {params}) {
      rpcCalls.add(fn);
      return null;
    };
    final service = SkillAssessmentService(supabase: client);

    await expectLater(service.startAssessment('assess-1'), throwsException);
    await expectLater(service.completeAssessment('attempt-1'), throwsException);
    expect(rpcCalls, isEmpty);
  });

  test('startAssessment opens the attempt through the server RPC', () async {
    client.rpcHandler = (fn, {params}) {
      rpcCalls.add(fn);
      expect(params, {'p_assessment_id': 'assess-1'});
      return {
        'id': 'attempt-9',
        'assessment_id': 'assess-1',
        'user_id': 'user-1',
        'started_at': '2026-11-14T10:00:00Z',
      };
    };

    final attempt =
        await SkillAssessmentService(supabase: client).startAssessment('assess-1');

    expect(rpcCalls, ['start_assessment_attempt']);
    expect(attempt.id, 'attempt-9');
    expect(attempt.isVerified, isFalse);
  });

  test('a grading failure propagates instead of producing a result', () async {
    client.setTableData('assessment_attempts', [attemptRow()]);
    client.rpcHandler =
        (fn, {params}) => throw const PostgrestException(message: 'grading unavailable');

    await expectLater(
      SkillAssessmentService(supabase: client).completeAssessment('attempt-1'),
      throwsA(isA<PostgrestException>()),
    );
  });
}

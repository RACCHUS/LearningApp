import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/skill_assessment_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../test_helpers/fake_supabase_client.dart';

void main() {
  group('SkillAssessmentService Server-Side Grading & Answer Withholding', () {
    late FakeSupabaseClient fakeClient;
    late SkillAssessmentService service;

    final testUser = User(
      id: 'user-test-123',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
    );

    setUp(() {
      fakeClient = FakeSupabaseClient(currentUser: testUser);
      service = SkillAssessmentService(supabase: fakeClient);
    });

    test('getQuestionsForTaking invokes get_assessment_questions_for_taking and withholds answer key', () async {
      fakeClient.rpcHandler = (fn, {params}) {
        if (fn == 'get_assessment_questions_for_taking') {
          expect(params?['p_assessment_id'], equals('assess-1'));
          return [
            {
              'id': 'q1',
              'assessment_id': 'assess-1',
              'question_text': 'What is Flutter?',
              'options': ['Framework', 'Database', 'Operating System', 'Language'],
              'order_index': 0,
            },
            {
              'id': 'q2',
              'assessment_id': 'assess-1',
              'question_text': 'What language does Flutter use?',
              'options': ['Java', 'Dart', 'Kotlin', 'Swift'],
              'order_index': 1,
            },
          ];
        }
        return null;
      };

      final questions = await service.getQuestionsForTaking('assess-1');

      expect(questions, hasLength(2));
      expect(questions[0].questionText, equals('What is Flutter?'));
      expect(questions[0].options, hasLength(4));
      // Correct answer and explanation must be null when taking assessment
      expect(questions[0].correctAnswer, isNull);
      expect(questions[0].explanation, isNull);

      expect(questions[1].questionText, equals('What language does Flutter use?'));
      expect(questions[1].correctAnswer, isNull);
    });

    test('completeAssessment invokes submit_and_grade_assessment and returns verified result', () async {
      fakeClient.setTableData('assessment_attempts', [
        {
          'id': 'attempt-1',
          'assessment_id': 'assess-1',
          'user_id': 'user-test-123',
          'started_at': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
          'answers': {'q1': 0, 'q2': 1},
          'created_at': DateTime.now().toIso8601String(),
          'skill_assessments': {
            'id': 'assess-1',
            'skill_id': 'skill-1',
            'title': 'Flutter Fundamentals',
            'passing_score': 70,
            'created_at': DateTime.now().toIso8601String(),
            'skills': {
              'id': 'skill-1',
              'name': 'Flutter',
              'slug': 'flutter',
              'created_at': DateTime.now().toIso8601String(),
            },
          },
        }
      ]);

      fakeClient.rpcHandler = (fn, {params}) {
        if (fn == 'submit_and_grade_assessment') {
          expect(params?['p_assessment_id'], equals('assess-1'));
          expect(params?['p_answers'], equals({'q1': 0, 'q2': 1}));
          expect(params?['p_attempt_id'], equals('attempt-1'));
          return {
            'attempt_id': 'attempt-1',
            'assessment_id': 'assess-1',
            'skill_id': 'skill-1',
            'score': 100,
            'correct_count': 2,
            'total_questions': 2,
            'passing_score': 70,
            'passed': true,
            'is_verified': true,
            'previous_level': 20,
            'new_level': 45,
            'question_results': [
              {
                'question_id': 'q1',
                'question_text': 'What is Flutter?',
                'options': ['Framework', 'Database', 'Operating System', 'Language'],
                'user_answer': 0,
                'correct_answer': 0,
                'is_correct': true,
                'explanation': 'Flutter is an open-source UI software development kit.',
              },
              {
                'question_id': 'q2',
                'question_text': 'What language does Flutter use?',
                'options': ['Java', 'Dart', 'Kotlin', 'Swift'],
                'user_answer': 1,
                'correct_answer': 1,
                'is_correct': true,
                'explanation': 'Flutter apps are written in Dart.',
              },
            ],
          };
        }
        return null;
      };

      final result = await service.completeAssessment('attempt-1');

      expect(result.attempt.score, equals(100));
      expect(result.attempt.correctCount, equals(2));
      expect(result.attempt.isVerified, isTrue);
      expect(result.passed, isTrue);
      expect(result.previousLevel, equals(20));
      expect(result.newLevel, equals(45));
      expect(result.leveledUp, isTrue);
      expect(result.levelChange, equals(25));

      // Question results now include explanations and correct answers for review
      expect(result.questionResults, hasLength(2));
      expect(result.questionResults[0].isCorrect, isTrue);
      expect(result.questionResults[0].question.correctAnswer, equals(0));
      expect(result.questionResults[0].question.explanation, contains('Flutter is an open-source UI'));
    });

    test('completeAssessment on failing attempt withholds correct answers, explanations, and per-question correctness', () async {
      fakeClient.setTableData('assessment_attempts', [
        {
          'id': 'attempt-fail',
          'assessment_id': 'assess-1',
          'user_id': 'user-test-123',
          'started_at': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
          'answers': {'q1': 1, 'q2': 0},
          'created_at': DateTime.now().toIso8601String(),
          'skill_assessments': {
            'id': 'assess-1',
            'skill_id': 'skill-1',
            'title': 'Flutter Fundamentals',
            'passing_score': 70,
            'created_at': DateTime.now().toIso8601String(),
            'skills': {
              'id': 'skill-1',
              'name': 'Flutter',
              'slug': 'flutter',
              'created_at': DateTime.now().toIso8601String(),
            },
          },
        }
      ]);

      fakeClient.rpcHandler = (fn, {params}) {
        if (fn == 'submit_and_grade_assessment') {
          return {
            'attempt_id': 'attempt-fail',
            'assessment_id': 'assess-1',
            'skill_id': 'skill-1',
            'score': 50,
            'correct_count': 1,
            'total_questions': 2,
            'passing_score': 70,
            'passed': false,
            'is_verified': true,
            'previous_level': 20,
            'new_level': 20,
            'question_results': [
              {
                'question_id': 'q1',
                'question_text': 'What is Flutter?',
                'options': ['Framework', 'Database', 'Operating System', 'Language'],
                'user_answer': 1,
                'correct_answer': null,
                'is_correct': null,
                'explanation': null,
              },
              {
                'question_id': 'q2',
                'question_text': 'What language does Flutter use?',
                'options': ['Java', 'Dart', 'Kotlin', 'Swift'],
                'user_answer': 0,
                'correct_answer': null,
                'is_correct': null,
                'explanation': null,
              },
            ],
          };
        }
        return null;
      };

      final result = await service.completeAssessment('attempt-fail');

      expect(result.attempt.score, equals(50));
      expect(result.passed, isFalse);
      expect(result.questionResults, hasLength(2));
      expect(result.questionResults[0].question.correctAnswer, isNull);
      expect(result.questionResults[0].question.explanation, isNull);
      expect(result.questionResults[0].isCorrect, isFalse);
      expect(result.questionResults[1].question.correctAnswer, isNull);
      expect(result.questionResults[1].question.explanation, isNull);
      expect(result.questionResults[1].isCorrect, isFalse);
    });
  });
}

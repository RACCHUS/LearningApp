import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/assessment_engine/mock_exam_blueprint.dart';
import 'package:learning_pwa/models/assessment_engine/mock_exam_session.dart';
import 'package:learning_pwa/models/assessment_item.dart';
import 'package:learning_pwa/providers/assessment_engine_provider.dart';
import 'package:learning_pwa/services/assessment/assessment_grading_service.dart';
import 'package:learning_pwa/services/assessment/exam_evaluation_service.dart';

final _now = DateTime.utc(2026, 11, 8);

AssessmentItem _item(
  String id, {
  Map<String, dynamic> scoringSpec = const {},
  AssessmentInteractionType type = AssessmentInteractionType.singleChoice,
}) =>
    AssessmentItem(
      id: id,
      interactionType: type,
      prompt: 'Prompt $id',
      responseSpec: const {
        'options': ['A', 'B', 'C'],
      },
      scoringSpec: scoringSpec,
      createdAt: _now,
      updatedAt: _now,
    );

Map<String, dynamic> _graded(String id, Map<String, dynamic> spec) => {
      'item_id': id,
      'is_correct': true,
      'is_partial': false,
      'score': 1,
      'scoring_spec': spec,
      'explanation': 'Because $id.',
    };

void main() {
  group('AssessmentGradingService.revealScoring', () {
    test('never calls the server when every key is already local', () async {
      var calls = 0;
      final service = AssessmentGradingService(transport: (_) async {
        calls++;
        return [];
      });
      final items = [
        _item('a', scoringSpec: const {'correct_index': 1}),
      ];

      final result = await service.revealScoring(items, {'a': 1});

      expect(calls, 0);
      expect(result, same(items));
    });

    test('sends only answered hidden items and merges the revealed keys',
        () async {
      List<Map<String, dynamic>>? sent;
      final service = AssessmentGradingService(transport: (payload) async {
        sent = payload;
        return [
          _graded('hidden', const {'correct_index': 2}),
        ];
      });

      final result = await service.revealScoring(
        [
          _item('local', scoringSpec: const {'correct_index': 0}),
          _item('hidden'),
          _item('unanswered'),
        ],
        {'local': 0, 'hidden': 2},
      );

      expect(sent, [
        {'item_id': 'hidden', 'response': 2},
      ]);
      expect(result[1].scoringSpec, {'correct_index': 2});
      expect(result[1].explanation, 'Because hidden.');
      expect(result[2].scoringSpec, isEmpty);
      expect(
        ExamEvaluationService().evaluateItemResponse(result[1], 2).isCorrect,
        isTrue,
      );
    });

    test('reveals unanswered items with a placeholder that cannot score',
        () async {
      List<Map<String, dynamic>>? sent;
      final service = AssessmentGradingService(transport: (payload) async {
        sent = payload;
        return [];
      });

      await service.revealScoring(
        [_item('skipped')],
        const {},
        revealUnanswered: true,
      );

      expect(sent, [
        {
          'item_id': 'skipped',
          'response': AssessmentGradingService.unansweredPlaceholder,
        },
      ]);
    });

    test('leaves items the server refuses unrevealed so they fail closed',
        () async {
      final service = AssessmentGradingService(transport: (_) async => [
            {'item_id': 'protected', 'error': 'not_available'},
          ]);

      final result = await service.revealScoring(
        [_item('protected')],
        {'protected': 0},
      );

      expect(result.single.scoringSpec, isEmpty);
      expect(
        ExamEvaluationService()
            .evaluateItemResponse(result.single, 0)
            .scoreEarned,
        0,
      );
    });

    test('splits large submissions into server-sized batches', () async {
      final batchSizes = <int>[];
      final service = AssessmentGradingService(transport: (payload) async {
        batchSizes.add(payload.length);
        return [];
      });
      final items = List.generate(260, (i) => _item('i$i'));

      await service.revealScoring(items, {for (final i in items) i.id: 0});

      expect(batchSizes, [250, 10]);
    });
  });

  group('AssessmentGradingService.revealForResponse', () {
    test('throws a learner-facing error when the item cannot be graded',
        () async {
      final service = AssessmentGradingService(transport: (_) async => [
            {'item_id': 'x', 'error': 'not_available'},
          ]);

      expect(
        service.revealForResponse(_item('x'), 0),
        throwsA(isA<AssessmentGradingException>()),
      );
    });

    test('wraps transport failures without leaking raw errors', () async {
      final service = AssessmentGradingService(
        transport: (_) async => throw Exception('socket: secret-host'),
      );

      await expectLater(
        service.revealForResponse(_item('x'), 0),
        throwsA(
          isA<AssessmentGradingException>().having(
            (e) => e.message,
            'message',
            isNot(contains('secret-host')),
          ),
        ),
      );
    });
  });

  group('ExamSessionNotifier with hidden answer keys', () {
    MockExamSession session() => MockExamSession(
          id: 'hidden-keys',
          blueprint: const MockExamBlueprint(
            targetVersionId: 'v',
            examCode: 'PRACTICE',
            title: 'Practice',
            domainWeights: [
              DomainWeightConstraint(
                domainId: 'd',
                domainCode: '1',
                domainTitle: 'Domain',
                weight: 1,
              ),
            ],
          ),
          items: [_item('q1'), _item('q2')],
          itemDomainMap: const {'q1': '1', 'q2': '1'},
          startedAt: _now,
          timeLimit: const Duration(minutes: 5),
        );

    test('grades from server-revealed keys and shows them for skipped items',
        () async {
      final notifier = ExamSessionNotifier(
        ExamEvaluationService(),
        gradingService: AssessmentGradingService(transport: (payload) async {
          return payload
              .map((entry) =>
                  _graded(entry['item_id'] as String, const {'correct_index': 1}))
              .toList();
        }),
      );
      addTearDown(notifier.dispose);

      notifier.startSession(session());
      notifier.recordResponse('q1', 1);
      final report = await notifier.submitExam();

      expect(report, isNotNull);
      final q1 = report!.scoredItems.firstWhere((s) => s.itemId == 'q1');
      final q2 = report.scoredItems.firstWhere((s) => s.itemId == 'q2');
      expect(q1.isCorrect, isTrue);
      expect(q1.explanation, 'Because q1.');
      expect(q2.userResponse, isNull);
      expect(q2.correctResponse, 1);
    });

    test('a grading failure can be retried by submitting again', () async {
      var fail = true;
      final notifier = ExamSessionNotifier(
        ExamEvaluationService(),
        gradingService: AssessmentGradingService(transport: (payload) async {
          if (fail) throw Exception('offline');
          return payload
              .map((entry) =>
                  _graded(entry['item_id'] as String, const {'correct_index': 0}))
              .toList();
        }),
      );
      addTearDown(notifier.dispose);

      notifier.startSession(session());
      notifier.recordResponse('q1', 0);

      await expectLater(
        notifier.submitExam(),
        throwsA(isA<AssessmentGradingException>()),
      );
      fail = false;
      final report = await notifier.submitExam();
      expect(report, isNotNull);
      expect(await notifier.submitExam(), isNull);
    });
  });
}

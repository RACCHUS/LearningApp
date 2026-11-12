// PR-0a addendum: remaining answer-key defaults found by the P0-light audit
// (docs/content_intelligence/00_BASELINE_AND_COMPATIBILITY_AUDIT.md §A.2).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/answer_key.dart';
import 'package:learning_pwa/models/community/family_abe_pilot.dart';
import 'package:learning_pwa/services/ai/generated_content_models.dart';
import 'package:learning_pwa/services/ai/item_evaluator.dart';

Map<String, dynamic> _aiItem(Object? correctIndex) => {
  'prompt': 'What is the minimum slope away from the foundation?',
  'options': [
    '6 inches within 10 feet',
    '2 inches within 10 feet',
    '12 inches within 10 feet',
    '4 inches within 10 feet',
  ],
  if (correctIndex != null) 'correct_index': correctIndex,
  'explanation': 'Option A is correct per FBC §1804.4.',
  'source_citation': 'Florida Building Code (Building) §1804.4',
};

void main() {
  group('GeneratedAssessmentItem.fromJson', () {
    test('explicit 0 is kept', () {
      final item = GeneratedAssessmentItem.fromJson(_aiItem(0));
      expect(item.correctIndex, 0);
      expect(item.hasValidKey, isTrue);
    });

    for (final bad in <Object?>[null, '1', 1.5, 4, -1]) {
      test('invalid key $bad becomes unscorable, not option 0', () {
        final item = GeneratedAssessmentItem.fromJson(_aiItem(bad));
        expect(item.correctIndex, AnswerKey.unscorableIndex);
        expect(item.hasValidKey, isFalse);
        expect(item.correctAnswer, isEmpty);
      });
    }

    test('ItemEvaluator never passes an item without a valid key', () {
      final evaluator = ItemEvaluator();
      expect(
        evaluator
            .evaluate(GeneratedAssessmentItem.fromJson(_aiItem(0)))
            .isPassed,
        isTrue,
      );
      final report = evaluator.evaluate(
        GeneratedAssessmentItem.fromJson(_aiItem(null)),
      );
      expect(report.isPassed, isFalse);
      expect(
        report.violations.map((v) => v.rule),
        contains('answer_key_invalid'),
      );
    });
  });

  group('DiagnosticQuestion.fromJson', () {
    Map<String, dynamic> json(Object? key) => {
      'id': 'd1',
      'prompt': '2 + 2?',
      'options': ['3', '4', '5'],
      if (key != null) 'correct_index': key,
      'concept_key': 'add',
      'explanation': '',
    };

    test('valid keys, including 0, are kept', () {
      expect(DiagnosticQuestion.fromJson(json(0)).correctIndex, 0);
      expect(DiagnosticQuestion.fromJson(json(1)).correctIndex, 1);
    });

    test('missing or out-of-range keys are unscorable', () {
      expect(
        DiagnosticQuestion.fromJson(json(null)).correctIndex,
        AnswerKey.unscorableIndex,
      );
      expect(
        DiagnosticQuestion.fromJson(json(3)).correctIndex,
        AnswerKey.unscorableIndex,
      );
    });
  });
}

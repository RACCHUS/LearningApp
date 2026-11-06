import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/ai/generated_content_models.dart';
import 'package:learning_pwa/services/ai/item_evaluator.dart';

void main() {
  late ItemEvaluator evaluator;

  setUp(() {
    evaluator = ItemEvaluator();
  });

  group('ItemEvaluator Psychometric & Haladyna Rules Tests', () {
    test('passes valid, grounded Haladyna-compliant item', () {
      const validItem = GeneratedAssessmentItem(
        prompt:
            'What is the minimum slope away from the foundation required by the Florida Building Code?',
        options: [
          '6 inches within 10 feet',
          '2 inches within 10 feet',
          '12 inches within 10 feet',
          '4 inches within 10 feet',
        ],
        correctIndex: 0,
        explanation:
            'Option A is correct: FBC §1804.4 requires 6 inches fall in the first 10 feet. Options B, C, and D are incorrect slopes.',
        sourceCitation: 'Florida Building Code (Building) §1804.4',
        bloomLevel: 'apply',
        difficulty: 'intermediate',
        expectedSeconds: 60,
      );

      final report = evaluator.evaluate(validItem);
      expect(report.isPassed, isTrue);
      expect(report.hasAnswerLeak, isFalse);
      expect(report.hasCitation, isTrue);
      expect(report.isLengthBalanced, isTrue);
      expect(report.violations, isEmpty);
      expect(report.score, greaterThanOrEqualTo(85.0));
    });

    test('detects answer leakage when stem contains the exact key', () {
      const leakyItem = GeneratedAssessmentItem(
        prompt:
            'Why is 6 inches fall within 10 feet required for building foundations under the Florida Building Code?',
        options: [
          '6 inches fall within 10 feet',
          '2 inches fall within 10 feet',
          '12 inches fall within 10 feet',
          '4 inches fall within 10 feet',
        ],
        correctIndex: 0,
        explanation: 'FBC §1804.4 states that 6 inches fall ensures proper drainage.',
        sourceCitation: 'FBC §1804.4',
      );

      final report = evaluator.evaluate(leakyItem);
      expect(report.isPassed, isFalse);
      expect(report.hasAnswerLeak, isTrue);
      expect(
        report.violations.any((v) => v.rule == 'answer_leakage'),
        isTrue,
      );
    });

    test('detects distractor length imbalance (giveaway longest option)', () {
      const unbalancedItem = GeneratedAssessmentItem(
        prompt: 'What constitutes an insurable interest in property under Florida insurance statutes?',
        options: [
          'This is the comprehensive economic interest in the safety or preservation of the subject from loss or destruction that must exist at the time of loss under F.S. 627.405',
          'Legal title only',
          'Any occupancy',
          'Family relationship',
        ],
        correctIndex: 0,
        explanation: 'F.S. 627.405 defines insurable interest economically. Other options are insufficient.',
        sourceCitation: 'Florida Statutes §627.405',
      );

      final report = evaluator.evaluate(unbalancedItem);
      expect(report.isLengthBalanced, isFalse);
      expect(report.lengthRatio, greaterThan(1.5));
      expect(
        report.violations.any((v) => v.rule == 'distractor_length_balance'),
        isTrue,
      );
    });

    test('detects negative stems ("NOT", "EXCEPT")', () {
      const negativeItem = GeneratedAssessmentItem(
        prompt: 'Which of the following is NOT a required element of a Florida construction lien?',
        options: [
          'Social security number of contractor',
          'Name of the owner',
          'Description of the property',
          'Total contract price',
        ],
        correctIndex: 0,
        explanation: 'F.S. 713.08 does not require a social security number on the claim of lien.',
        sourceCitation: 'Florida Statutes §713.08',
      );

      final report = evaluator.evaluate(negativeItem);
      expect(
        report.violations.any((v) => v.rule == 'negative_stem'),
        isTrue,
      );
    });

    test('flags "all of the above" and "none of the above" options', () {
      const badOptionsItem = GeneratedAssessmentItem(
        prompt: 'What materials may be used for continuous footing forms?',
        options: [
          'Trench earth where soil is stable',
          'Dimensional lumber or plywood',
          'Prefabricated steel forms',
          'All of the above',
        ],
        correctIndex: 3,
        explanation: 'All listed form materials are permissible under standard FBC specifications.',
        sourceCitation: 'FBC §1809.5',
      );

      final report = evaluator.evaluate(badOptionsItem);
      expect(
        report.violations.any((v) => v.rule == 'haladyna_all_none_above'),
        isTrue,
      );
    });

    test('fails item when citation is missing or placeholder', () {
      const ungroundedItem = GeneratedAssessmentItem(
        prompt: 'What is the required thickness of residential concrete slab-on-grade?',
        options: [
          '3.5 inches',
          '1.5 inches',
          '2.0 inches',
          '5.5 inches',
        ],
        correctIndex: 0,
        explanation: 'Standard residential slab thickness is 3.5 inches.',
        sourceCitation: 'N/A',
      );

      final report = evaluator.evaluate(ungroundedItem);
      expect(report.isPassed, isFalse);
      expect(report.hasCitation, isFalse);
      expect(
        report.violations.any((v) => v.rule == 'source_citation_missing'),
        isTrue,
      );
    });
  });
}


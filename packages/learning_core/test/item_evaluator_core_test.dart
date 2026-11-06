import 'package:learning_core/learning_core.dart';
import 'package:test/test.dart';

void main() {
  group('ItemEvaluatorCore', () {
    late ItemEvaluatorCore evaluator;

    setUp(() {
      evaluator = ItemEvaluatorCore();
    });

    test('valid Haladyna item passes with high score and zero errors', () {
      const validItem = AssessmentItemCore(
        id: 'item-001',
        stem: 'Under OSHA 1926.501, at what minimum height above a lower level must fall protection be provided for construction workers?',
        sourceRef: 'OSHA 29 CFR 1926.501(b)(1): "Each employee on a walking/working surface with an unprotected side or edge 6 feet or more..."',
        options: [
          AssessmentOptionCore(text: '4 feet above floor level', isCorrect: false),
          AssessmentOptionCore(text: '6 feet above floor level', isCorrect: true),
          AssessmentOptionCore(text: '8 feet above floor level', isCorrect: false),
          AssessmentOptionCore(text: '10 feet above floor level', isCorrect: false),
        ],
      );

      final report = evaluator.evaluate(validItem);

      expect(report.passed, isTrue);
      expect(report.score, greaterThanOrEqualTo(90.0));
      expect(report.violations.where((v) => v.severity == 'error'), isEmpty);
    });

    test('flags missing source citation as error', () {
      const itemWithoutSource = AssessmentItemCore(
        id: 'item-002',
        stem: 'What is the standard residential stud spacing in North American framing?',
        sourceRef: null,
        options: [
          AssessmentOptionCore(text: '12 inches on center', isCorrect: false),
          AssessmentOptionCore(text: '16 inches on center', isCorrect: true),
          AssessmentOptionCore(text: '20 inches on center', isCorrect: false),
          AssessmentOptionCore(text: '24 inches on center', isCorrect: false),
        ],
      );

      final report = evaluator.evaluate(itemWithoutSource);

      expect(report.passed, isFalse);
      expect(report.violations.any((v) => v.rule == 'source_grounding'), isTrue);
    });

    test('flags absolute modifiers like "all of the above"', () {
      const itemWithAllOfTheAbove = AssessmentItemCore(
        id: 'item-003',
        stem: 'Which PPE elements are required when operating a concrete masonry saw?',
        sourceRef: 'OSHA 1926.102 eye protection standard.',
        options: [
          AssessmentOptionCore(text: 'Safety glasses with side shields', isCorrect: false),
          AssessmentOptionCore(text: 'N95 particulate respirator mask', isCorrect: false),
          AssessmentOptionCore(text: 'Hearing protection earplugs', isCorrect: false),
          AssessmentOptionCore(text: 'All of the above safety items', isCorrect: true),
        ],
      );

      final report = evaluator.evaluate(itemWithAllOfTheAbove);

      expect(report.violations.any((v) => v.rule == 'absolute_modifier'), isTrue);
    });

    test('flags distractor length imbalance when ratio exceeds 1.5x', () {
      const unbalancedItem = AssessmentItemCore(
        id: 'item-004',
        stem: 'What is the required primary egress path width in commercial hallways?',
        sourceRef: 'NFPA 101 Life Safety Code Table 7.3.4.1.',
        options: [
          AssessmentOptionCore(text: '36 inches', isCorrect: false),
          AssessmentOptionCore(
            text: '44 inches unobstructed clearance along the entire designated travel pathway from door to stairwell',
            isCorrect: true,
          ),
          AssessmentOptionCore(text: '48 inches', isCorrect: false),
          AssessmentOptionCore(text: '54 inches', isCorrect: false),
        ],
      );

      final report = evaluator.evaluate(unbalancedItem);

      expect(report.violations.any((v) => v.rule == 'length_balance'), isTrue);
    });
  });
}


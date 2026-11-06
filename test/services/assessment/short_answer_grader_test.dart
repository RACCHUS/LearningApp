import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/question_content.dart';
import 'package:learning_pwa/services/assessment/short_answer_grader.dart';

QuestionContent q({
  List<String> options = const ['Paris'],
  int correctAnswer = 0,
  List<String>? accepted,
  String? method,
  double? tolerance,
}) => QuestionContent(
  id: 'q',
  lessonId: 'l',
  order: 0,
  questionText: 'Q?',
  options: options,
  correctAnswer: correctAnswer,
  questionType: 'short_answer',
  acceptedAnswers: accepted,
  gradingMethod: method,
  numericTolerance: tolerance,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  group('legacy single answer (normalized text by default)', () {
    final legacy = q();

    test('case, whitespace and end punctuation are ignored', () {
      for (final r in ['Paris', 'paris', '  PARIS ', 'Paris.', 'paris!']) {
        expect(ShortAnswerGrader.grade(legacy, r).isCorrect, isTrue, reason: r);
      }
    });

    test('spelling still counts; no fuzzy matching', () {
      for (final r in ['Pariss', 'Pari', 'Paris France']) {
        expect(
          ShortAnswerGrader.grade(legacy, r).isCorrect,
          isFalse,
          reason: r,
        );
      }
    });

    test('blank answer is rejected with a prompt', () {
      final g = ShortAnswerGrader.grade(legacy, '   ');
      expect(g.isCorrect, isFalse);
      expect(g.feedback, 'Type an answer first.');
    });

    test(
      'feedback explains a normalized match and shows the answer on a miss',
      () {
        expect(ShortAnswerGrader.grade(legacy, 'Paris').feedback, 'Correct!');
        expect(
          ShortAnswerGrader.grade(legacy, 'paris.').feedback,
          contains('Accepted as "Paris"'),
        );
        final miss = ShortAnswerGrader.grade(legacy, 'Rome').feedback;
        expect(miss, startsWith('Incorrect. Answer: Paris.'));
        expect(miss, contains('spelling and accents count'));
      },
    );
  });

  test('accents are preserved by normalized text', () {
    final fr = q(accepted: ['café']);
    expect(ShortAnswerGrader.grade(fr, 'Café').isCorrect, isTrue);
    expect(ShortAnswerGrader.grade(fr, 'cafe').isCorrect, isFalse);
  });

  test('accepted answers cover synonyms and are listed on a miss', () {
    final syn = q(accepted: ['big', 'large', 'huge']);
    expect(ShortAnswerGrader.grade(syn, 'Large').isCorrect, isTrue);
    expect(ShortAnswerGrader.grade(syn, 'huge').matchedAnswer, 'huge');
    expect(
      ShortAnswerGrader.grade(syn, 'massive').feedback,
      contains('Also accepted: large, huge.'),
    );
  });

  test('declared accepted answers take precedence over options', () {
    final g = q(options: ['old key'], accepted: ['new key']);
    expect(ShortAnswerGrader.grade(g, 'old key').isCorrect, isFalse);
    expect(ShortAnswerGrader.grade(g, 'new key').isCorrect, isTrue);
  });

  test('exact method respects case', () {
    final chem = q(accepted: ['NaCl'], method: 'exact');
    expect(ShortAnswerGrader.grade(chem, ' NaCl ').isCorrect, isTrue);
    expect(ShortAnswerGrader.grade(chem, 'nacl').isCorrect, isFalse);
    expect(
      ShortAnswerGrader.grade(chem, 'nacl').feedback,
      contains('must match exactly'),
    );
  });

  group('numeric', () {
    test('exact number with formatting variants', () {
      final n = q(accepted: ['1000'], method: 'numeric');
      for (final r in ['1000', '1,000', '1000.0', ' +1000 ']) {
        expect(ShortAnswerGrader.grade(n, r).isCorrect, isTrue, reason: r);
      }
      expect(ShortAnswerGrader.grade(n, '1001').isCorrect, isFalse);
    });

    test('tolerance is inclusive and explained', () {
      final pi = q(accepted: ['3.14'], method: 'numeric', tolerance: 0.01);
      expect(ShortAnswerGrader.grade(pi, '3.15').isCorrect, isTrue);
      expect(ShortAnswerGrader.grade(pi, '3.13').isCorrect, isTrue);
      expect(ShortAnswerGrader.grade(pi, '3.16').isCorrect, isFalse);
      expect(ShortAnswerGrader.grade(pi, '3.15').feedback, contains('±0.01'));
    });

    test('ambiguous or non-numeric responses are rejected, not guessed', () {
      final n = q(accepted: ['12'], method: 'numeric');
      for (final r in ['twelve', '12 cm', '1.2.3', '12-13']) {
        final g = ShortAnswerGrader.grade(n, r);
        expect(g.isCorrect, isFalse, reason: r);
      }
      expect(
        ShortAnswerGrader.grade(n, 'twelve').feedback,
        contains('Enter a number'),
      );
    });
  });

  test('grading method names parse leniently and default to normalized', () {
    expect(
      ShortAnswerGradingMethod.parse('normalized_text'),
      ShortAnswerGradingMethod.normalizedText,
    );
    expect(
      ShortAnswerGradingMethod.parse('Numeric'),
      ShortAnswerGradingMethod.numeric,
    );
    expect(
      ShortAnswerGradingMethod.parse(null),
      ShortAnswerGradingMethod.normalizedText,
    );
  });
}

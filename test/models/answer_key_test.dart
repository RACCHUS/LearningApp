// PR-0a answer/scoring integrity (master plan v2.6 §14.8, Appendix G.2/H.3).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/core/errors/model_parse_exception.dart';
import 'package:learning_pwa/models/answer_key.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/question_content.dart';
import 'package:learning_pwa/services/assessment/short_answer_grader.dart';

const _four = ['Alpha', 'Beta', 'Gamma', 'Delta'];

QuestionContent _content({
  required List<String> options,
  required int correct,
  String? type,
  List<String>? accepted,
}) => QuestionContent(
  id: 'q',
  lessonId: 'l',
  order: 0,
  questionText: 'Q?',
  options: options,
  correctAnswer: correct,
  questionType: type,
  acceptedAnswers: accepted,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  group('AnswerKey.fromIndex — plan Appendix G.2 truth table', () {
    test('explicit 0 with four distinct options is valid', () {
      final r = AnswerKey.fromIndex(0, _four);
      expect(r.isScorable, isTrue);
      expect(r.index, 0);
    });

    test('"0" string is rejected on the strict path', () {
      expect(
        AnswerKey.fromIndex('0', _four).status,
        AnswerKeyStatus.invalidKey,
      );
    });

    test('"2" string is accepted only by the explicit legacy adapter', () {
      final r = AnswerKey.fromIndex('2', _four, allowLegacyDecimalString: true);
      expect(r.index, 2);
      expect(
        AnswerKey.fromIndex(
          '2.0',
          _four,
          allowLegacyDecimalString: true,
        ).isScorable,
        isFalse,
      );
      expect(
        AnswerKey.fromIndex(
          'abc',
          _four,
          allowLegacyDecimalString: true,
        ).status,
        AnswerKeyStatus.invalidKey,
      );
    });

    test('null is missing_key', () {
      expect(
        AnswerKey.fromIndex(null, _four).status,
        AnswerKeyStatus.missingKey,
      );
    });

    test('4 with four options and -1 are out of range', () {
      expect(AnswerKey.fromIndex(4, _four).status, AnswerKeyStatus.invalidKey);
      expect(AnswerKey.fromIndex(-1, _four).status, AnswerKeyStatus.invalidKey);
    });

    test('bool and fractional values are rejected', () {
      expect(AnswerKey.fromIndex(true, _four).isScorable, isFalse);
      expect(AnswerKey.fromIndex(1.0, _four).isScorable, isFalse);
    });

    test('a key pointing at a blank placeholder option is invalid', () {
      expect(
        AnswerKey.fromIndex(0, ['', '', '', '']).status,
        AnswerKeyStatus.invalidKey,
      );
    });

    test('a key whose option text is duplicated is ambiguous', () {
      expect(
        AnswerKey.fromIndex(0, ['Same', 'same ', 'Other']).status,
        AnswerKeyStatus.ambiguousOptions,
      );
      // Duplicates elsewhere do not affect a distinct keyed option.
      expect(
        AnswerKey.fromIndex(2, ['Same', 'same', 'Other']).isScorable,
        isTrue,
      );
    });

    test('empty option list is invalid', () {
      expect(AnswerKey.fromIndex(0, const []).isScorable, isFalse);
    });

    test('storedIndexOrUnscorable never fabricates 0', () {
      expect(
        AnswerKey.storedIndexOrUnscorable(null, _four),
        AnswerKey.unscorableIndex,
      );
      expect(
        AnswerKey.storedIndexOrUnscorable('x', _four),
        AnswerKey.unscorableIndex,
      );
      expect(
        AnswerKey.storedIndexOrUnscorable(9, _four),
        AnswerKey.unscorableIndex,
      );
      expect(AnswerKey.storedIndexOrUnscorable(0, _four), 0);
      expect(AnswerKey.storedIndexOrUnscorable('3', _four), 3);
    });
  });

  group('AnswerKey.fromText — unique normalized exact match only', () {
    test('case, surrounding and repeated whitespace are normalized', () {
      expect(AnswerKey.fromText('  beta ', _four).index, 1);
      expect(AnswerKey.fromText('New  York', ['New York', 'Boston']).index, 0);
    });

    test('empty and whitespace are missing_key', () {
      expect(AnswerKey.fromText('', _four).status, AnswerKeyStatus.missingKey);
      expect(
        AnswerKey.fromText('   ', _four).status,
        AnswerKeyStatus.missingKey,
      );
    });

    test('substring containment is not a match', () {
      expect(
        AnswerKey.fromText('10', ['100%', '50%']).status,
        AnswerKeyStatus.invalidKey,
      );
      expect(AnswerKey.fromText('Alpha Beta', _four).isScorable, isFalse);
    });

    test('matching two normalized-equal options is ambiguous', () {
      expect(
        AnswerKey.fromText('x', ['X', 'x', 'y']).status,
        AnswerKeyStatus.ambiguousOptions,
      );
    });
  });

  group('TrueFalseKey — semantics from labels, not position', () {
    test('[True, False] index 0 means true', () {
      expect(TrueFalseKey.correctValue(['True', 'False'], 0), isTrue);
      expect(TrueFalseKey.correctValue(['True', 'False'], 1), isFalse);
    });

    test('[False, True] index 0 means false', () {
      expect(TrueFalseKey.correctValue(['False', 'True'], 0), isFalse);
      expect(TrueFalseKey.correctValue(['False', 'True'], 1), isTrue);
    });

    test('duplicate, unknown or missing labels are unscorable', () {
      expect(TrueFalseKey.correctValue(['True', 'True'], 0), isNull);
      expect(TrueFalseKey.correctValue(['Yes', 'Maybe'], 0), isNull);
      expect(TrueFalseKey.correctValue(const [], 0), isNull);
      expect(TrueFalseKey.correctValue(['True', 'False'], 2), isNull);
      expect(TrueFalseKey.correctValue(['True', 'False'], -1), isNull);
    });

    test('indexFor writes the right index for either order', () {
      expect(TrueFalseKey.indexFor(['True', 'False'], true), 0);
      expect(TrueFalseKey.indexFor(['False', 'True'], true), 1);
    });

    test('QuestionContent exposes the label-derived value', () {
      expect(
        _content(
          options: ['True', 'False'],
          correct: 0,
          type: 'true_false',
        ).trueFalseCorrectValue,
        isTrue,
      );
      final bad = _content(
        options: ['True', 'True'],
        correct: 0,
        type: 'true_false',
      );
      expect(bad.trueFalseCorrectValue, isNull);
      expect(bad.hasScorableIndexKey, isFalse);
    });
  });

  group('Question.fromJson', () {
    Map<String, dynamic> row(Object? correct) => {
      'id': 'q1',
      'question_text': 'Q?',
      'options': _four,
      'correct_answer': correct,
      'type': 'mcq',
      'created_by': 'u',
      'created_at': '2026-01-01T00:00:00Z',
    };

    test('missing correct_answer still raises the required-field error', () {
      expect(
        () => Question.fromJson(row(null)),
        throwsA(
          isA<ModelParseException>().having(
            (e) => e.fields,
            'fields',
            contains('correct_answer'),
          ),
        ),
      );
    });

    test('present malformed value throws instead of becoming 0', () {
      expect(
        () => Question.fromJson(row('banana')),
        throwsA(isA<ModelParseException>()),
      );
      expect(
        () => Question.fromJson(row(1.5)),
        throwsA(isA<ModelParseException>()),
      );
    });

    test('valid 0 and legacy digit string are preserved', () {
      expect(Question.fromJson(row(0)).correctAnswer, 0);
      expect(Question.fromJson(row('2')).correctAnswer, 2);
    });
  });

  group('ShortAnswerGrader legacy fallback', () {
    test('declared accepted answers are used', () {
      final q = _content(
        options: const [],
        correct: 0,
        type: 'short_answer',
        accepted: ['4'],
      );
      expect(ShortAnswerGrader.grade(q, '4').isCorrect, isTrue);
    });

    test('unscorable index is never consumed as an accepted answer', () {
      final q = _content(
        options: const ['', 'x'],
        correct: 0,
        type: 'short_answer',
      );
      expect(ShortAnswerGrader.acceptedAnswersFor(q), isEmpty);
      expect(ShortAnswerGrader.grade(q, '').isCorrect, isFalse);
      final sentinel = _content(
        options: const ['Paris'],
        correct: AnswerKey.unscorableIndex,
        type: 'short_answer',
      );
      expect(ShortAnswerGrader.acceptedAnswersFor(sentinel), isEmpty);
      expect(ShortAnswerGrader.grade(sentinel, 'Paris').isCorrect, isFalse);
    });

    test('a genuinely valid legacy keyed option is still accepted', () {
      final q = _content(
        options: const ['Paris'],
        correct: 0,
        type: 'short_answer',
      );
      expect(ShortAnswerGrader.grade(q, 'paris').isCorrect, isTrue);
    });
  });
}

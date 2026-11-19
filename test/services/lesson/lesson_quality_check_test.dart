import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/lesson/lesson_quality_check.dart';

Map<String, dynamic> lesson({
  String description = 'Learn how VLOOKUP finds values in a table column.',
  List<Map<String, dynamic>>? terms,
  List<Map<String, dynamic>>? concepts,
  List<Map<String, dynamic>>? questions,
}) => {
  'title': 'VLOOKUP',
  'description': description,
  'terms':
      terms ??
      [
        {
          'term': 'Lookup value',
          'definition': 'The value VLOOKUP searches for in the first column.',
        },
      ],
  'concepts':
      concepts ??
      [
        {
          'concept_text': 'How VLOOKUP searches',
          'example_text':
              'VLOOKUP looks down the first column of the range, then moves '
              'right to the column index and returns that cell.',
        },
      ],
  'questions':
      questions ??
      [
        q('Which column is returned for index 3 in D:F?', ['D', 'E', 'F'], 2),
        q('What does FALSE ask for?', [
          'Exact match',
          'Sorted data',
          'Approximate',
        ], 0),
      ],
};

Map<String, dynamic> q(
  String stem,
  List<String> options,
  int key, {
  String explanation = 'Because the index counts from the first column.',
}) => {
  'question': stem,
  'options': options,
  'correct_answer': key,
  'explanation': explanation,
};

List<String> tips(Map<String, dynamic> l) =>
    LessonQualityCheck.check(l).map((t) => t.toString()).toList();

void main() {
  test('a sound lesson gets no tips', () {
    expect(tips(lesson()), isEmpty);
  });

  test('lesson-level gaps are pointed out', () {
    final t = tips(
      lesson(description: '', terms: [], concepts: [], questions: []),
    );
    expect(t.join('\n'), contains('description'));
    expect(t.join('\n'), contains('nothing to read'));
    expect(t.join('\n'), contains('at least 2 questions'));
  });

  test('giveaway options, missing explanations and too few options', () {
    final t = tips(
      lesson(
        questions: [
          q('Pick one', ['Yes', 'All of the above', 'No'], 0, explanation: ''),
          q('Pick another', ['Yes', 'No'], 1),
        ],
      ),
    ).join('\n');
    expect(t, contains('Question 1: Avoid "all/none of the above"'));
    expect(t, contains('Question 1: Add a short explanation'));
    expect(t, contains('Question 2: Only 2 options'));
  });

  test('a much longer right answer and an answer in the question', () {
    final t = tips(
      lesson(
        questions: [
          q('Why use FALSE?', [
            'Speed',
            'Because it returns an exact match or #N/A when missing',
            'Color',
          ], 1),
          q('Is the lookup value the value VLOOKUP searches for?', [
            'the value VLOOKUP searches for',
            'a column number',
            'a range',
          ], 0),
        ],
      ),
    ).join('\n');
    expect(t, contains('Question 1: The right answer is much longer'));
    expect(t, contains('Question 2: The question already contains'));
  });

  test('repeated questions and terms, short text', () {
    final t = tips(
      lesson(
        terms: [
          {'term': 'Range', 'definition': 'Cells.'},
          {'term': 'range', 'definition': 'A rectangular block of cells.'},
        ],
        concepts: [
          {'concept_text': 'Short', 'example_text': 'Too short.'},
        ],
        questions: [
          q('What is a range?', ['A', 'B', 'C'], 0),
          q('What is a  range?', ['A', 'B', 'C'], 1),
        ],
      ),
    ).join('\n');
    expect(t, contains('Term 1: The definition is very short'));
    expect(t, contains('Term 2: Repeats term 1'));
    expect(t, contains('Explanation 1: This is very short'));
    expect(t, contains('Question 2: Repeats question 1'));
  });

  test('unscorable keys do not crash the check', () {
    expect(
      () => LessonQualityCheck.check(
        lesson(
          questions: [
            {
              'question': 'x',
              'options': ['a', 'b', 'c'],
              'correct_answer': null,
            },
          ],
        ),
      ),
      returnsNormally,
    );
  });
}

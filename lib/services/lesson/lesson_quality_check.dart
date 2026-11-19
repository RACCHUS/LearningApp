import 'package:learning_pwa/models/answer_key.dart';

/// One improvement hint. Hints never block an import or change content.
class QualityTip {
  const QualityTip(this.where, this.message);

  /// Human-readable location, e.g. "Question 2".
  final String where;
  final String message;

  @override
  String toString() => '$where: $message';
}

/// Deterministic quality hints for a normalized personal lesson (the
/// `personal` map the importer saves: `terms`, `concepts`, `questions`).
/// It checks for common weaknesses in AI-written lessons that a learner
/// would otherwise only notice later. No model calls; every hint explains
/// what to ask the AI to change.
class LessonQualityCheck {
  const LessonQualityCheck._();

  static final _giveaway = RegExp(
    r'^(all|none|both|neither) (of the above|of these|a and b|of them)\b',
    caseSensitive: false,
  );

  static List<QualityTip> check(Map<String, dynamic> lesson) {
    final tips = <QualityTip>[];
    final description = (lesson['description'] ?? '').toString().trim();
    final terms = _maps(lesson['terms']);
    final concepts = _maps(lesson['concepts']);
    final questions = _maps(lesson['questions']);

    if (description.length < 30) {
      tips.add(
        const QualityTip(
          'Lesson',
          'Add a one- or two-sentence description of what learners will '
              'be able to do.',
        ),
      );
    }
    if (concepts.isEmpty && terms.isEmpty) {
      tips.add(
        const QualityTip(
          'Lesson',
          'There is nothing to read before the questions. Ask for at least '
              'one explanation.',
        ),
      );
    }
    if (questions.length < 2) {
      tips.add(
        const QualityTip(
          'Lesson',
          'Add at least 2 questions so learners can check they understood.',
        ),
      );
    }

    for (final (i, c) in concepts.indexed) {
      final body = (c['example_text'] ?? '').toString().trim();
      if (body.length < 80) {
        tips.add(
          QualityTip(
            'Explanation ${i + 1}',
            'This is very short. Ask for a few sentences and an example.',
          ),
        );
      }
    }

    final seenTerms = <String, int>{};
    for (final (i, t) in terms.indexed) {
      final name = AnswerKey.normalize((t['term'] ?? '').toString());
      final def = (t['definition'] ?? '').toString().trim();
      if (def.length < 15) {
        tips.add(
          QualityTip(
            'Term ${i + 1}',
            'The definition is very short. Ask for a clear one-sentence '
                'definition.',
          ),
        );
      }
      final earlier = seenTerms[name];
      if (name.isNotEmpty && earlier != null) {
        tips.add(QualityTip('Term ${i + 1}', 'Repeats term ${earlier + 1}.'));
      } else {
        seenTerms[name] = i;
      }
    }

    final seenStems = <String, int>{};
    for (final (i, q) in questions.indexed) {
      final where = 'Question ${i + 1}';
      final stem = (q['question'] ?? q['question_text'] ?? '').toString();
      final options = q['options'] is List
          ? [for (final o in q['options'] as List) '$o']
          : const <String>[];
      final key = q['correct_answer'];
      final explanation = (q['explanation'] ?? '').toString().trim();

      final norm = AnswerKey.normalize(stem);
      final earlier = seenStems[norm];
      if (norm.isNotEmpty && earlier != null) {
        tips.add(QualityTip(where, 'Repeats question ${earlier + 1}.'));
      } else {
        seenStems[norm] = i;
      }
      if (options.isEmpty) continue; // short answer: options not used

      if (options.length < 3) {
        tips.add(
          QualityTip(
            where,
            'Only ${options.length} options. Use 3 to 5 so guessing is '
            'harder.',
          ),
        );
      }
      if (options.any((o) => _giveaway.hasMatch(o.trim()))) {
        tips.add(
          QualityTip(
            where,
            'Avoid "all/none of the above": it can often be answered '
            'without knowing the topic.',
          ),
        );
      }
      if (explanation.length < 20) {
        tips.add(
          QualityTip(
            where,
            'Add a short explanation of why the answer is right.',
          ),
        );
      }
      if (key is! int || key < 0 || key >= options.length) continue;
      final answer = options[key].trim();
      final others = [
        for (final (j, o) in options.indexed)
          if (j != key) o.trim(),
      ];
      final longestOther = others.fold<int>(
        0,
        (m, o) => o.length > m ? o.length : m,
      );
      if (answer.length >= 1.5 * longestOther &&
          answer.length - longestOther >= 15) {
        tips.add(
          QualityTip(
            where,
            'The right answer is much longer than the others, which gives '
            'it away. Ask for options of similar length.',
          ),
        );
      }
      final normAnswer = AnswerKey.normalize(answer);
      if (normAnswer.length >= 5 &&
          norm.contains(normAnswer) &&
          !others.any((o) => norm.contains(AnswerKey.normalize(o)))) {
        tips.add(
          QualityTip(where, 'The question already contains the answer text.'),
        );
      }
    }
    return tips;
  }

  static List<Map<String, dynamic>> _maps(Object? raw) => raw is List
      ? [
          for (final m in raw)
            if (m is Map) Map<String, dynamic>.from(m),
        ]
      : const [];
}

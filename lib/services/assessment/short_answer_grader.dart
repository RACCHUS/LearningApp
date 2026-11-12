import 'package:learning_pwa/models/answer_key.dart';
import 'package:learning_pwa/models/question_content.dart';

/// How a short answer is compared with its accepted answers.
/// Correctness never uses fuzzy matching.
enum ShortAnswerGradingMethod {
  /// Must match exactly (surrounding spaces ignored). Use when case,
  /// accents or spelling are the point of the question.
  exact,

  /// Ignores case, extra spaces and trailing punctuation. Accents and
  /// spelling still matter.
  normalizedText,

  /// Compares numbers, within an optional tolerance.
  numeric;

  static ShortAnswerGradingMethod parse(String? raw) {
    switch (raw?.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]'), '')) {
      case 'exact':
        return ShortAnswerGradingMethod.exact;
      case 'numeric':
      case 'number':
        return ShortAnswerGradingMethod.numeric;
      default:
        return ShortAnswerGradingMethod.normalizedText;
    }
  }

  String get ruleDescription {
    switch (this) {
      case ShortAnswerGradingMethod.exact:
        return 'must match exactly, including capitals and accents';
      case ShortAnswerGradingMethod.normalizedText:
        return 'capitals, extra spaces and end punctuation are ignored; '
            'spelling and accents count';
      case ShortAnswerGradingMethod.numeric:
        return 'compared as a number';
    }
  }
}

class ShortAnswerGrade {
  const ShortAnswerGrade({
    required this.isCorrect,
    required this.feedback,
    this.matchedAnswer,
  });

  final bool isCorrect;

  /// Learner-facing explanation of why the answer was accepted or not.
  final String feedback;
  final String? matchedAnswer;
}

class ShortAnswerGrader {
  const ShortAnswerGrader._();

  /// Accepted answers: the declared list, else the legacy keyed option —
  /// but only when that key is genuinely valid (in range, non-blank and
  /// unambiguous). A defaulted or invalid index is never consumed, so an
  /// item with no trustworthy answer cannot be graded correct.
  static List<String> acceptedAnswersFor(QuestionContent q) {
    final declared = (q.acceptedAnswers ?? const <String>[])
        .where((a) => a.trim().isNotEmpty)
        .toList();
    if (declared.isNotEmpty) return declared;
    final key = AnswerKey.fromIndex(q.correctAnswer, q.options);
    if (key.isScorable) return [q.options[key.index!]];
    return const [];
  }

  static ShortAnswerGrade grade(QuestionContent q, String response) {
    final method = ShortAnswerGradingMethod.parse(q.gradingMethod);
    final accepted = acceptedAnswersFor(q);
    final display = accepted.isEmpty ? null : accepted.first;

    if (response.trim().isEmpty) {
      return const ShortAnswerGrade(
        isCorrect: false,
        feedback: 'Type an answer first.',
      );
    }

    if (method == ShortAnswerGradingMethod.numeric) {
      final value = parseNumber(response);
      if (value == null) {
        return ShortAnswerGrade(
          isCorrect: false,
          feedback:
              'Incorrect. Enter a number. '
                      '${display == null ? '' : 'Answer: $display'}'
                  .trim(),
        );
      }
      final tolerance = (q.numericTolerance ?? 0).abs();
      for (final answer in accepted) {
        final target = parseNumber(answer);
        if (target != null && (value - target).abs() <= tolerance + 1e-9) {
          return ShortAnswerGrade(
            isCorrect: true,
            matchedAnswer: answer,
            feedback: tolerance > 0
                ? 'Correct! Within ±${_fmt(tolerance)} of $answer.'
                : 'Correct! Matches $answer.',
          );
        }
      }
      return ShortAnswerGrade(
        isCorrect: false,
        feedback:
            'Incorrect. Answer: ${display ?? '—'}'
            '${tolerance > 0 ? ' (±${_fmt(tolerance)})' : ''}.',
      );
    }

    final normalize = method == ShortAnswerGradingMethod.exact
        ? (String s) => s.trim()
        : normalizeText;
    final given = normalize(response);
    for (final answer in accepted) {
      if (normalize(answer) == given) {
        final exactMatch = answer.trim() == response.trim();
        return ShortAnswerGrade(
          isCorrect: true,
          matchedAnswer: answer,
          feedback: exactMatch
              ? 'Correct!'
              : 'Correct! Accepted as "$answer" (${method.ruleDescription}).',
        );
      }
    }
    final alternatives = accepted.length > 1
        ? ' Also accepted: ${accepted.skip(1).join(', ')}.'
        : '';
    return ShortAnswerGrade(
      isCorrect: false,
      feedback:
          'Incorrect. Answer: ${display ?? '—'}.$alternatives '
                  'Rule: ${method.ruleDescription}.'
              .trim(),
    );
  }

  /// Lowercase, collapse whitespace, drop trailing sentence punctuation.
  /// Accents are kept on purpose.
  static String normalizeText(String s) => s
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[.!?,;:]+$'), '')
      .trim();

  /// Parses "1,234.5", "-3", "0.5". Rejects anything else (units, words).
  static double? parseNumber(String raw) {
    final s = raw.trim().replaceAll(RegExp(r'(?<=\d),(?=\d{3}(\D|$))'), '');
    if (!RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)$').hasMatch(s)) return null;
    return double.tryParse(s);
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

import '../models/assessment_item.dart';

class EvaluationViolationCore {
  final String rule;
  final String severity; // 'error' | 'warning'
  final String message;

  const EvaluationViolationCore({
    required this.rule,
    required this.severity,
    required this.message,
  });

  Map<String, dynamic> toJson() => {
        'rule': rule,
        'severity': severity,
        'message': message,
      };
}

class EvaluationReportCore {
  final double score; // 0.0 - 100.0
  final bool passed;
  final List<EvaluationViolationCore> violations;

  const EvaluationReportCore({
    required this.score,
    required this.passed,
    required this.violations,
  });

  Map<String, dynamic> toJson() => {
        'score': score,
        'passed': passed,
        'violations': violations.map((v) => v.toJson()).toList(),
      };
}

/// Pure Dart implementation of the Haladyna (2002) Item Evaluation Rubric.
class ItemEvaluatorCore {
  static const _negativePatterns = [
    r'\bNOT\b',
    r'\bEXCEPT\b',
    r'\bNEVER\b',
    r'\bFALSE\b',
  ];

  static const _absoluteModifiers = [
    'all of the above',
    'none of the above',
    'always',
    'never',
    'only',
    'every',
  ];

  /// Evaluates an assessment item against psychometric guidelines.
  EvaluationReportCore evaluate(AssessmentItemCore item) {
    final violations = <EvaluationViolationCore>[];

    // Rule 1: Source Excerpt Citation Presence
    if (item.sourceRef == null || item.sourceRef!.trim().isEmpty) {
      violations.add(const EvaluationViolationCore(
        rule: 'source_grounding',
        severity: 'error',
        message: 'Item lacks an authoritative source excerpt citation.',
      ));
    }

    // Rule 2: Minimum Option Count (3-5 options)
    if (item.options.length < 3 || item.options.length > 5) {
      violations.add(EvaluationViolationCore(
        rule: 'option_count',
        severity: 'error',
        message: 'Item has ${item.options.length} options; expected between 3 and 5.',
      ));
    }

    // Rule 3: Single Correct Answer
    final correctCount = item.options.where((o) => o.isCorrect).length;
    if (correctCount != 1) {
      violations.add(EvaluationViolationCore(
        rule: 'single_key',
        severity: 'error',
        message: 'Item must have exactly 1 correct option; found $correctCount.',
      ));
    }

    // Rule 4: Haladyna Rule 13 — Avoid Negative Stems
    for (final pattern in _negativePatterns) {
      if (RegExp(pattern).hasMatch(item.stem)) {
        violations.add(EvaluationViolationCore(
          rule: 'negative_stem',
          severity: 'warning',
          message: 'Stem contains negative modifier matching "$pattern". Use positive phrasing unless measuring exception recognition.',
        ));
        break;
      }
    }

    // Rule 5: Haladyna Rules 14 & 15 — Avoid "All of the Above" and Absolute Modifiers
    for (final opt in item.options) {
      final lower = opt.text.toLowerCase().trim();
      for (final mod in _absoluteModifiers) {
        if (lower.contains(mod)) {
          violations.add(EvaluationViolationCore(
            rule: 'absolute_modifier',
            severity: 'error',
            message: 'Option contains test-taking cue or absolute modifier "$mod".',
          ));
          break;
        }
      }
    }

    // Rule 6: Haladyna Rules 10 & 16 — Distractor Length Balance (<1.5x)
    if (item.options.isNotEmpty) {
      final lengths = item.options.map((o) => o.text.trim().length).toList();
      final minLen = lengths.reduce((a, b) => a < b ? a : b);
      final maxLen = lengths.reduce((a, b) => a > b ? a : b);

      if (minLen > 0) {
        final ratio = maxLen / minLen;
        if (ratio > 1.5) {
          violations.add(EvaluationViolationCore(
            rule: 'length_balance',
            severity: 'warning',
            message: 'Distractor lengths vary by ${ratio.toStringAsFixed(2)}x (max: $maxLen chars, min: $minLen chars). Keep within 1.5x to eliminate length cues.',
          ));
        }
      }
    }

    // Rule 7: Answer Leakage (Stem contains key verbatim)
    final correctOption = item.options.cast<AssessmentOptionCore?>().firstWhere(
          (o) => o?.isCorrect == true,
          orElse: () => null,
        );
    if (correctOption != null && correctOption.text.trim().length > 4) {
      final keyWord = correctOption.text.trim().toLowerCase();
      final stemLower = item.stem.toLowerCase();
      if (stemLower.contains(keyWord)) {
        violations.add(const EvaluationViolationCore(
          rule: 'answer_leakage',
          severity: 'error',
          message: 'Potential answer clue: stem contains key text verbatim.',
        ));
      }
    }

    // Calculate score: Start at 100, deduct 20 for each error, 10 for each warning
    double score = 100.0;
    for (final v in violations) {
      if (v.severity == 'error') {
        score -= 20.0;
      } else {
        score -= 10.0;
      }
    }
    if (score < 0) score = 0;

    final hasErrors = violations.any((v) => v.severity == 'error');
    return EvaluationReportCore(
      score: score,
      passed: !hasErrors && score >= 70.0,
      violations: violations,
    );
  }
}


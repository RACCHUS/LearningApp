import 'generated_content_models.dart';

/// Individual violation identified by the automated evaluation suite.
class EvaluationViolation {
  final String rule;
  final String severity; // 'critical', 'warning', 'info'
  final String message;

  const EvaluationViolation({
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

/// Result of evaluating an assessment item against psychometric and Haladyna rules.
class ItemEvaluationReport {
  final bool isPassed;
  final double score; // 0.0 to 100.0
  final bool hasAnswerLeak;
  final bool hasCitation;
  final bool isLengthBalanced;
  final double lengthRatio;
  final List<EvaluationViolation> violations;

  const ItemEvaluationReport({
    required this.isPassed,
    required this.score,
    required this.hasAnswerLeak,
    required this.hasCitation,
    required this.isLengthBalanced,
    required this.lengthRatio,
    required this.violations,
  });

  Map<String, dynamic> toJson() => {
        'is_passed': isPassed,
        'score': score,
        'has_answer_leak': hasAnswerLeak,
        'has_citation': hasCitation,
        'is_length_balanced': isLengthBalanced,
        'length_ratio': lengthRatio,
        'violations': violations.map((v) => v.toJson()).toList(),
      };
}

/// Aggregate summary report across an evaluation batch.
class BatchEvaluationReport {
  final int totalItems;
  final int passedItems;
  final int answerLeaksCount;
  final int citationsPresentCount;
  final int lengthBalancedCount;
  final double averageScore;

  const BatchEvaluationReport({
    required this.totalItems,
    required this.passedItems,
    required this.answerLeaksCount,
    required this.citationsPresentCount,
    required this.lengthBalancedCount,
    required this.averageScore,
  });

  double get passRate => totalItems > 0 ? passedItems / totalItems : 0.0;
  double get citationRate =>
      totalItems > 0 ? citationsPresentCount / totalItems : 0.0;
  double get lengthBalanceRate =>
      totalItems > 0 ? lengthBalancedCount / totalItems : 0.0;
  double get leakRate =>
      totalItems > 0 ? answerLeaksCount / totalItems : 0.0;

  Map<String, dynamic> toJson() => {
        'total_items': totalItems,
        'passed_items': passedItems,
        'pass_rate': passRate,
        'answer_leaks': answerLeaksCount,
        'leak_rate': leakRate,
        'citations_present': citationsPresentCount,
        'citation_rate': citationRate,
        'length_balanced': lengthBalancedCount,
        'length_balance_rate': lengthBalanceRate,
        'average_score': averageScore,
      };
}

/// Automated psychometric & Haladyna (2002) evaluation suite for AI-generated items (ARCH-4, §5).
class ItemEvaluator {
  /// Evaluates a single assessment item.
  ItemEvaluationReport evaluate(GeneratedAssessmentItem item) {
    final violations = <EvaluationViolation>[];
    double score = 100.0;

    // 0. Answer key must be valid; an item without one can never pass.
    final hasValidKey = item.hasValidKey;
    if (!hasValidKey) {
      violations.add(const EvaluationViolation(
        rule: 'answer_key_invalid',
        severity: 'critical',
        message:
            'Item has no valid correct answer (missing, out-of-range, blank or '
            'duplicated keyed option).',
      ));
      score -= 100.0;
    }

    // 1. Answer Leakage Check (Critical, Haladyna guideline: No test-taking cues)
    final leakViolation = _checkAnswerLeakage(item);
    final hasAnswerLeak = leakViolation != null;
    if (hasAnswerLeak) {
      violations.add(leakViolation);
      score -= 40.0;
    }

    // 2. Distractor Length Balance Check (Avoid giveaway longest option)
    final lengthRatio = _computeLengthRatio(item);
    final isLengthBalanced = lengthRatio <= 1.5 && lengthRatio >= 0.5;
    if (!isLengthBalanced) {
      violations.add(EvaluationViolation(
        rule: 'distractor_length_balance',
        severity: 'warning',
        message:
            'Correct answer length (${item.correctAnswer.length} chars) is outside 0.5x-1.5x of average distractor length (${_averageDistractorLength(item).toStringAsFixed(1)} chars; ratio: ${lengthRatio.toStringAsFixed(2)}x).',
      ));
      score -= 15.0;
    }

    // 3. Citation & Source Grounding Check (§5)
    final hasCitation = _checkCitation(item);
    if (!hasCitation) {
      violations.add(const EvaluationViolation(
        rule: 'source_citation_missing',
        severity: 'critical',
        message:
            'Item lacks a valid authoritative statutory, regulatory, or textbook source citation.',
      ));
      score -= 20.0;
    }

    // 4. Negative Stem Check (Haladyna Guideline 13)
    final negativeStemViolation = _checkNegativeStem(item);
    if (negativeStemViolation != null) {
      violations.add(negativeStemViolation);
      score -= 10.0;
    }

    // 5. Absolute Modifiers & Trivial Options (Haladyna Guidelines 14, 15)
    final optionViolations = _checkOptionForm(item);
    if (optionViolations.isNotEmpty) {
      violations.addAll(optionViolations);
      score -= (optionViolations.length * 5.0);
    }

    // 6. Option Uniqueness & Count
    if (item.options.length != 4) {
      violations.add(EvaluationViolation(
        rule: 'option_count_invalid',
        severity: 'critical',
        message: 'Item has ${item.options.length} options; exactly 4 required.',
      ));
      score -= 25.0;
    } else {
      final uniqueOptions = item.options.map((e) => e.toLowerCase()).toSet();
      if (uniqueOptions.length < item.options.length) {
        violations.add(const EvaluationViolation(
          rule: 'duplicate_options',
          severity: 'critical',
          message: 'Item contains duplicate or identical options.',
        ));
        score -= 25.0;
      }
    }

    // 7. Elaborative Feedback Coverage
    if (item.explanation.trim().length < 20) {
      violations.add(const EvaluationViolation(
        rule: 'sparse_explanation',
        severity: 'warning',
        message:
            'Explanation is too brief (< 20 characters); must provide elaborative rationale.',
      ));
      score -= 10.0;
    }

    score = score.clamp(0.0, 100.0);
    final isPassed =
        hasValidKey && !hasAnswerLeak && hasCitation && score >= 70.0;

    return ItemEvaluationReport(
      isPassed: isPassed,
      score: score,
      hasAnswerLeak: hasAnswerLeak,
      hasCitation: hasCitation,
      isLengthBalanced: isLengthBalanced,
      lengthRatio: lengthRatio,
      violations: violations,
    );
  }

  /// Evaluates an entire batch of items and aggregates psychometric statistics.
  BatchEvaluationReport evaluateBatch(List<GeneratedAssessmentItem> items) {
    if (items.isEmpty) {
      return const BatchEvaluationReport(
        totalItems: 0,
        passedItems: 0,
        answerLeaksCount: 0,
        citationsPresentCount: 0,
        lengthBalancedCount: 0,
        averageScore: 0.0,
      );
    }

    int passed = 0;
    int leaks = 0;
    int citations = 0;
    int balanced = 0;
    double totalScore = 0.0;

    for (final item in items) {
      final report = evaluate(item);
      if (report.isPassed) passed++;
      if (report.hasAnswerLeak) leaks++;
      if (report.hasCitation) citations++;
      if (report.isLengthBalanced) balanced++;
      totalScore += report.score;
    }

    return BatchEvaluationReport(
      totalItems: items.length,
      passedItems: passed,
      answerLeaksCount: leaks,
      citationsPresentCount: citations,
      lengthBalancedCount: balanced,
      averageScore: totalScore / items.length,
    );
  }

  EvaluationViolation? _checkAnswerLeakage(GeneratedAssessmentItem item) {
    final prompt = item.prompt.toLowerCase();
    final answer = item.correctAnswer.trim().toLowerCase();

    // Ignore very short common words (e.g. numbers, 'yes', 'no')
    if (answer.length >= 4) {
      // Direct word boundary containment or substring match
      final pattern = RegExp('\\b${RegExp.escape(answer)}\\b', caseSensitive: false);
      if (pattern.hasMatch(prompt)) {
        return EvaluationViolation(
          rule: 'answer_leakage',
          severity: 'critical',
          message:
              'Question stem explicitly leaks the correct answer "$answer".',
        );
      }
    }

    // Check for cue phrases like "The answer is ..."
    if (prompt.contains('the answer is') ||
        prompt.contains('the correct choice is') ||
        prompt.contains('which is known as ${item.correctAnswer.toLowerCase()}')) {
      return const EvaluationViolation(
        rule: 'answer_leakage_phrase',
        severity: 'critical',
        message: 'Question stem contains an explicit answer giveaway phrase.',
      );
    }

    return null;
  }

  double _computeLengthRatio(GeneratedAssessmentItem item) {
    final avgDistractor = _averageDistractorLength(item);
    if (avgDistractor <= 0) return 1.0;
    return item.correctAnswer.length / avgDistractor;
  }

  double _averageDistractorLength(GeneratedAssessmentItem item) {
    final distractors = item.distractors;
    if (distractors.isEmpty) return 0.0;
    final total = distractors.fold<int>(0, (sum, opt) => sum + opt.length);
    return total / distractors.length;
  }

  bool _checkCitation(GeneratedAssessmentItem item) {
    final c = item.sourceCitation.trim().toLowerCase();
    if (c.length < 5) return false;
    if (c == 'none' || c == 'n/a' || c == 'unknown' || c == 'not specified') {
      return false;
    }
    return true;
  }

  EvaluationViolation? _checkNegativeStem(GeneratedAssessmentItem item) {
    final prompt = item.prompt;
    final negativePatterns = [
      RegExp(r'\bNOT\b'),
      RegExp(r'\bEXCEPT\b'),
      RegExp(r'\bLEAST\b'),
      RegExp(r'\bNEVER\b'),
    ];

    for (final pattern in negativePatterns) {
      if (pattern.hasMatch(prompt)) {
        return EvaluationViolation(
          rule: 'negative_stem',
          severity: 'warning',
          message:
              'Stem contains negative phrasing ("${pattern.pattern.replaceAll(r'\b', '')}"); Haladyna recommends positive stems unless measuring exception comprehension.',
        );
      }
    }
    return null;
  }

  List<EvaluationViolation> _checkOptionForm(GeneratedAssessmentItem item) {
    final violations = <EvaluationViolation>[];
    for (int i = 0; i < item.options.length; i++) {
      final opt = item.options[i].trim().toLowerCase();

      // Check all-of-the-above / none-of-the-above
      if (opt.contains('all of the above') ||
          opt == 'all above' ||
          opt.contains('none of the above') ||
          opt == 'none above') {
        violations.add(EvaluationViolation(
          rule: 'haladyna_all_none_above',
          severity: 'critical',
          message:
              'Option ${String.fromCharCode(65 + i)} uses "$opt". Haladyna guidelines forbid "all/none of the above".',
        ));
      }

      // Check absolute modifiers
      if (opt.startsWith('always ') ||
          opt.startsWith('never ') ||
          opt.contains(' under no circumstances')) {
        violations.add(EvaluationViolation(
          rule: 'absolute_modifier',
          severity: 'warning',
          message:
              'Option ${String.fromCharCode(65 + i)} contains absolute modifiers ("always"/"never"), which learners recognize as test-wiseness clues.',
        ));
      }
    }
    return violations;
  }
}


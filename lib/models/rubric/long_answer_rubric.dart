/// Performance tiers for long-answer rubric grading.
enum RubricScoreLevel {
  exemplary(4, 'Exemplary', 'Mastery exceeded: comprehensive, accurate understanding with full regulatory citations.'),
  proficient(3, 'Proficient', 'Meets standard: clear understanding with required terminology and correct citations.'),
  developing(2, 'Developing', 'Approaching standard: partial understanding, missing key citations or minor inaccuracies.'),
  emerging(1, 'Emerging', 'Initial attempt: limited understanding, vague concepts, missing required keywords.'),
  unacceptable(0, 'Unacceptable', 'No relevant understanding or off-topic / non-responsive.');

  final int points;
  final String label;
  final String description;

  const RubricScoreLevel(this.points, this.label, this.description);

  static RubricScoreLevel fromPoints(int pts) {
    if (pts >= 4) return RubricScoreLevel.exemplary;
    if (pts == 3) return RubricScoreLevel.proficient;
    if (pts == 2) return RubricScoreLevel.developing;
    if (pts == 1) return RubricScoreLevel.emerging;
    return RubricScoreLevel.unacceptable;
  }
}

/// An individual criterion within an analytic rubric.
class RubricCriterion {
  final String id;
  final String title;
  final String description;
  final int weight;
  final List<String> mandatoryKeywords;
  final List<String> regulatoryCitations;
  final Map<RubricScoreLevel, String> levelDescriptors;

  const RubricCriterion({
    required this.id,
    required this.title,
    required this.description,
    this.weight = 1,
    this.mandatoryKeywords = const [],
    this.regulatoryCitations = const [],
    this.levelDescriptors = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'weight': weight,
    'mandatoryKeywords': mandatoryKeywords,
    'regulatoryCitations': regulatoryCitations,
    'levelDescriptors': levelDescriptors.map(
      (k, v) => MapEntry(k.name, v),
    ),
  };

  factory RubricCriterion.fromJson(Map<String, dynamic> json) {
    final descriptorsRaw = json['levelDescriptors'] as Map<String, dynamic>? ?? {};
    final Map<RubricScoreLevel, String> descriptors = {};
    for (final entry in descriptorsRaw.entries) {
      final level = RubricScoreLevel.values.firstWhere(
        (l) => l.name == entry.key,
        orElse: () => RubricScoreLevel.unacceptable,
      );
      descriptors[level] = entry.value.toString();
    }

    return RubricCriterion(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      weight: json['weight'] as int? ?? 1,
      mandatoryKeywords: (json['mandatoryKeywords'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      regulatoryCitations: (json['regulatoryCitations'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      levelDescriptors: descriptors,
    );
  }
}

/// A structured multi-dimensional rubric for long-answer evaluation.
class LongAnswerRubric {
  final String id;
  final String title;
  final String promptQuestion;
  final String domainTopic;
  final int minWords;
  final int maxWords;
  final List<RubricCriterion> criteria;
  final int passingScore;

  const LongAnswerRubric({
    required this.id,
    required this.title,
    required this.promptQuestion,
    required this.domainTopic,
    this.minWords = 50,
    this.maxWords = 500,
    required this.criteria,
    required this.passingScore,
  });

  int get maxScore =>
      criteria.fold<int>(0, (sum, c) => sum + (c.weight * 4));

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'promptQuestion': promptQuestion,
    'domainTopic': domainTopic,
    'minWords': minWords,
    'maxWords': maxWords,
    'criteria': criteria.map((c) => c.toJson()).toList(),
    'passingScore': passingScore,
  };

  factory LongAnswerRubric.fromJson(Map<String, dynamic> json) {
    return LongAnswerRubric(
      id: json['id'] as String,
      title: json['title'] as String,
      promptQuestion: json['promptQuestion'] as String,
      domainTopic: json['domainTopic'] as String,
      minWords: json['minWords'] as int? ?? 50,
      maxWords: json['maxWords'] as int? ?? 500,
      criteria: (json['criteria'] as List<dynamic>? ?? [])
          .map((c) => RubricCriterion.fromJson(c as Map<String, dynamic>))
          .toList(),
      passingScore: json['passingScore'] as int? ?? 10,
    );
  }
}

/// Detailed evaluation score for a single rubric criterion.
class CriterionScoreResult {
  final String criterionId;
  final RubricScoreLevel level;
  final int points;
  final List<String> matchedKeywords;
  final List<String> missingKeywords;
  final List<String> matchedCitations;
  final List<String> missingCitations;
  final String rationale;
  final String improvementTip;

  const CriterionScoreResult({
    required this.criterionId,
    required this.level,
    required this.points,
    this.matchedKeywords = const [],
    this.missingKeywords = const [],
    this.matchedCitations = const [],
    this.missingCitations = const [],
    required this.rationale,
    required this.improvementTip,
  });

  Map<String, dynamic> toJson() => {
    'criterionId': criterionId,
    'level': level.name,
    'points': points,
    'matchedKeywords': matchedKeywords,
    'missingKeywords': missingKeywords,
    'matchedCitations': matchedCitations,
    'missingCitations': missingCitations,
    'rationale': rationale,
    'improvementTip': improvementTip,
  };

  factory CriterionScoreResult.fromJson(Map<String, dynamic> json) {
    return CriterionScoreResult(
      criterionId: json['criterionId'] as String,
      level: RubricScoreLevel.values.firstWhere(
        (l) => l.name == json['level'],
        orElse: () => RubricScoreLevel.unacceptable,
      ),
      points: json['points'] as int? ?? 0,
      matchedKeywords: (json['matchedKeywords'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      missingKeywords: (json['missingKeywords'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      matchedCitations: (json['matchedCitations'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      missingCitations: (json['missingCitations'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      rationale: json['rationale'] as String? ?? '',
      improvementTip: json['improvementTip'] as String? ?? '',
    );
  }
}

/// Overall composite result of a long-answer essay evaluation.
class LongAnswerEvaluationResult {
  final String rubricId;
  final int totalScore;
  final int maxScore;
  final double percentage;
  final bool passed;
  final int wordCount;
  final Map<String, CriterionScoreResult> criterionResults;
  final String summaryFeedback;
  final bool usedAi;
  final bool flagPotentialPromptInjection;

  const LongAnswerEvaluationResult({
    required this.rubricId,
    required this.totalScore,
    required this.maxScore,
    required this.percentage,
    required this.passed,
    required this.wordCount,
    required this.criterionResults,
    required this.summaryFeedback,
    this.usedAi = false,
    this.flagPotentialPromptInjection = false,
  });

  Map<String, dynamic> toJson() => {
    'rubricId': rubricId,
    'totalScore': totalScore,
    'maxScore': maxScore,
    'percentage': percentage,
    'passed': passed,
    'wordCount': wordCount,
    'criterionResults': criterionResults.map(
      (k, v) => MapEntry(k, v.toJson()),
    ),
    'summaryFeedback': summaryFeedback,
    'usedAi': usedAi,
    'flagPotentialPromptInjection': flagPotentialPromptInjection,
  };

  factory LongAnswerEvaluationResult.fromJson(Map<String, dynamic> json) {
    final rawResults = json['criterionResults'] as Map<String, dynamic>? ?? {};
    final Map<String, CriterionScoreResult> mapped = {};
    for (final entry in rawResults.entries) {
      mapped[entry.key] = CriterionScoreResult.fromJson(
        entry.value as Map<String, dynamic>,
      );
    }

    return LongAnswerEvaluationResult(
      rubricId: json['rubricId'] as String,
      totalScore: json['totalScore'] as int? ?? 0,
      maxScore: json['maxScore'] as int? ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      passed: json['passed'] as bool? ?? false,
      wordCount: json['wordCount'] as int? ?? 0,
      criterionResults: mapped,
      summaryFeedback: json['summaryFeedback'] as String? ?? '',
      usedAi: json['usedAi'] as bool? ?? false,
      flagPotentialPromptInjection:
          json['flagPotentialPromptInjection'] as bool? ?? false,
    );
  }
}


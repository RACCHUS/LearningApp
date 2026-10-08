import '../../models/assessment_engine/exam_diagnostic_report.dart';
import '../../models/assessment_engine/mock_exam_session.dart';
import '../../models/assessment_item.dart';
import '../../models/user_concept_state.dart';

/// Evaluates mock examination submissions with strict pedagogical safeguards (Section 15.6).
class ExamEvaluationService {
  /// Evaluates an exam session and compiles a comprehensive diagnostic report.
  ExamDiagnosticReport evaluateExam(MockExamSession session) {
    final scoredItems = <ScoredItemResult>[];
    int correctCount = 0;
    int partialCount = 0;
    int incorrectCount = 0;
    int unansweredCount = 0;
    double totalScoreEarned = 0.0;

    final domainScoreTracker = <String, ({int total, int correct, double earned})>{};
    for (final domain in session.blueprint.domainWeights) {
      domainScoreTracker[domain.domainCode] = (total: 0, correct: 0, earned: 0.0);
    }

    final missedConceptMap = <String, int>{}; // conceptId -> missed count

    for (final item in session.items) {
      final domainCode = session.itemDomainMap[item.id] ?? '1.0';
      final userAns = session.userResponses[item.id];
      final itemConcepts = session.itemConceptMap[item.id] ?? [];

      if (userAns == null) {
        unansweredCount++;
        scoredItems.add(ScoredItemResult(
          itemId: item.id,
          prompt: item.prompt,
          domainCode: domainCode,
          userResponse: null,
          correctResponse: _extractCorrectAnswer(item),
          isCorrect: false,
          scoreEarned: 0.0,
          explanation: item.explanation,
          conceptIds: itemConcepts,
        ));

        final curr = domainScoreTracker[domainCode] ?? (total: 0, correct: 0, earned: 0.0);
        domainScoreTracker[domainCode] = (
          total: curr.total + 1,
          correct: curr.correct,
          earned: curr.earned,
        );

        for (final cid in itemConcepts) {
          missedConceptMap[cid] = (missedConceptMap[cid] ?? 0) + 1;
        }
        continue;
      }

      // Evaluate interaction polymorphic types
      final evaluation = evaluateItemResponse(item, userAns);
      if (evaluation.isCorrect) {
        correctCount++;
      } else if (evaluation.isPartial) {
        partialCount++;
      } else {
        incorrectCount++;
        for (final cid in itemConcepts) {
          missedConceptMap[cid] = (missedConceptMap[cid] ?? 0) + 1;
        }
      }

      totalScoreEarned += evaluation.scoreEarned;

      scoredItems.add(ScoredItemResult(
        itemId: item.id,
        prompt: item.prompt,
        domainCode: domainCode,
        userResponse: userAns,
        correctResponse: _extractCorrectAnswer(item),
        isCorrect: evaluation.isCorrect,
        isPartial: evaluation.isPartial,
        scoreEarned: evaluation.scoreEarned,
        explanation: item.explanation,
        conceptIds: itemConcepts,
      ));

      final curr = domainScoreTracker[domainCode] ?? (total: 0, correct: 0, earned: 0.0);
      domainScoreTracker[domainCode] = (
        total: curr.total + 1,
        correct: curr.correct + (evaluation.isCorrect ? 1 : 0),
        earned: curr.earned + evaluation.scoreEarned,
      );
    }

    // Compile Domain Diagnostics
    final domainDiagnostics = <DomainDiagnostic>[];
    double weightedPercentageSum = 0.0;
    double totalActiveWeight = 0.0;

    for (final domain in session.blueprint.domainWeights) {
      final stats = domainScoreTracker[domain.domainCode] ?? (total: 0, correct: 0, earned: 0.0);
      final percentage = stats.total > 0 ? (stats.earned / stats.total) * 100.0 : 0.0;
      final evidenceLevel = DomainEvidenceLevel.fromPercentage(percentage);

      domainDiagnostics.add(DomainDiagnostic(
        domainId: domain.domainId,
        domainCode: domain.domainCode,
        domainTitle: domain.domainTitle,
        domainWeight: domain.weight,
        totalQuestions: stats.total,
        correctQuestions: stats.correct,
        scoreEarned: stats.earned,
        percentage: percentage,
        evidenceLevel: evidenceLevel,
      ));

      if (stats.total > 0) {
        weightedPercentageSum += percentage * domain.weight;
        totalActiveWeight += domain.weight;
      }
    }

    // Overall Practice Performance
    final overallPercentage = totalActiveWeight > 0
        ? (weightedPercentageSum / totalActiveWeight).clamp(0.0, 100.0)
        : (session.totalQuestions > 0 ? (totalScoreEarned / session.totalQuestions) * 100.0 : 0.0);

    // Compute Scaled Score (e.g. 100-900 CompTIA scale)
    final scaledScore = _calculateScaledScore(overallPercentage, session.blueprint.officialScoreScale);

    // Determine Readiness Band and Section 15.6 Safe Phrasing
    final TargetReadinessBand readinessBand;
    final String headline;
    final String summary;

    if (overallPercentage >= 80.0) {
      readinessBand = TargetReadinessBand.strongCoverage;
      headline = 'Strong Practice Readiness Demonstrated';
      summary =
          'Your evaluation reflects strong foundational grasp across the curriculum blueprint. Continue targeted review to sustain readiness.';
    } else if (overallPercentage >= 65.0) {
      readinessBand = TargetReadinessBand.developing;
      headline = 'Developing Practice Performance';
      summary =
          'You demonstrate solid knowledge in several domains with key opportunities for reinforcement prior to official testing.';
    } else {
      readinessBand = TargetReadinessBand.needsReinforcement;
      headline = 'Targeted Reinforcement Recommended';
      summary =
          'Practice evidence indicates that concentrated concept review in specific domains will significantly strengthen test performance.';
    }

    // Remediation recommendations based on missed items
    final remediationRecommendations = <RemediationRecommendation>[];
    final sortedMissedConcepts = missedConceptMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedMissedConcepts.take(5)) {
      remediationRecommendations.add(RemediationRecommendation(
        conceptId: entry.key,
        conceptName: 'Review Concept (${entry.key})',
        domainTitle: 'Domain Objective Alignment',
        priority: entry.value >= 2 ? 'high' : 'medium',
        rationale: 'Missed in ${entry.value} practice items during this session.',
      ));
    }

    return ExamDiagnosticReport(
      sessionId: session.id,
      targetVersionId: session.blueprint.targetVersionId,
      completedAt: session.completedAt ?? DateTime.now(),
      durationTaken: Duration(seconds: session.elapsedSeconds),
      officialFacts: OfficialExamFacts(
        examCode: session.blueprint.examCode,
        title: session.blueprint.title,
        publishedPassingScore: session.blueprint.officialPassingScore,
        scoreScale: session.blueprint.officialScoreScale,
        timeLimitMinutes: session.blueprint.timeLimitMinutes,
      ),
      readinessEstimate: AppReadinessEstimate(
        practiceScorePercentage: overallPercentage,
        estimatedScaledScore: scaledScore,
        readinessBand: readinessBand,
        readinessHeadline: headline,
        readinessSummary: summary,
        totalQuestions: session.totalQuestions,
        correctCount: correctCount,
        partialCount: partialCount,
        incorrectCount: incorrectCount,
        unansweredCount: unansweredCount,
        totalScoreEarned: totalScoreEarned,
      ),
      domainDiagnostics: domainDiagnostics,
      remediationRecommendations: remediationRecommendations,
      scoredItems: scoredItems,
    );
  }

  /// Canonical evaluator for polymorphic assessment responses.
  ///
  /// Shared by mock exams, diagnostics, and other assessment surfaces so
  /// response scoring cannot drift between presentation modes.
  ({bool isCorrect, bool isPartial, double scoreEarned}) evaluateItemResponse(
    AssessmentItem item,
    dynamic userAns,
  ) {
    switch (item.interactionType) {
      case AssessmentInteractionType.singleChoice:
        final correctIndex = (item.scoringSpec['correct_index'] as num?)?.toInt();
        final userIndex = userAns is num ? userAns.toInt() : int.tryParse(userAns.toString());
        final isMatch = correctIndex != null && userIndex == correctIndex;
        return (isCorrect: isMatch, isPartial: false, scoreEarned: isMatch ? 1.0 : 0.0);

      case AssessmentInteractionType.multiSelect:
        final correctIndices = (item.scoringSpec['correct_indices'] as List? ?? const [])
            .whereType<num>()
            .map((e) => e.toInt())
            .toSet();
        final userIndices = (userAns is Iterable ? userAns : [userAns])
            .whereType<num>()
            .map((e) => e.toInt())
            .toSet();

        final scoringMode = item.scoringSpec['scoring_method'] as String? ??
            item.scoringSpec['mode'] as String? ??
            'all_or_nothing';

        if (scoringMode == 'partial_credit' && correctIndices.isNotEmpty) {
          final correctSelected = userIndices.intersection(correctIndices).length;
          final incorrectSelected = userIndices.difference(correctIndices).length;
          double score = (correctSelected - incorrectSelected) / correctIndices.length;
          score = score.clamp(0.0, 1.0);
          final isFull = score >= 0.999;
          final isPart = score > 0.0 && !isFull;
          return (isCorrect: isFull, isPartial: isPart, scoreEarned: score);
        }

        final isMatch = correctIndices.isNotEmpty &&
            userIndices.length == correctIndices.length &&
            userIndices.difference(correctIndices).isEmpty;
        return (isCorrect: isMatch, isPartial: false, scoreEarned: isMatch ? 1.0 : 0.0);

      case AssessmentInteractionType.orderedResponse:
        final items = (item.responseSpec['items'] as List? ?? const [])
            .map((e) => e.toString())
            .toList();
        final correctOrder = (item.scoringSpec['correct_order'] as List? ?? const [])
            .whereType<num>()
            .map((e) => e.toInt())
            .toList();

        if (items.isEmpty ||
            correctOrder.length != items.length ||
            correctOrder.any((index) => index < 0 || index >= items.length)) {
          return (isCorrect: false, isPartial: false, scoreEarned: 0.0);
        }

        final expectedOrder = correctOrder.map((index) => items[index]).toList();
        final userOrder = (userAns is List ? userAns : const [])
            .map((e) => e.toString())
            .toList();

        final isMatch = userOrder.length == expectedOrder.length &&
            List.generate(expectedOrder.length, (i) => userOrder[i] == expectedOrder[i])
                .every((value) => value);
        return (isCorrect: isMatch, isPartial: false, scoreEarned: isMatch ? 1.0 : 0.0);

      case AssessmentInteractionType.matching:
        final correctPairs = (item.scoringSpec['correct_pairs'] as Map? ?? const {}).map(
          (k, v) => MapEntry(k.toString().trim(), v.toString().trim()),
        );
        final userPairs = (userAns is Map ? userAns : const {}).map(
          (k, v) => MapEntry(k.toString().trim(), v.toString().trim()),
        );

        if (correctPairs.isEmpty) {
          return (isCorrect: false, isPartial: false, scoreEarned: 0.0);
        }

        int matchedCount = 0;
        for (final entry in correctPairs.entries) {
          if (userPairs[entry.key] == entry.value) {
            matchedCount++;
          }
        }

        final score = matchedCount / correctPairs.length;
        final isFull = score >= 0.999;
        final isPart = score > 0.0 && !isFull;
        return (isCorrect: isFull, isPartial: isPart, scoreEarned: score);

      default:
        // Unsupported interaction types must fail closed rather than award credit.
        return (isCorrect: false, isPartial: false, scoreEarned: 0.0);
    }
  }

  dynamic _extractCorrectAnswer(AssessmentItem item) {
    switch (item.interactionType) {
      case AssessmentInteractionType.singleChoice:
        return item.scoringSpec['correct_index'];
      case AssessmentInteractionType.multiSelect:
        return item.scoringSpec['correct_indices'];
      case AssessmentInteractionType.orderedResponse:
        return item.scoringSpec['correct_order'];
      case AssessmentInteractionType.matching:
        return item.scoringSpec['correct_pairs'];
      default:
        return null;
    }
  }

  int _calculateScaledScore(double percentage, String scale) {
    if (scale == '100-900') {
      // CompTIA: 100 + (percentage / 100) * 800
      final scaled = 100 + (percentage / 100.0) * 800;
      return scaled.round().clamp(100, 900);
    }
    // Default 0-100 scale
    return percentage.round().clamp(0, 100);
  }
}

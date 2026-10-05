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
      final evaluation = _evaluateItemResponse(item, userAns);
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

  /// Internal evaluator for polymorphic interaction response formats.
  ({bool isCorrect, bool isPartial, double scoreEarned}) _evaluateItemResponse(
    AssessmentItem item,
    dynamic userAns,
  ) {
    switch (item.interactionType) {
      case AssessmentInteractionType.singleChoice:
        final correctAns = item.responseSpec['answer'] ?? item.responseSpec['correct_answer'];
        final isMatch = userAns.toString().trim() == correctAns.toString().trim();
        return (isCorrect: isMatch, isPartial: false, scoreEarned: isMatch ? 1.0 : 0.0);

      case AssessmentInteractionType.multiSelect:
        final correctList = (item.responseSpec['answers'] ??
                item.responseSpec['correct_answers'] as List? ??
                [])
            .map((e) => e.toString().trim())
            .toSet();

        final userList = (userAns is List ? userAns : [userAns])
            .map((e) => e.toString().trim())
            .toSet();

        final scoringMode = item.scoringSpec['mode'] as String? ?? 'all_or_nothing';

        if (scoringMode == 'partial_credit' && correctList.isNotEmpty) {
          int correctSelected = userList.intersection(correctList).length;
          int incorrectSelected = userList.difference(correctList).length;
          double score = (correctSelected - incorrectSelected) / correctList.length;
          score = score.clamp(0.0, 1.0);
          final isFull = score >= 0.999;
          final isPart = score > 0.0 && !isFull;
          return (isCorrect: isFull, isPartial: isPart, scoreEarned: score);
        } else {
          final isMatch = userList.length == correctList.length &&
              userList.difference(correctList).isEmpty;
          return (isCorrect: isMatch, isPartial: false, scoreEarned: isMatch ? 1.0 : 0.0);
        }

      case AssessmentInteractionType.orderedResponse:
        final correctOrder = (item.responseSpec['correct_order'] as List? ?? [])
            .map((e) => e.toString().trim())
            .toList();

        final userOrder = (userAns is List ? userAns : [])
            .map((e) => e.toString().trim())
            .toList();

        if (userOrder.length != correctOrder.length) {
          return (isCorrect: false, isPartial: false, scoreEarned: 0.0);
        }

        bool match = true;
        for (int i = 0; i < correctOrder.length; i++) {
          if (userOrder[i] != correctOrder[i]) {
            match = false;
            break;
          }
        }
        return (isCorrect: match, isPartial: false, scoreEarned: match ? 1.0 : 0.0);

      case AssessmentInteractionType.matching:
        final correctPairs = (item.responseSpec['pairs'] as Map? ?? {}).map(
          (k, v) => MapEntry(k.toString().trim(), v.toString().trim()),
        );

        final userPairs = (userAns is Map ? userAns : {}).map(
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
        // Default string comparison
        final correctStr = (item.responseSpec['answer'] ?? '').toString().trim();
        final isMatch = userAns.toString().trim() == correctStr;
        return (isCorrect: isMatch, isPartial: false, scoreEarned: isMatch ? 1.0 : 0.0);
    }
  }

  dynamic _extractCorrectAnswer(AssessmentItem item) {
    return item.responseSpec['answer'] ??
        item.responseSpec['answers'] ??
        item.responseSpec['correct_order'] ??
        item.responseSpec['pairs'];
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

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/assessment_engine/exam_diagnostic_report.dart';
import '../../models/assessment_engine/mock_exam_blueprint.dart';
import '../../models/assessment_engine/mock_exam_session.dart';
import '../../models/assessment_item.dart';
import '../../models/user_concept_state.dart';

/// Exception thrown when a server-side simulation exam operation fails.
class ClepSimulationException implements Exception {
  final String message;
  final String? code;

  const ClepSimulationException(this.message, {this.code});

  @override
  String toString() => 'ClepSimulationException: $message${code != null ? ' (code: $code)' : ''}';
}

/// Structured diagnostic result returned from confidential server-side exam scoring.
///
/// Accurately maps the authoritative database contract returned by `clep_submit_simulation_exam`:
/// - `raw_score` (integer)
/// - `accuracy_percentage` (numeric)
/// - `readiness_indicator` (text)
/// - `total_questions` (integer)
/// - `time_spent_seconds` (integer)
/// - `is_calibrated_clep_score` (boolean)
/// - `scoring_disclaimer` (text)
/// - `results` (jsonb array of item outcomes with answered, is_correct, concept_ids)
class ClepSimulationSubmissionResult {
  final String attemptId;
  final String targetVersionId;
  final double percentage;
  final String readiness;
  final int correctCount;
  final int totalQuestions;
  final int answeredCount;
  final int timeSpentSeconds;
  final bool isCalibratedClepScore;
  final String scoringDisclaimer;
  final List<Map<String, dynamic>> itemResults;

  const ClepSimulationSubmissionResult({
    required this.attemptId,
    this.targetVersionId = '',
    required this.percentage,
    required this.readiness,
    required this.correctCount,
    required this.totalQuestions,
    required this.answeredCount,
    required this.timeSpentSeconds,
    this.isCalibratedClepScore = false,
    this.scoringDisclaimer = '',
    required this.itemResults,
  });

  /// Accessor aliases matching exact database column / JSON payload naming
  int get rawScore => correctCount;
  double get accuracyPercentage => percentage;
  String get readinessIndicator => readiness;

  factory ClepSimulationSubmissionResult.fromJson(
    Map<String, dynamic> json, {
    int? clientAnsweredCount,
  }) {
    final rawResults = (json['results'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

    // 1. Correct count: map from database contract 'raw_score', fallback to 'correct_count'
    final correct = (json['raw_score'] as num?)?.toInt() ??
        (json['correct_count'] as num?)?.toInt() ??
        0;

    // 2. Percentage: map from database contract 'accuracy_percentage', fallback to 'percentage'
    final pct = (json['accuracy_percentage'] as num?)?.toDouble() ??
        (json['percentage'] as num?)?.toDouble() ??
        0.0;

    // 3. Readiness: map from database contract 'readiness_indicator', fallback to 'readiness'
    final readinessStr = json['readiness_indicator'] as String? ??
        json['readiness'] as String? ??
        'Pending Review';

    // 4. Answered count: database omits answered_count field, so compute from results
    // where answered == true, or use clientAnsweredCount as fallback.
    int computedAnsweredCount = (json['answered_count'] as num?)?.toInt() ??
        rawResults.where((r) => r['answered'] == true).length;
    if (computedAnsweredCount == 0 && clientAnsweredCount != null && clientAnsweredCount > 0) {
      computedAnsweredCount = clientAnsweredCount;
    }

    return ClepSimulationSubmissionResult(
      attemptId: json['attempt_id'] as String? ?? '',
      targetVersionId: json['target_version_id'] as String? ?? '',
      percentage: pct,
      readiness: readinessStr,
      correctCount: correct,
      totalQuestions: (json['total_questions'] as num?)?.toInt() ?? 0,
      answeredCount: computedAnsweredCount,
      timeSpentSeconds: (json['time_spent_seconds'] as num?)?.toInt() ?? 0,
      isCalibratedClepScore: json['is_calibrated_clep_score'] == true,
      scoringDisclaimer: json['scoring_disclaimer'] as String? ?? '',
      itemResults: rawResults,
    );
  }

  /// Converts this server-side submission result into a complete [ExamDiagnosticReport]
  /// suitable for display in [ExamReportScreen].
  ///
  /// Guarantees:
  /// - Protected answer keys and item explanations remain null in scored items.
  /// - Accurately populates readiness bands and evidence levels from server scores.
  ExamDiagnosticReport toDiagnosticReport(MockExamSession session) {
    final itemResultMap = <String, Map<String, dynamic>>{};
    for (final res in itemResults) {
      final id = res['id']?.toString();
      if (id != null) {
        itemResultMap[id] = res;
      }
    }

    final domainConstraints = session.blueprint.domainWeights.isNotEmpty
        ? session.blueprint.domainWeights
        : ClepSimulationService.defaultClepDomainWeights(session.blueprint.examCode);

    final scoredItems = <ScoredItemResult>[];
    final domainStats = <String, ({int total, int correct, double earned})>{};
    for (final domain in domainConstraints) {
      domainStats[domain.domainCode] = (total: 0, correct: 0, earned: 0.0);
    }

    final missedConcepts = <String, int>{};

    for (final item in session.items) {
      final itemRes = itemResultMap[item.id];
      final domainCode = itemRes?['domain_code'] as String? ??
          session.itemDomainMap[item.id] ??
          '1.0';
      final userAns = session.userResponses[item.id];
      final isItemCorrect = itemRes?['is_correct'] == true;
      final cids = (itemRes?['concept_ids'] as List?)?.cast<String>() ??
          session.itemConceptMap[item.id] ??
          const [];

      scoredItems.add(ScoredItemResult(
        itemId: item.id,
        prompt: item.prompt,
        domainCode: domainCode,
        userResponse: userAns,
        correctResponse: null, // Protected: withheld from simulation bank
        isCorrect: isItemCorrect,
        isPartial: false,
        scoreEarned: isItemCorrect ? 1.0 : 0.0,
        explanation: null, // Protected: explanations withheld from simulation bank
        conceptIds: cids,
      ));

      final curr = domainStats[domainCode] ?? (total: 0, correct: 0, earned: 0.0);
      domainStats[domainCode] = (
        total: curr.total + 1,
        correct: curr.correct + (isItemCorrect ? 1 : 0),
        earned: curr.earned + (isItemCorrect ? 1.0 : 0.0),
      );

      if (!isItemCorrect) {
        for (final cid in cids) {
          missedConcepts[cid] = (missedConcepts[cid] ?? 0) + 1;
        }
      }
    }

    // Domain diagnostics
    final domainDiagnostics = <DomainDiagnostic>[];
    for (final domain in domainConstraints) {
      final stats = domainStats[domain.domainCode] ?? (total: 0, correct: 0, earned: 0.0);
      final domainPct = stats.total > 0 ? (stats.earned / stats.total) * 100.0 : 0.0;
      domainDiagnostics.add(DomainDiagnostic(
        domainId: domain.domainId,
        domainCode: domain.domainCode,
        domainTitle: domain.domainTitle,
        domainWeight: domain.weight,
        totalQuestions: stats.total,
        correctQuestions: stats.correct,
        scoreEarned: stats.earned,
        percentage: domainPct,
        evidenceLevel: DomainEvidenceLevel.fromPercentage(domainPct),
      ));
    }

    // Readiness estimate
    TargetReadinessBand band;
    if (percentage >= 70.0) {
      band = TargetReadinessBand.strongCoverage;
    } else if (percentage >= 50.0) {
      band = TargetReadinessBand.developing;
    } else {
      band = TargetReadinessBand.needsReinforcement;
    }

    final totalQs = totalQuestions > 0 ? totalQuestions : session.totalQuestions;
    final unans = session.unansweredCount;
    final incorrect = (totalQs - correctCount - unans).clamp(0, totalQs);

    final readinessEst = AppReadinessEstimate(
      practiceScorePercentage: percentage,
      estimatedScaledScore: null, // Equated official score requires College Board form equating
      readinessBand: band,
      readinessHeadline: readiness,
      readinessSummary: scoringDisclaimer.isNotEmpty
          ? scoringDisclaimer
          : 'Diagnostic simulation estimate based on server-side evaluation.',
      totalQuestions: totalQs,
      correctCount: correctCount,
      partialCount: 0,
      incorrectCount: incorrect,
      unansweredCount: unans,
      totalScoreEarned: correctCount.toDouble(),
    );

    // Official facts
    final facts = OfficialExamFacts(
      examCode: session.blueprint.examCode,
      title: session.blueprint.title,
      publishedPassingScore: session.blueprint.officialPassingScore,
      scoreScale: session.blueprint.officialScoreScale ??
          '20-80 (ACE Recommended Passing: 50)',
      timeLimitMinutes: session.blueprint.timeLimitMinutes,
      nonAffiliationNotice:
          'LearningApp is independent of the College Board. Practice simulation results do not represent official scores.',
    );

    // Remediation recommendations
    final remediationRecommendations = missedConcepts.entries.map((entry) {
      return RemediationRecommendation(
        conceptId: entry.key,
        conceptName: 'Remediation: ${entry.key}',
        domainTitle: session.blueprint.title,
        priority: entry.value > 1 ? 'high' : 'medium',
        rationale: 'Review concept based on ${entry.value} missed question(s).',
      );
    }).toList();

    return ExamDiagnosticReport(
      sessionId: attemptId.isNotEmpty ? attemptId : session.id,
      targetVersionId: session.blueprint.targetVersionId,
      examPartKey: session.blueprint.examPartKey,
      completedAt: session.completedAt ?? DateTime.now(),
      durationTaken: Duration(seconds: timeSpentSeconds > 0 ? timeSpentSeconds : session.elapsedSeconds),
      officialFacts: facts,
      readinessEstimate: readinessEst,
      domainDiagnostics: domainDiagnostics,
      remediationRecommendations: remediationRecommendations,
      scoredItems: scoredItems,
    );
  }
}

/// Client service managing the complete lifecycle of confidential, protected CLEP simulation exams.
///
/// Communicates exclusively with the server-side security RPCs:
/// - `clep_issue_simulation_exam`: verifies authentication, single-attempt invariant, and returns sanitized items.
/// - `clep_submit_simulation_exam`: locks attempt, grades answers confidentially, and returns scores without disclosing protected keys.
class ClepSimulationService {
  final SupabaseClient? _supabase;
  final Future<dynamic> Function(String rpcName, Map<String, dynamic> params)? _transport;

  ClepSimulationService({
    SupabaseClient? supabase,
    Future<dynamic> Function(String rpcName, Map<String, dynamic> params)? transport,
  })  : _supabase = supabase,
        _transport = transport;

  SupabaseClient get _client => _supabase ?? Supabase.instance.client;

  Future<dynamic> _invokeRpc(String rpcName, Map<String, dynamic> params) async {
    try {
      if (_transport != null) {
        return await _transport(rpcName, params);
      }
      return await _client.rpc(rpcName, params: params);
    } on PostgrestException catch (e) {
      throw ClepSimulationException(e.message, code: e.code);
    } catch (e) {
      if (e is ClepSimulationException) rethrow;
      throw ClepSimulationException(e.toString());
    }
  }

  /// Default College Board blueprint domain specifications for CLEP examinations.
  static List<DomainWeightConstraint> defaultClepDomainWeights(String examCode) {
    if (examCode == 'CLEP-ALG') {
      return const [
        DomainWeightConstraint(
          domainId: 'clep-alg-domain-1',
          domainCode: '1.0',
          domainTitle: 'Algebraic operations',
          weight: 0.25,
        ),
        DomainWeightConstraint(
          domainId: 'clep-alg-domain-2',
          domainCode: '2.0',
          domainTitle: 'Equations and inequalities',
          weight: 0.25,
        ),
        DomainWeightConstraint(
          domainId: 'clep-alg-domain-3',
          domainCode: '3.0',
          domainTitle: 'Functions and their properties',
          weight: 0.30,
        ),
        DomainWeightConstraint(
          domainId: 'clep-alg-domain-4',
          domainCode: '4.0',
          domainTitle: 'Number systems and operations',
          weight: 0.20,
        ),
      ];
    }
    return const [];
  }

  /// Issues an authenticated CLEP simulation exam from the database.
  ///
  /// Enforces:
  /// - Server-side authentication and single-attempt constraint.
  /// - Delivery of safe options only; scoring keys and explanations remain permanently server-side.
  /// - Proper exam tool policy mapping (e.g., allowedTools: {'calculator'} for College Algebra).
  /// - Accurate 4-domain psychometric tagging across all questions.
  Future<MockExamSession> issueSimulationExam({
    required String targetVersionId,
    required String examCode,
    required String examTitle,
    Set<String> allowedTools = const {},
    List<DomainWeightConstraint> domainWeights = const [],
  }) async {
    final raw = await _invokeRpc('clep_issue_simulation_exam', {
      'p_target_version_id': targetVersionId,
    });

    if (raw is! Map) {
      throw const ClepSimulationException('Unexpected response payload from clep_issue_simulation_exam');
    }

    final data = raw.cast<String, dynamic>();
    final attemptId = data['attempt_id'] as String;
    final timeLimitMins = (data['time_limit_minutes'] as num?)?.toInt() ?? 90;
    final issuedAt = DateTime.parse(data['issued_at'] as String? ?? DateTime.now().toIso8601String());
    final questionsRaw = (data['questions'] as List?) ?? [];
    final domainsRaw = (data['domains'] as List?) ?? [];

    List<DomainWeightConstraint> resolvedDomainWeights = List.of(domainWeights);
    if (resolvedDomainWeights.isEmpty) {
      if (domainsRaw.isNotEmpty) {
        resolvedDomainWeights = domainsRaw.map((d) {
          final dMap = (d as Map).cast<String, dynamic>();
          return DomainWeightConstraint(
            domainId: dMap['id'] as String? ?? '',
            domainCode: dMap['code'] as String? ?? '1.0',
            domainTitle: dMap['title'] as String? ?? 'Domain ${dMap['code']}',
            weight: (dMap['weight'] as num?)?.toDouble() ?? 0.25,
          );
        }).toList();
      } else {
        resolvedDomainWeights = defaultClepDomainWeights(examCode);
      }
    }

    final now = DateTime.now();
    final items = <AssessmentItem>[];
    final itemDomainMap = <String, String>{};
    final itemConceptMap = <String, List<String>>{};

    for (int index = 0; index < questionsRaw.length; index++) {
      final q = questionsRaw[index];
      if (q is! Map) continue;
      final qMap = q.cast<String, dynamic>();
      final id = qMap['id'] as String;
      final cids = (qMap['concept_ids'] as List?)?.cast<String>() ?? const [];
      final meta = (qMap['metadata'] as Map?)?.cast<String, dynamic>() ?? const {};

      // Resolve domain code from:
      // 1. Direct question field
      // 2. Question metadata
      // 3. Fallback based on known College Board 60-question blueprint ordering
      //    (0..14: 1.0, 15..29: 2.0, 30..47: 3.0, 48..59: 4.0)
      String domainCode = qMap['domain_code'] as String? ??
          meta['domain_code'] as String? ??
          '';
      if (domainCode.isEmpty) {
        if (examCode == 'CLEP-ALG' && questionsRaw.length == 60) {
          if (index < 15) {
            domainCode = '1.0';
          } else if (index < 30) {
            domainCode = '2.0';
          } else if (index < 48) {
            domainCode = '3.0';
          } else {
            domainCode = '4.0';
          }
        } else {
          domainCode = '1.0';
        }
      }

      itemDomainMap[id] = domainCode;
      itemConceptMap[id] = cids;

      items.add(AssessmentItem(
        id: id,
        interactionType: AssessmentInteractionType.singleChoice,
        prompt: qMap['prompt'] as String? ?? '',
        responseSpec: (qMap['response_spec'] as Map?)?.cast<String, dynamic>() ?? const {},
        scoringSpec: const {}, // Protected: scoring keys are withheld server-side
        explanation: null, // Protected: explanations are withheld server-side
        metadata: meta,
        createdAt: now,
        updatedAt: now,
      ));
    }

    final blueprint = MockExamBlueprint(
      targetVersionId: targetVersionId,
      examCode: examCode,
      title: examTitle,
      timeLimitMinutes: timeLimitMins,
      defaultQuestionCount: items.length,
      allowedTools: allowedTools,
      domainWeights: resolvedDomainWeights,
      isProtectedSimulation: true,
      metadata: {
        'is_protected_simulation': true,
        'bank': 'simulation_exam',
        'exposure': 'timed_exam_only',
        'attempt_id': attemptId,
      },
    );

    return MockExamSession(
      id: attemptId,
      blueprint: blueprint,
      items: items,
      itemDomainMap: itemDomainMap,
      itemConceptMap: itemConceptMap,
      startedAt: issuedAt,
      timeLimit: Duration(minutes: timeLimitMins),
      status: ExamSessionStatus.inProgress,
    );
  }

  /// Submits student responses for confidential server-side grading.
  ///
  /// Guarantees:
  /// - Stored attempt results and client returns never disclose protected answer keys or item explanations.
  /// - Server calculates elapsed time and grades against the authoritative database bank.
  Future<ClepSimulationSubmissionResult> submitSimulationExam({
    required String attemptId,
    required Map<String, dynamic> responses,
  }) async {
    if (responses.isEmpty) {
      throw const ClepSimulationException(
        'Cannot submit empty responses: at least one answered question is required.',
        code: '22023',
      );
    }

    final raw = await _invokeRpc('clep_submit_simulation_exam', {
      'p_attempt_id': attemptId,
      'p_responses': responses,
    });

    if (raw is! Map) {
      throw const ClepSimulationException('Unexpected response payload from clep_submit_simulation_exam');
    }

    return ClepSimulationSubmissionResult.fromJson(
      raw.cast<String, dynamic>(),
      clientAnsweredCount: responses.length,
    );
  }

  /// Helper generating an [ExamDiagnosticReport] directly from a submission result and session.
  ExamDiagnosticReport createDiagnosticReport({
    required MockExamSession session,
    required ClepSimulationSubmissionResult result,
  }) {
    return result.toDiagnosticReport(session);
  }
}

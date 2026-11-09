import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/assessment_engine/mock_exam_blueprint.dart';
import '../../models/assessment_engine/mock_exam_session.dart';
import '../../models/assessment_item.dart';

/// Exception thrown when a server-side simulation exam operation fails.
class ClepSimulationException implements Exception {
  final String message;
  final String? code;

  const ClepSimulationException(this.message, {this.code});

  @override
  String toString() => 'ClepSimulationException: $message${code != null ? ' (code: $code)' : ''}';
}

/// Structured diagnostic result returned from confidential server-side exam scoring.
class ClepSimulationSubmissionResult {
  final String attemptId;
  final double percentage;
  final String readiness;
  final int correctCount;
  final int totalQuestions;
  final int answeredCount;
  final int timeSpentSeconds;
  final List<Map<String, dynamic>> itemResults;

  const ClepSimulationSubmissionResult({
    required this.attemptId,
    required this.percentage,
    required this.readiness,
    required this.correctCount,
    required this.totalQuestions,
    required this.answeredCount,
    required this.timeSpentSeconds,
    required this.itemResults,
  });

  factory ClepSimulationSubmissionResult.fromJson(Map<String, dynamic> json) {
    return ClepSimulationSubmissionResult(
      attemptId: json['attempt_id'] as String? ?? '',
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      readiness: json['readiness'] as String? ?? 'Pending Review',
      correctCount: (json['correct_count'] as num?)?.toInt() ?? 0,
      totalQuestions: (json['total_questions'] as num?)?.toInt() ?? 0,
      answeredCount: (json['answered_count'] as num?)?.toInt() ?? 0,
      timeSpentSeconds: (json['time_spent_seconds'] as num?)?.toInt() ?? 0,
      itemResults: (json['results'] as List?)?.cast<Map<String, dynamic>>() ?? const [],
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

  /// Issues an authenticated CLEP simulation exam from the database.
  ///
  /// Enforces:
  /// - Server-side authentication and single-attempt constraint.
  /// - Delivery of safe options only; scoring keys and explanations remain permanently server-side.
  /// - Proper exam tool policy mapping (e.g., allowedTools: {'calculator'} for College Algebra).
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

    final now = DateTime.now();
    final items = <AssessmentItem>[];
    for (final q in questionsRaw) {
      if (q is! Map) continue;
      final qMap = q.cast<String, dynamic>();
      items.add(AssessmentItem(
        id: qMap['id'] as String,
        interactionType: AssessmentInteractionType.singleChoice,
        prompt: qMap['prompt'] as String? ?? '',
        responseSpec: (qMap['response_spec'] as Map?)?.cast<String, dynamic>() ?? const {},
        scoringSpec: const {}, // Protected! scoring keys are withheld server-side
        explanation: null, // Protected! explanations are withheld server-side
        metadata: (qMap['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
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
      domainWeights: domainWeights,
    );

    return MockExamSession(
      id: attemptId,
      blueprint: blueprint,
      items: items,
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

    return ClepSimulationSubmissionResult.fromJson(raw.cast<String, dynamic>());
  }
}

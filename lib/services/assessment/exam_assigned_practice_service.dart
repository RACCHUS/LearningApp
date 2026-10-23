import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
final _partKey = RegExp(r'^[a-z][a-z0-9_]{0,127}$');

Map<String, dynamic> _exactObject(dynamic raw, Set<String> keys) {
  if (raw is! Map) throw const FormatException('Invalid practice response');
  final value = Map<String, dynamic>.from(raw);
  if (value.length != keys.length ||
      value.keys.toSet().difference(keys).isNotEmpty) {
    throw const FormatException('Unexpected practice response fields');
  }
  return value;
}

bool _validUuid(dynamic value) => value is String && _uuid.hasMatch(value);

/// Safe, ungraded question projection returned by the authenticated issuer.
/// No canonical answer, rubric, source token or answer hash is kept here.
class IssuedExamQuestion {
  final String id;
  final String prompt;
  final List<String> options;
  const IssuedExamQuestion._(this.id, this.prompt, this.options);
}

/// An opaque single-session assignment. Constructed only from checked RPC data.
class IssuedExamPractice {
  final String ownerId;
  final String sessionId;
  final String assignmentId;
  final String targetVersionId;
  final String examPartKey;
  final DateTime expiresAt;
  final List<IssuedExamQuestion> questions;
  const IssuedExamPractice._(
    this.ownerId,
    this.sessionId,
    this.assignmentId,
    this.targetVersionId,
    this.examPartKey,
    this.expiresAt,
    this.questions,
  );

  static IssuedExamPractice parse(
    dynamic raw, {
    required String expectedOwnerId,
    required String expectedSessionId,
    required String expectedTargetVersionId,
    required String expectedExamPartKey,
  }) {
    final data = _exactObject(raw, {
      'assignment_id', 'target_version_id', 'exam_part_key',
      'expires_at', 'practice_only', 'question_count', 'questions',
    });
    final entries = data['questions'];
    final expiry = DateTime.tryParse(data['expires_at']?.toString() ?? '');
    if (!_validUuid(data['assignment_id']) ||
        data['target_version_id'] != expectedTargetVersionId ||
        data['exam_part_key'] != expectedExamPartKey ||
        data['practice_only'] != true ||
        data['question_count'] != 6 ||
        expiry == null ||
        entries is! List ||
        entries.length != 6) {
      throw const FormatException('Invalid issued practice envelope');
    }
    final ids = <String>{};
    final questions = <IssuedExamQuestion>[];
    for (final entry in entries) {
      final q = _exactObject(entry, {
        'id', 'interaction_type', 'prompt', 'response_spec',
      });
      final options = _exactObject(q['response_spec'], {'options'})['options'];
      if (!_validUuid(q['id']) ||
          !ids.add(q['id'] as String) ||
          q['interaction_type'] != 'single_choice' ||
          q['prompt'] is! String ||
          (q['prompt'] as String).trim().isEmpty ||
          (q['prompt'] as String).length > 20000 ||
          options is! List ||
          options.length < 2 ||
          options.length > 10 ||
          options.any((x) =>
              x is! String || x.trim().isEmpty || x.length > 1000)) {
        throw const FormatException('Unsafe issued practice question');
      }
      questions.add(IssuedExamQuestion._(
        q['id'] as String,
        q['prompt'] as String,
        List<String>.unmodifiable(options.cast<String>()),
      ));
    }
    return IssuedExamPractice._(
      expectedOwnerId, expectedSessionId,
      data['assignment_id'] as String,
      expectedTargetVersionId, expectedExamPartKey, expiry,
      List<IssuedExamQuestion>.unmodifiable(questions),
    );
  }
}

/// Scores are accepted only from the server's canonical submission RPC.
class IssuedExamResult {
  final String attemptId;
  final int questionCount;
  final int fullyCorrectCount;
  final double practiceScore;
  final bool alreadyRecorded;
  const IssuedExamResult._(
    this.attemptId, this.questionCount, this.fullyCorrectCount,
    this.practiceScore, this.alreadyRecorded,
  );

  static IssuedExamResult parse(dynamic raw, IssuedExamPractice assignment) {
    final data = _exactObject(raw, {
      'attempt_id', 'target_version_id', 'exam_part_key',
      'question_count', 'fully_correct_count', 'partial_count',
      'practice_score', 'already_recorded', 'official_exam_result',
    });
    final count = data['question_count'];
    final correct = data['fully_correct_count'];
    final score = data['practice_score'];
    if (!_validUuid(data['attempt_id']) ||
        data['target_version_id'] != assignment.targetVersionId ||
        data['exam_part_key'] != assignment.examPartKey ||
        count != assignment.questions.length ||
        correct is! int || correct < 0 || correct > count ||
        data['partial_count'] != 0 ||
        score is! num || !score.toDouble().isFinite ||
        score < 0 || score > 1 ||
        data['already_recorded'] is! bool ||
        data['official_exam_result'] != false) {
      throw const FormatException('Invalid canonical practice receipt');
    }
    // Canonical scorer rounds to six decimal places.
    final expectedScore = correct / count;
    if ((score.toDouble() - expectedScore).abs() > 0.000001) {
      throw const FormatException('Inconsistent canonical practice score');
    }
    return IssuedExamResult._(
      data['attempt_id'] as String, count as int, correct,
      score.toDouble(), data['already_recorded'] as bool,
    );
  }
}

/// Dormant adapter for EXM-03 reviewed question delivery and submission.
/// Existing mock/diagnostic UI is intentionally NOT wired to this service.
/// The database remains the sole scorer and validates live-session ownership.
class ExamAssignedPracticeService {
  final SupabaseClient _client;
  final String? Function()? _testSessionId;
  final Future<dynamic> Function(String, String)? _testIssue;
  final Future<dynamic> Function(String, Map<String, int>)? _testSubmit;

  ExamAssignedPracticeService({
    SupabaseClient? client,
    String? Function()? testSessionId,
    Future<dynamic> Function(String, String)? testIssue,
    Future<dynamic> Function(String, Map<String, int>)? testSubmit,
  }) : _client = client ?? Supabase.instance.client,
       _testSessionId = testSessionId,
       _testIssue = testIssue,
       _testSubmit = testSubmit;

  // JWT session_id is stable across token refreshes. Reading it locally
  // is a privacy guard, NOT a substitute for server-side JWT validation.
  String? _sessionId() {
    if (_testSessionId != null) return _testSessionId();
    final token = _client.auth.currentSession?.accessToken;
    if (token == null) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final data = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (data is! Map) return null;
      final id = data['session_id'];
      return _validUuid(id) ? id as String : null;
    } on FormatException {
      return null;
    }
  }

  String _guard(String ownerId, {String? sessionId}) {
    final user = _client.auth.currentUser;
    final actualSession = _sessionId();
    if (ownerId.isEmpty || user == null || user.isAnonymous ||
        user.id != ownerId || !_validUuid(actualSession) ||
        (sessionId != null || actualSession == null) &&
            (sessionId != null && actualSession != sessionId)) {
      throw StateError('EXM practice account or session changed');
    }
    return actualSession!;
  }

  Future<IssuedExamPractice> issue({
    required String expectedOwnerId,
    required String targetVersionId,
    required String examPartKey,
  }) async {
    if (!_validUuid(targetVersionId) || !_partKey.hasMatch(examPartKey)) {
      throw ArgumentError('Exact exam target version and part are required');
    }
    final session = _guard(expectedOwnerId);
    final raw = _testIssue != null
        ? await _testIssue(targetVersionId, examPartKey)
        : await _client.rpc('exm03_issue_assigned_practice', params: {
            'p_target_version_id': targetVersionId,
            'p_exam_part_key': examPartKey,
          });
    _guard(expectedOwnerId, sessionId: session);
    return IssuedExamPractice.parse(
      raw, expectedOwnerId: expectedOwnerId,
      expectedSessionId: session,
      expectedTargetVersionId: targetVersionId,
      expectedExamPartKey: examPartKey,
    );
  }

  Future<IssuedExamResult> submit({
    required String expectedOwnerId,
    required IssuedExamPractice assignment,
    required Map<String, int> responses,
  }) async {
    final session = _guard(expectedOwnerId);
    if (assignment.ownerId != expectedOwnerId ||
        assignment.sessionId != session ||
        responses.length != assignment.questions.length) {
      throw StateError('Assignment does not belong to the active session');
    }
    final answers = Map<String, int>.from(responses);
    for (final question in assignment.questions) {
      final index = answers[question.id];
      if (index == null || index < 0 || index >= question.options.length) {
        throw ArgumentError('Every issued question needs a valid choice');
      }
    }
    if (answers.keys.toSet().difference(
      assignment.questions.map((q) => q.id).toSet()).isNotEmpty) {
      throw ArgumentError('Responses must match exact issued questions');
    }
    final raw = _testSubmit != null
        ? await _testSubmit(assignment.assignmentId, answers)
        : await _client.rpc('exm03_submit_assigned_practice', params: {
            'p_assignment_id': assignment.assignmentId,
            'p_responses': answers,
          });
    _guard(expectedOwnerId, sessionId: session);
    return IssuedExamResult.parse(raw, assignment);
  }
}

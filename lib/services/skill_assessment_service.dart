import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/skill.dart';
import '../models/assessment.dart';

/// Service for managing skills and assessments
class SkillAssessmentService {
  final SupabaseClient _supabase;

  SkillAssessmentService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  String? get _userId => _supabase.auth.currentUser?.id;

  // ============================================================================
  // SKILLS
  // ============================================================================

  /// Get all skills
  Future<List<Skill>> getSkills({String? category}) async {
    try {
      var query = _supabase.from('skills').select();

      if (category != null) {
        query = query.eq('category', category);
      }

      final response = await query.order('name');
      return (response as List).map((json) => Skill.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching skills: $e');
      rethrow;
    }
  }

  /// Get a skill by ID
  Future<Skill> getSkill(String skillId) async {
    try {
      final response =
          await _supabase.from('skills').select().eq('id', skillId).single();
      return Skill.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error fetching skill: $e');
      rethrow;
    }
  }

  /// Get skill by slug
  Future<Skill?> getSkillBySlug(String slug) async {
    try {
      final response =
          await _supabase.from('skills').select().eq('slug', slug).maybeSingle();
      return response != null ? Skill.fromJson(response) : null;
    } catch (e) {
      debugPrint('❌ Error fetching skill by slug: $e');
      rethrow;
    }
  }

  // ============================================================================
  // USER SKILL STATS
  // ============================================================================

  /// Get user's stats for all skills
  Future<List<UserSkillStats>> getUserSkillStats() async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User must be authenticated');
    }

    try {
      final response = await _supabase
          .from('user_skill_stats')
          .select('*, skills(*)')
          .eq('user_id', userId)
          .order('level', ascending: false);

      return (response as List)
          .map((json) => UserSkillStats.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching user skill stats: $e');
      rethrow;
    }
  }

  /// Get user's stats for a specific skill
  Future<UserSkillStats?> getUserSkillStat(String skillId) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User must be authenticated');
    }

    try {
      final response = await _supabase
          .from('user_skill_stats')
          .select('*, skills(*)')
          .eq('user_id', userId)
          .eq('skill_id', skillId)
          .maybeSingle();

      return response != null ? UserSkillStats.fromJson(response) : null;
    } catch (e) {
      debugPrint('❌ Error fetching user skill stat: $e');
      rethrow;
    }
  }

  // ============================================================================
  // ASSESSMENTS
  // ============================================================================

  /// Get assessments for a skill
  Future<List<SkillAssessment>> getAssessmentsForSkill(String skillId) async {
    try {
      final response = await _supabase
          .from('skill_assessments')
          .select('*, skills(*)')
          .eq('skill_id', skillId)
          .eq('is_active', true)
          .order('difficulty');

      return (response as List)
          .map((json) => SkillAssessment.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching assessments: $e');
      rethrow;
    }
  }

  /// Get questions for taking an assessment (sanitized: answers & explanations withheld)
  Future<List<AssessmentQuestion>> getQuestionsForTaking(String assessmentId) async {
    try {
      final response = await _supabase.rpc(
        'get_assessment_questions_for_taking',
        params: {'p_assessment_id': assessmentId},
      );
      return (response as List)
          .map((json) => AssessmentQuestion.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching sanitized questions: $e');
      rethrow;
    }
  }

  /// Get assessment with questions
  Future<SkillAssessment> getAssessmentWithQuestions(
    String assessmentId, {
    bool sanitizeForTaking = true,
  }) async {
    try {
      if (sanitizeForTaking) {
        final assessmentResponse = await _supabase
            .from('skill_assessments')
            .select('*, skills(*)')
            .eq('id', assessmentId)
            .single();

        final questions = await getQuestionsForTaking(assessmentId);
        final assessment = SkillAssessment.fromJson(assessmentResponse);
        return assessment.copyWith(questions: questions);
      } else {
        final response = await _supabase.from('skill_assessments').select('''
          *,
          skills(*),
          assessment_questions(*)
        ''').eq('id', assessmentId).single();

        return SkillAssessment.fromJson(response);
      }
    } catch (e) {
      debugPrint('❌ Error fetching assessment with questions: $e');
      rethrow;
    }
  }

  // ============================================================================
  // ASSESSMENT ATTEMPTS
  // ============================================================================

  /// Start a new assessment attempt authoritatively via server-side RPC
  Future<AssessmentAttempt> startAssessment(String assessmentId) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User must be authenticated');
    }

    try {
      final response = await _supabase.rpc(
        'start_assessment_attempt',
        params: {'p_assessment_id': assessmentId},
      );

      final attemptMap = Map<String, dynamic>.from(response as Map);
      debugPrint('✅ Assessment started via server RPC: ${attemptMap['id']}');
      return AssessmentAttempt.fromJson(attemptMap);
    } catch (e) {
      debugPrint('❌ Error starting assessment: $e');
      rethrow;
    }
  }

  /// Submit answer for a question (updates answers JSONB)
  Future<void> submitAnswer(
    String attemptId,
    String questionId,
    int answerIndex,
  ) async {
    try {
      // Get current answers
      final current = await _supabase
          .from('assessment_attempts')
          .select('answers')
          .eq('id', attemptId)
          .single();

      final answers =
          Map<String, dynamic>.from(current['answers'] as Map? ?? {});
      answers[questionId] = answerIndex;

      await _supabase
          .from('assessment_attempts')
          .update({'answers': answers}).eq('id', attemptId);

      debugPrint('✅ Answer submitted for question: $questionId');
    } catch (e) {
      debugPrint('❌ Error submitting answer: $e');
      rethrow;
    }
  }

  /// Complete an assessment and calculate score via trusted server-side grading RPC
  Future<AssessmentResult> completeAssessment(
    String attemptId, {
    bool wasOvertime = false,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User must be authenticated');
    }

    try {
      // 1. Get the attempt to obtain assessment_id, answers, and started_at
      final attemptResponse = await _supabase
          .from('assessment_attempts')
          .select('*, skill_assessments(*, skills(*))')
          .eq('id', attemptId)
          .single();

      final attempt = AssessmentAttempt.fromJson(attemptResponse);
      final assessment = attempt.assessment!;
      final userAnswers = attempt.answers ?? {};
      final startedAt = attempt.startedAt;
      final timeTaken = DateTime.now().difference(startedAt).inSeconds;

      // 2. Delegate grading to server-side SECURITY DEFINER RPC
      final gradeResponse = await _supabase.rpc(
        'submit_and_grade_assessment',
        params: {
          'p_assessment_id': assessment.id,
          'p_answers': userAnswers,
          'p_attempt_id': attemptId,
        },
      );

      final gradeMap = Map<String, dynamic>.from(gradeResponse as Map);
      final score = gradeMap['score'] as int? ?? 0;
      final correctCount = gradeMap['correct_count'] as int? ?? 0;
      final passed = gradeMap['passed'] as bool? ?? false;
      final previousLevel = gradeMap['previous_level'] as int? ?? 0;
      final newLevel = gradeMap['new_level'] as int? ?? 0;
      final isVerified = gradeMap['is_verified'] as bool? ?? true;
      final serverTimeTaken = gradeMap['time_spent_seconds'] as int? ?? timeTaken;
      final serverIsOvertime = gradeMap['is_overtime'] as bool? ?? wasOvertime;
      final returnedAttemptId = gradeMap['attempt_id'] as String? ?? attemptId;

      // Parse question results returned by server
      final rawResults = gradeMap['question_results'] as List? ?? [];
      final questionResults = rawResults.map((r) {
        final qMap = Map<String, dynamic>.from(r as Map);
        final question = AssessmentQuestion(
          id: qMap['question_id'] as String,
          assessmentId: assessment.id,
          questionText: qMap['question_text'] as String? ?? '',
          options: (qMap['options'] as List? ?? []).cast<String>(),
          correctAnswer: qMap['correct_answer'] as int?,
          explanation: qMap['explanation'] as String?,
          createdAt: DateTime.now(),
        );
        return QuestionResult(
          question: question,
          userAnswer: qMap['user_answer'] as int?,
          isCorrect: qMap['is_correct'] as bool? ?? false,
        );
      }).toList();

      debugPrint('✅ Assessment completed & server-graded: $score% ($correctCount/${questionResults.length}), verified: $isVerified');

      return AssessmentResult(
        attempt: attempt.copyWith(
          id: returnedAttemptId,
          score: score,
          correctCount: correctCount,
          totalQuestions: questionResults.length,
          completedAt: DateTime.now(),
          timeTakenSeconds: serverTimeTaken,
          wasOvertime: serverIsOvertime,
          isVerified: isVerified,
        ),
        assessment: assessment,
        previousLevel: previousLevel,
        newLevel: newLevel,
        passed: passed,
        questionResults: questionResults,
      );
    } catch (e) {
      debugPrint('❌ Error completing assessment: $e');
      rethrow;
    }
  }

  /// Get user's attempt history for an assessment
  Future<List<AssessmentAttempt>> getAttemptHistory(String assessmentId) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User must be authenticated');
    }

    try {
      final response = await _supabase
          .from('assessment_attempts')
          .select('*, skill_assessments(*)')
          .eq('user_id', userId)
          .eq('assessment_id', assessmentId)
          .eq('is_deleted', false)
          .order('started_at', ascending: false);

      return (response as List)
          .map((json) => AssessmentAttempt.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching attempt history: $e');
      rethrow;
    }
  }

  /// Get all attempts for a skill (across all assessments)
  Future<List<AssessmentAttempt>> getSkillAttempts(String skillId) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User must be authenticated');
    }

    try {
      final response = await _supabase
          .from('assessment_attempts')
          .select('*, skill_assessments!inner(*)')
          .eq('user_id', userId)
          .eq('skill_assessments.skill_id', skillId)
          .eq('is_deleted', false)
          .order('started_at', ascending: false);

      return (response as List)
          .map((json) => AssessmentAttempt.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching skill attempts: $e');
      rethrow;
    }
  }

  // ============================================================================
  // LEADERBOARD
  // ============================================================================

  /// Get leaderboard for a skill
  Future<List<LeaderboardEntry>> getSkillLeaderboard(
    String skillId, {
    int limit = 100,
  }) async {
    try {
      final response = await _supabase
          .from('skill_leaderboard')
          .select()
          .eq('skill_id', skillId)
          .order('rank')
          .limit(limit);

      return (response as List)
          .map((json) => LeaderboardEntry.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching leaderboard: $e');
      rethrow;
    }
  }

  /// Get user's rank on a skill leaderboard
  Future<int?> getUserRank(String skillId) async {
    final userId = _userId;
    if (userId == null) return null;

    try {
      final response = await _supabase
          .from('skill_leaderboard')
          .select('rank')
          .eq('skill_id', skillId)
          .eq('user_id', userId)
          .maybeSingle();

      return response?['rank'] as int?;
    } catch (e) {
      debugPrint('❌ Error fetching user rank: $e');
      return null;
    }
  }
}

/// Leaderboard entry
class LeaderboardEntry {
  final String skillId;
  final String skillName;
  final String userId;
  final String? displayName;
  final int level;
  final int bestScore;
  final int totalAssessments;
  final int rank;

  const LeaderboardEntry({
    required this.skillId,
    required this.skillName,
    required this.userId,
    this.displayName,
    required this.level,
    required this.bestScore,
    required this.totalAssessments,
    required this.rank,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      skillId: json['skill_id'] as String,
      skillName: json['skill_name'] as String,
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String?,
      level: json['level'] as int? ?? 0,
      bestScore: json['best_score'] as int? ?? 0,
      totalAssessments: json['total_assessments'] as int? ?? 0,
      rank: json['rank'] as int? ?? 0,
    );
  }

  SkillTier get tier => SkillTier.fromLevel(level);
}

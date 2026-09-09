import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/skill.dart';
import '../models/assessment.dart';

/// Service for managing skills and assessments
class SkillAssessmentService {
  final SupabaseClient _supabase;
  final _uuid = const Uuid();

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

  /// Get assessment with questions
  Future<SkillAssessment> getAssessmentWithQuestions(
      String assessmentId) async {
    try {
      final response = await _supabase.from('skill_assessments').select('''
        *,
        skills(*),
        assessment_questions(*)
      ''').eq('id', assessmentId).single();

      return SkillAssessment.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error fetching assessment with questions: $e');
      rethrow;
    }
  }

  // ============================================================================
  // ASSESSMENT ATTEMPTS
  // ============================================================================

  /// Start a new assessment attempt
  Future<AssessmentAttempt> startAssessment(String assessmentId) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User must be authenticated');
    }

    try {
      // Get the assessment to know question count
      final assessment = await getAssessmentWithQuestions(assessmentId);

      final response = await _supabase
          .from('assessment_attempts')
          .insert({
            'id': _uuid.v4(),
            'assessment_id': assessmentId,
            'user_id': userId,
            'started_at': DateTime.now().toIso8601String(),
            'total_questions': assessment.questions?.length ?? 0,
            'is_verified': true,
            'is_deleted': false,
          })
          .select()
          .single();

      debugPrint('✅ Assessment started: ${response['id']}');
      return AssessmentAttempt.fromJson(response);
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

  /// Complete an assessment and calculate score
  Future<AssessmentResult> completeAssessment(
    String attemptId, {
    bool wasOvertime = false,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User must be authenticated');
    }

    try {
      // Get the attempt with assessment and questions
      final attemptResponse = await _supabase
          .from('assessment_attempts')
          .select('*, skill_assessments(*, skills(*), assessment_questions(*))')
          .eq('id', attemptId)
          .single();

      final attempt = AssessmentAttempt.fromJson(attemptResponse);
      final assessment = attempt.assessment!;
      final questions = assessment.questions ?? [];
      final userAnswers = attempt.answers ?? {};

      // Calculate score
      int correctCount = 0;
      final questionResults = <QuestionResult>[];

      for (final question in questions) {
        final userAnswer = userAnswers[question.id];
        final isCorrect = userAnswer == question.correctAnswer;
        if (isCorrect) correctCount++;

        questionResults.add(QuestionResult(
          question: question,
          userAnswer: userAnswer,
          isCorrect: isCorrect,
        ));
      }

      final score = questions.isNotEmpty
          ? ((correctCount / questions.length) * 100).round()
          : 0;

      final startedAt = attempt.startedAt;
      final completedAt = DateTime.now();
      final timeTaken = completedAt.difference(startedAt).inSeconds;

      // Get previous level
      final prevStats = await getUserSkillStat(assessment.skillId);
      final previousLevel = prevStats?.level ?? 0;

      // Update the attempt
      await _supabase.from('assessment_attempts').update({
        'completed_at': completedAt.toIso8601String(),
        'score': score,
        'correct_count': correctCount,
        'time_taken_seconds': timeTaken,
        'was_overtime': wasOvertime,
      }).eq('id', attemptId);

      // Get new level (trigger should have updated it)
      final newStats = await getUserSkillStat(assessment.skillId);
      final newLevel = newStats?.level ?? 0;

      debugPrint('✅ Assessment completed: $score% ($correctCount/${questions.length})');

      return AssessmentResult(
        attempt: attempt.copyWith(
          score: score,
          correctCount: correctCount,
          completedAt: completedAt,
          timeTakenSeconds: timeTaken,
          wasOvertime: wasOvertime,
        ),
        assessment: assessment,
        previousLevel: previousLevel,
        newLevel: newLevel,
        passed: score >= assessment.passingScore,
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

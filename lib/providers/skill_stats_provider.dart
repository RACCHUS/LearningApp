import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/skill.dart';
import '../models/assessment.dart';
import '../services/skill_assessment_service.dart';
export 'assessment_provider.dart';

/// Service provider
final skillAssessmentServiceProvider = Provider<SkillAssessmentService>((ref) {
  return SkillAssessmentService();
});

// ============================================================================
// SKILLS
// ============================================================================

/// All skills
final skillsProvider = FutureProvider<List<Skill>>((ref) async {
  final service = ref.read(skillAssessmentServiceProvider);
  return service.getSkills();
});

/// Skills by category
final skillsByCategoryProvider =
    FutureProvider.family<List<Skill>, String>((ref, category) async {
  final service = ref.read(skillAssessmentServiceProvider);
  return service.getSkills(category: category);
});

/// Single skill by ID
final skillProvider = FutureProvider.family<Skill, String>((ref, skillId) async {
  final service = ref.read(skillAssessmentServiceProvider);
  return service.getSkill(skillId);
});

/// Skill by slug
final skillBySlugProvider =
    FutureProvider.family<Skill?, String>((ref, slug) async {
  final service = ref.read(skillAssessmentServiceProvider);
  return service.getSkillBySlug(slug);
});

// ============================================================================
// USER SKILL STATS
// ============================================================================

/// User's stats for all skills
final userSkillStatsProvider =
    StateNotifierProvider<UserSkillStatsNotifier, AsyncValue<List<UserSkillStats>>>(
        (ref) {
  final service = ref.read(skillAssessmentServiceProvider);
  return UserSkillStatsNotifier(service);
});

/// User's stats for a specific skill
final userSkillStatProvider =
    FutureProvider.family<UserSkillStats?, String>((ref, skillId) async {
  final service = ref.read(skillAssessmentServiceProvider);
  return service.getUserSkillStat(skillId);
});

class UserSkillStatsNotifier
    extends StateNotifier<AsyncValue<List<UserSkillStats>>> {
  final SkillAssessmentService _service;

  UserSkillStatsNotifier(this._service) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      state = const AsyncValue.loading();
      final stats = await _service.getUserSkillStats();
      state = AsyncValue.data(stats);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _load();
  }

  /// Get stats for a specific skill
  UserSkillStats? getStatsForSkill(String skillId) {
    return state.maybeWhen(
      data: (stats) {
        try {
          return stats.firstWhere((s) => s.skillId == skillId);
        } catch (_) {
          return null;
        }
      },
      orElse: () => null,
    );
  }

  /// Get top skills by level
  List<UserSkillStats> getTopSkills({int limit = 5}) {
    return state.maybeWhen(
      data: (stats) {
        final sorted = [...stats]..sort((a, b) => b.level.compareTo(a.level));
        return sorted.take(limit).toList();
      },
      orElse: () => [],
    );
  }

  /// Get skills that need practice (low level or not assessed recently)
  List<UserSkillStats> getNeedsPractice({int limit = 5}) {
    return state.maybeWhen(
      data: (stats) {
        final sorted = [...stats]..sort((a, b) {
            // Prioritize unverified, then low level, then old assessments
            if (a.isVerified != b.isVerified) {
              return a.isVerified ? 1 : -1;
            }
            return a.level.compareTo(b.level);
          });
        return sorted.take(limit).toList();
      },
      orElse: () => [],
    );
  }
}

// ============================================================================
// ASSESSMENTS
// ============================================================================

/// Assessments for a skill
final skillAssessmentsProvider =
    FutureProvider.family<List<SkillAssessment>, String>((ref, skillId) async {
  final service = ref.read(skillAssessmentServiceProvider);
  return service.getAssessmentsForSkill(skillId);
});

/// Single assessment with questions
final assessmentWithQuestionsProvider =
    FutureProvider.family<SkillAssessment, String>((ref, assessmentId) async {
  final service = ref.read(skillAssessmentServiceProvider);
  return service.getAssessmentWithQuestions(assessmentId);
});

/// Attempt history for an assessment
final attemptHistoryProvider =
    FutureProvider.family<List<AssessmentAttempt>, String>(
        (ref, assessmentId) async {
  final service = ref.read(skillAssessmentServiceProvider);
  return service.getAttemptHistory(assessmentId);
});

/// All attempts for a skill
final skillAttemptsProvider =
    FutureProvider.family<List<AssessmentAttempt>, String>(
        (ref, skillId) async {
  final service = ref.read(skillAssessmentServiceProvider);
  return service.getSkillAttempts(skillId);
});

// ============================================================================
// ASSESSMENT SESSION (extracted to assessment_provider.dart)
// ============================================================================

// ============================================================================
// LEADERBOARD
// ============================================================================

/// Leaderboard for a skill
final skillLeaderboardProvider =
    FutureProvider.family<List<LeaderboardEntry>, String>(
        (ref, skillId) async {
  final service = ref.read(skillAssessmentServiceProvider);
  return service.getSkillLeaderboard(skillId);
});

/// User's rank on a skill leaderboard
final userSkillRankProvider =
    FutureProvider.family<int?, String>((ref, skillId) async {
  final service = ref.read(skillAssessmentServiceProvider);
  return service.getUserRank(skillId);
});

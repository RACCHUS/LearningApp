import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_pwa/core/logging/app_logger.dart';
import 'package:learning_pwa/models/community/educator_reputation.dart';
import 'package:learning_pwa/models/community/educator_verification.dart';
import 'package:learning_pwa/services/community/educator_service.dart';

/// Service for calculating and retrieving evidence-weighted contributor reputations (ECO-04).
///
/// Implements Phase 2 Invariants:
/// - "Accepted answers and upvotes count more from verified contributors; no raw-count gaming."
/// - Multipliers reward licensed credentials (1.5x) and platform vetted (1.2x).
/// - Quality acceptance ratio penalizes spamming low-quality answers.
class EducatorReputationService {
  final _logger = AppLogger('EducatorReputationService');

  final SupabaseClient? _injectedClient;
  SupabaseClient? get _supabase {
    if (_injectedClient != null) return _injectedClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  final EducatorService _educatorService;

  EducatorReputationService({
    SupabaseClient? supabase,
    EducatorService? educatorService,
  })  : _injectedClient = supabase,
        _educatorService = educatorService ?? EducatorService(supabase: supabase);

  /// Synchronous evidence-weighted reputation calculation helper.
  EducatorReputation calculateReputation({
    required String educatorId,
    required int upvotesCount,
    required int acceptedAnswersCount,
    required int totalAnswersCount,
    List<EducatorVerification> verifications = const [],
  }) {
    return EducatorReputation.compute(
      educatorId: educatorId,
      upvotesCount: upvotesCount,
      acceptedAnswersCount: acceptedAnswersCount,
      totalAnswersCount: totalAnswersCount,
      verifications: verifications,
    );
  }

  /// Fetches an educator's activity stats and public verifications to compute reputation.
  Future<EducatorReputation> fetchReputation(String educatorId) async {
    try {
      final client = _supabase;
      if (client == null) {
        return calculateReputation(
          educatorId: educatorId,
          upvotesCount: 0,
          acceptedAnswersCount: 0,
          totalAnswersCount: 0,
        );
      }

      // 1. Fetch public verifications
      final verifications = await _educatorService.fetchPublicVerifications(educatorId);

      // 2. Fetch answer metrics for this author
      final answersRes = await client
          .from('community_answers')
          .select('id, upvote_count, is_accepted, status')
          .eq('author_id', educatorId)
          .eq('status', 'published');

      int upvotes = 0;
      int accepted = 0;
      final answersList = answersRes as List;
      final totalAnswers = answersList.length;

      for (final row in answersList) {
        if (row is Map<String, dynamic>) {
          upvotes += (row['upvote_count'] as int? ?? 0);
          if (row['is_accepted'] == true) {
            accepted++;
          }
        }
      }

      return calculateReputation(
        educatorId: educatorId,
        upvotesCount: upvotes,
        acceptedAnswersCount: accepted,
        totalAnswersCount: totalAnswers,
        verifications: verifications,
      );
    } catch (e, stack) {
      _logger.error('Failed to fetch reputation for educator $educatorId', error: e, stackTrace: stack);
      // Fallback default reputation
      return EducatorReputation.compute(
        educatorId: educatorId,
        upvotesCount: 0,
        acceptedAnswersCount: 0,
        totalAnswersCount: 0,
      );
    }
  }
}

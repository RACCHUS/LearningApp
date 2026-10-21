import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_pwa/core/logging/app_logger.dart';
import 'package:learning_pwa/models/community/community_question.dart';
import 'package:learning_pwa/models/community/community_answer.dart';

/// Service managing concept-scoped Community Q&A workflows (ECO-01).
///
/// Enforces Phase 1 private engineering boundaries:
/// - Fetches curated seed FAQs for in-context learning screens.
/// - Manages private/draft question submissions for learners.
/// - Atomic upvoting via the database RPC.
class CommunityQaService {
  final _logger = AppLogger('CommunityQaService');

  final SupabaseClient? _injectedClient;
  SupabaseClient get _supabase => _injectedClient ?? Supabase.instance.client;

  CommunityQaService({SupabaseClient? supabase})
      : _injectedClient = supabase;

  /// Fetches curated, published seed FAQs, optionally filtered by topic scope.
  Future<List<CommunityQuestion>> fetchSeedFaqs({
    String? conceptId,
    String? targetId,
    String? lessonId,
  }) async {
    try {
      var query = _supabase
          .from('community_questions')
          .select()
          .eq('status', 'published')
          .eq('is_seeded', true);

      if (conceptId != null && conceptId.isNotEmpty) {
        query = query.eq('concept_id', conceptId);
      } else if (targetId != null && targetId.isNotEmpty) {
        query = query.eq('target_id', targetId);
      } else if (lessonId != null && lessonId.isNotEmpty) {
        query = query.eq('lesson_id', lessonId);
      }

      final response = await query.order('upvote_count', ascending: false);
      final List<dynamic> rows = response as List<dynamic>;
      return rows
          .map((row) => CommunityQuestion.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      _logger.warn('Failed to fetch seed FAQs, falling back to offline defaults: $e', error: e, stackTrace: st);
      return _getOfflineSeedFaqs(conceptId: conceptId, targetId: targetId, lessonId: lessonId);
    }
  }

  /// Fetches all published questions associated with a concept.
  Future<List<CommunityQuestion>> fetchConceptQuestions(String conceptId) async {
    try {
      final response = await _supabase
          .from('community_questions')
          .select()
          .eq('concept_id', conceptId)
          .eq('status', 'published')
          .order('upvote_count', ascending: false);

      final List<dynamic> rows = response as List<dynamic>;
      return rows
          .map((row) => CommunityQuestion.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      _logger.warn('Failed to fetch concept questions: $e', error: e, stackTrace: st);
      return [];
    }
  }

  /// Fetches the authenticated user's private draft or under-review questions.
  Future<List<CommunityQuestion>> fetchMyDrafts() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _supabase
          .from('community_questions')
          .select()
          .eq('author_id', user.id)
          .inFilter('status', ['draft', 'under_review'])
          .order('created_at', ascending: false);

      final List<dynamic> rows = response as List<dynamic>;
      return rows
          .map((row) => CommunityQuestion.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      _logger.warn('Failed to fetch user drafts: $e', error: e, stackTrace: st);
      return [];
    }
  }

  /// Fetches answers for a specific community question.
  Future<List<CommunityAnswer>> fetchAnswersForQuestion(String questionId) async {
    try {
      final response = await _supabase
          .from('community_answers')
          .select()
          .eq('question_id', questionId)
          .eq('status', 'published')
          .order('is_accepted', ascending: false)
          .order('upvote_count', ascending: false);

      final List<dynamic> rows = response as List<dynamic>;
      return rows
          .map((row) => CommunityAnswer.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      _logger.warn('Failed to fetch answers for question $questionId: $e', error: e, stackTrace: st);
      return [];
    }
  }

  /// Creates a private draft question (or marks it under review).
  ///
  /// Non-admin users cannot publish directly to the public feed during Phase 1.
  Future<CommunityQuestion?> createDraftQuestion({
    required String title,
    required String bodyMarkdown,
    String? conceptId,
    String? targetId,
    String? lessonId,
    String? cipCode,
    bool submitForReview = false,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _logger.warn('Cannot create question: user is not authenticated');
      return null;
    }

    final status = submitForReview ? 'under_review' : 'draft';

    try {
      final data = {
        'author_id': user.id,
        'title': title.trim(),
        'body_markdown': bodyMarkdown.trim(),
        'status': status,
        'is_seeded': false,
        if (conceptId != null) 'concept_id': conceptId,
        if (targetId != null) 'target_id': targetId,
        if (lessonId != null) 'lesson_id': lessonId,
        if (cipCode != null) 'cip_code': cipCode,
      };

      final response = await _supabase
          .from('community_questions')
          .insert(data)
          .select()
          .single();

      return CommunityQuestion.fromJson(response);
    } catch (e, st) {
      _logger.error('Failed to create draft question: $e', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Toggles an upvote on a question or answer via the atomic database RPC.
  Future<Map<String, dynamic>> toggleVote({
    required String targetType,
    required String targetId,
  }) async {
    try {
      final response = await _supabase.rpc(
        'cast_community_vote',
        params: {
          'p_target_type': targetType,
          'p_target_id': targetId,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e, st) {
      _logger.error('Failed to cast community vote on $targetType $targetId: $e', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Offline fallback demonstration FAQs to ensure guidance remains accessible offline
  /// without presenting fabricated engagement metrics or unverified claims.
  List<CommunityQuestion> _getOfflineSeedFaqs({
    String? conceptId,
    String? targetId,
    String? lessonId,
  }) {
    final now = DateTime.now();
    final allSeeds = [
      CommunityQuestion(
        id: 'seed-faq-001',
        authorId: 'offline-demo',
        title: 'What is the CVC pattern in phonics?',
        bodyMarkdown: 'A CVC word is composed of a Consonant, a Short Vowel, and a Consonant (e.g., cat, dog, sun). Blending these three sounds together is the first step toward fluent reading.',
        status: 'published',
        isSeeded: true,
        conceptId: 'literacy.cvc.basics',
        viewCount: 0,
        upvoteCount: 0,
        answerCount: 0,
        createdAt: now,
        updatedAt: now,
      ),
      CommunityQuestion(
        id: 'seed-faq-002',
        authorId: 'offline-demo',
        title: 'How do sight words differ from decodable words?',
        bodyMarkdown: 'Decodable words can be sounded out letter-by-letter using standard phonics rules. Sight words frequently appear in English and may follow irregular spelling patterns, so learners memorize them for instant recognition.',
        status: 'published',
        isSeeded: true,
        conceptId: 'literacy.sight_words',
        viewCount: 0,
        upvoteCount: 0,
        answerCount: 0,
        createdAt: now,
        updatedAt: now,
      ),
      CommunityQuestion(
        id: 'seed-faq-003',
        authorId: 'offline-demo',
        title: 'What safety gear is required for OSHA general workplace standards?',
        bodyMarkdown: 'OSHA standard PPE typically requires hard hats, eye protection (safety glasses or goggles), slip-resistant steel-toe boots, and hearing protection in high-decibel zones.',
        status: 'published',
        isSeeded: true,
        conceptId: 'workplace.safety.ppe',
        viewCount: 0,
        upvoteCount: 0,
        answerCount: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    if (conceptId != null && conceptId.isNotEmpty) {
      return allSeeds.where((q) => q.conceptId == conceptId).toList();
    }
    return allSeeds;
  }
}

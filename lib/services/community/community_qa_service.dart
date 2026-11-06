import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_pwa/core/logging/app_logger.dart';
import 'package:learning_pwa/models/community/community_question.dart';
import 'package:learning_pwa/models/community/community_answer.dart';
import 'package:learning_pwa/models/community/community_review_audit.dart';
import 'package:learning_pwa/models/community/author_review_feedback.dart';
import 'package:learning_pwa/data/seed_faqs_catalog.dart';

/// Service managing concept-scoped Community Q&A workflows (ECO-01 & ECO-02).
///
/// Enforces Phase 1 private engineering boundaries:
/// - Fetches curated seed FAQs for in-context learning screens.
/// - Manages private/draft question submissions for learners.
/// - Provides moderator review workflows for queued questions and answers.
/// - Enforces single accepted answer mechanics.
/// - Atomic upvoting via the database RPC.
class CommunityQaService {
  final _logger = AppLogger('CommunityQaService');

  final SupabaseClient? _injectedClient;
  SupabaseClient get _supabase => _injectedClient ?? Supabase.instance.client;

  CommunityQaService({SupabaseClient? supabase})
      : _injectedClient = supabase;

  /// Returns the current authenticated user ID, or null if unauthenticated / offline.
  String? get currentUserId {
    try {
      return _supabase.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  /// Broadcast stream of authentication state changes.
  Stream<AuthState>? get authStateChanges {
    try {
      return _supabase.auth.onAuthStateChange;
    } catch (_) {
      return null;
    }
  }

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
      final result = rows
          .map((row) => CommunityQuestion.fromJson(row as Map<String, dynamic>))
          .toList();

      return result;
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

  /// Fetches questions awaiting educator or moderator review.
  ///
  /// Accessible only to users possessing moderator or admin privileges.
  Future<List<CommunityQuestion>> fetchUnderReviewQuestions({int limit = 50}) async {
    try {
      final response = await _supabase
          .from('community_questions')
          .select()
          .eq('status', 'under_review')
          .order('created_at', ascending: false)
          .limit(limit);

      final List<dynamic> rows = response as List<dynamic>;
      return rows
          .map((row) => CommunityQuestion.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      _logger.warn('Failed to fetch under-review questions: $e', error: e, stackTrace: st);
      return [];
    }
  }

  /// Fetches answers awaiting educator or moderator review.
  ///
  /// Accessible only to users possessing moderator or admin privileges.
  Future<List<CommunityAnswer>> fetchUnderReviewAnswers({int limit = 50}) async {
    try {
      final response = await _supabase
          .from('community_answers')
          .select()
          .eq('status', 'under_review')
          .order('created_at', ascending: false)
          .limit(limit);

      final List<dynamic> rows = response as List<dynamic>;
      return rows
          .map((row) => CommunityAnswer.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      _logger.warn('Failed to fetch under-review answers: $e', error: e, stackTrace: st);
      return [];
    }
  }

  /// Fetches durable review decision history for moderation and governance auditing.
  ///
  /// Accessible to moderators via RLS policy.
  Future<List<CommunityReviewAudit>> fetchReviewAuditHistory({
    String? targetType,
    String? targetId,
    int limit = 50,
  }) async {
    try {
      var query = _supabase
          .from('community_review_audit')
          .select();

      if (targetType != null) {
        query = query.eq('target_type', targetType);
      }
      if (targetId != null) {
        query = query.eq('target_id', targetId);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      final List<dynamic> rows = response as List<dynamic>;
      return rows
          .map((row) => CommunityReviewAudit.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      _logger.warn('Failed to fetch community review audit history: $e', error: e, stackTrace: st);
      return [];
    }
  }

  /// Fetches the authenticated user's private draft, under-review, or archived questions.
  Future<List<CommunityQuestion>> fetchMyDrafts() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final response = await _supabase
          .from('community_questions')
          .select()
          .eq('author_id', user.id)
          .inFilter('status', ['draft', 'under_review', 'archived'])
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

  /// Fetches the authenticated user's private draft, under-review, or archived answers.
  Future<List<CommunityAnswer>> fetchMyDraftAnswers() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final response = await _supabase
          .from('community_answers')
          .select()
          .eq('author_id', user.id)
          .inFilter('status', ['draft', 'under_review', 'archived'])
          .order('created_at', ascending: false);

      final List<dynamic> rows = response as List<dynamic>;
      return rows
          .map((row) => CommunityAnswer.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      _logger.warn('Failed to fetch user draft answers: $e', error: e, stackTrace: st);
      return [];
    }
  }

  /// Fetches decision feedback for the authenticated user's submissions.
  ///
  /// Calls the secure RPC [fetch_my_submission_feedback] which returns only feedback
  /// on items authored by the caller, without exposing internal moderation notes
  /// or reviewer identity.
  Future<List<AuthorReviewFeedback>> fetchMySubmissionFeedback({String? targetId}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final response = await _supabase.rpc(
        'fetch_my_submission_feedback',
        params: {
          if (targetId != null) 'p_target_id': targetId,
        },
      );

      final List<dynamic> rows = response as List<dynamic>;
      return rows
          .map((row) => AuthorReviewFeedback.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      _logger.warn('Failed to fetch submission feedback: $e', error: e, stackTrace: st);
      return [];
    }
  }

  /// Resolves question titles for a list of question UUIDs.
  Future<Map<String, String>> fetchQuestionTitles(List<String> questionIds) async {
    if (questionIds.isEmpty) return {};
    try {
      final uniqueIds = questionIds.toSet().toList();
      final response = await _supabase
          .from('community_questions')
          .select('id, title')
          .inFilter('id', uniqueIds);

      final List<dynamic> rows = response as List<dynamic>;
      final map = <String, String>{};
      for (final row in rows) {
        final id = row['id'] as String?;
        final title = row['title'] as String?;
        if (id != null && title != null) {
          map[id] = title;
        }
      }
      return map;
    } catch (e, st) {
      _logger.warn('Failed to fetch question titles: $e', error: e, stackTrace: st);
      return {};
    }
  }

  /// Resolves the parent question UUID for a list of answer UUIDs.
  Future<Map<String, String>> fetchAnswerParentQuestionMap(List<String> answerIds) async {
    if (answerIds.isEmpty) return {};
    try {
      final uniqueIds = answerIds.toSet().toList();
      final response = await _supabase
          .from('community_answers')
          .select('id, question_id')
          .inFilter('id', uniqueIds);

      final List<dynamic> rows = response as List<dynamic>;
      final map = <String, String>{};
      for (final row in rows) {
        final id = row['id'] as String?;
        final questionId = row['question_id'] as String?;
        if (id != null && questionId != null) {
          map[id] = questionId;
        }
      }
      return map;
    } catch (e, st) {
      _logger.warn('Failed to fetch answer parent question map: $e', error: e, stackTrace: st);
      return {};
    }
  }

  /// Returns a map of targetId -> latest AuthorReviewFeedback, preserving only the newest
  /// review decision for each submission target.
  Future<Map<String, AuthorReviewFeedback>> fetchLatestSubmissionFeedback({String? targetId}) async {
    final list = await fetchMySubmissionFeedback(targetId: targetId);
    final map = <String, AuthorReviewFeedback>{};
    for (final f in list) {
      map.putIfAbsent(f.targetId, () => f);
    }
    return map;
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
      final result = rows
          .map((row) => CommunityAnswer.fromJson(row as Map<String, dynamic>))
          .toList();

      if (result.isEmpty && questionId.startsWith('seed-faq-')) {
        return _getOfflineAnswersForQuestion(questionId);
      }
      return result;
    } catch (e, st) {
      _logger.warn('Failed to fetch answers for question $questionId: $e', error: e, stackTrace: st);
      return _getOfflineAnswersForQuestion(questionId);
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
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _logger.warn('Cannot create question: user is not authenticated');
        return null;
      }

      final status = submitForReview ? 'under_review' : 'draft';

      final data = {
        'author_id': user.id,
        'title': title.trim(),
        'body_markdown': bodyMarkdown.trim(),
        'status': status,
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

  /// Creates a draft answer (or marks it under review).
  ///
  /// Non-admin users cannot publish answers directly during Phase 1.
  Future<CommunityAnswer?> createDraftAnswer({
    required String questionId,
    required String bodyMarkdown,
    bool submitForReview = false,
    bool isAiGenerated = false,
    String? aiModelName,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _logger.warn('Cannot create answer: user is not authenticated');
        return null;
      }

      final status = submitForReview ? 'under_review' : 'draft';

      final data = {
        'question_id': questionId,
        'author_id': user.id,
        'body_markdown': bodyMarkdown.trim(),
        'status': status,
        'is_ai_generated': isAiGenerated,
        if (aiModelName != null) 'ai_model_name': aiModelName,
      };

      final response = await _supabase
          .from('community_answers')
          .insert(data)
          .select()
          .single();

      return CommunityAnswer.fromJson(response);
    } catch (e, st) {
      _logger.error('Failed to create draft answer: $e', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Updates an authored question draft or under-review submission.
  Future<CommunityQuestion?> updateQuestionDraft({
    required String questionId,
    required String title,
    required String bodyMarkdown,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final response = await _supabase
          .from('community_questions')
          .update({
            'title': title.trim(),
            'body_markdown': bodyMarkdown.trim(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', questionId)
          .eq('author_id', user.id)
          .select()
          .single();

      return CommunityQuestion.fromJson(response);
    } catch (e, st) {
      _logger.error('Failed to update question draft: $e', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Updates an authored answer draft or under-review submission.
  Future<CommunityAnswer?> updateAnswerDraft({
    required String answerId,
    required String bodyMarkdown,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final response = await _supabase
          .from('community_answers')
          .update({
            'body_markdown': bodyMarkdown.trim(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', answerId)
          .eq('author_id', user.id)
          .select()
          .single();

      return CommunityAnswer.fromJson(response);
    } catch (e, st) {
      _logger.error('Failed to update answer draft: $e', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Submits a moderation report on a community question or answer.
  Future<String> submitContentReport({
    required String targetType,
    required String targetId,
    required String reason,
    String? description,
  }) async {
    final response = await _supabase.rpc(
      'submit_moderation_report',
      params: {
        'p_target_type': targetType,
        'p_target_id': targetId,
        'p_reason': reason,
        if (description != null) 'p_description': description,
      },
    );
    return response.toString();
  }

  /// Reviews a community question via the atomic database RPC.
  ///
  /// Permitted actions: 'publish', 'reject', 'archive'.
  /// Requires caller to possess moderator or admin privileges.
  Future<Map<String, dynamic>> reviewQuestion({
    required String questionId,
    required String action,
    String? notes,
    String? internalNotes,
  }) async {
    try {
      final response = await _supabase.rpc(
        'review_community_question',
        params: {
          'p_question_id': questionId,
          'p_action': action,
          if (notes != null) 'p_notes': notes,
          if (internalNotes != null) 'p_internal_notes': internalNotes,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e, st) {
      _logger.error('Failed to review community question $questionId: $e', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Reviews a community answer via the atomic database RPC.
  ///
  /// Permitted actions: 'publish', 'reject', 'archive', 'flag'.
  /// Requires caller to possess moderator or admin privileges.
  Future<Map<String, dynamic>> reviewAnswer({
    required String answerId,
    required String action,
    String? notes,
    String? internalNotes,
  }) async {
    try {
      final response = await _supabase.rpc(
        'review_community_answer',
        params: {
          'p_answer_id': answerId,
          'p_action': action,
          if (notes != null) 'p_notes': notes,
          if (internalNotes != null) 'p_internal_notes': internalNotes,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e, st) {
      _logger.error('Failed to review community answer $answerId: $e', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Accepts an answer for a question via the atomic database RPC.
  ///
  /// Restricted to the question author or a moderator.
  /// Automatically unaccepts any previously accepted answer on that question.
  Future<Map<String, dynamic>> acceptAnswer({
    required String answerId,
  }) async {
    try {
      final response = await _supabase.rpc(
        'accept_community_answer',
        params: {
          'p_answer_id': answerId,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e, st) {
      _logger.error('Failed to accept community answer $answerId: $e', error: e, stackTrace: st);
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

  /// Offline fallback demonstration FAQs (36 curated pilot items from SeedFaqsCatalog)
  /// without presenting fabricated engagement metrics or unverified claims.
  List<CommunityQuestion> _getOfflineSeedFaqs({
    String? conceptId,
    String? targetId,
    String? lessonId,
  }) {
    final allSeeds = SeedFaqsCatalog.allQuestions;

    if (conceptId != null && conceptId.isNotEmpty) {
      return allSeeds.where((q) => q.conceptId == conceptId).toList();
    }
    if (targetId != null && targetId.isNotEmpty) {
      return allSeeds.where((q) => q.targetId == targetId).toList();
    }
    if (lessonId != null && lessonId.isNotEmpty) {
      return allSeeds.where((q) => q.lessonId == lessonId).toList();
    }
    return allSeeds;
  }

  /// Provides offline answers corresponding to offline demo FAQs from SeedFaqsCatalog.
  List<CommunityAnswer> _getOfflineAnswersForQuestion(String questionId) {
    return SeedFaqsCatalog.getAnswersForQuestion(questionId);
  }
}

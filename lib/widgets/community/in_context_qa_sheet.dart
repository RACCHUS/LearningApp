import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;
import 'package:learning_pwa/models/community/community_question.dart';
import 'package:learning_pwa/models/community/community_answer.dart';
import 'package:learning_pwa/models/community/community_answer_revision.dart';
import 'package:learning_pwa/models/community/community_review_audit.dart';
import 'package:learning_pwa/models/community/author_review_feedback.dart';
import 'package:learning_pwa/services/community/community_qa_service.dart';
import 'package:learning_pwa/services/governance/moderation_service.dart';
import 'package:learning_pwa/theme/design_tokens.dart';
import 'package:learning_pwa/models/governance/moderation_report.dart';
import 'package:learning_pwa/services/community/spam_rate_limiter.dart';
import 'package:learning_pwa/widgets/community/report_content_dialog.dart';
import 'package:learning_pwa/widgets/community/adult_age_confirmation_dialog.dart';
import 'package:learning_pwa/models/community/community_bookmark.dart';
import 'package:learning_pwa/models/community/educator_profile.dart';
import 'package:learning_pwa/models/community/educator_reputation.dart';
import 'package:learning_pwa/models/community/educator_verification.dart';
import 'package:learning_pwa/services/community/educator_service.dart';
import 'package:learning_pwa/services/community/educator_reputation_service.dart';
import 'package:learning_pwa/services/community/community_bookmark_service.dart';
import 'package:learning_pwa/widgets/community/educator_credential_badge.dart';
import 'package:learning_pwa/widgets/community/bookmarked_explanations_sheet.dart';
import 'package:learning_pwa/widgets/community/qa_audit_log_list.dart';
import 'package:learning_pwa/widgets/community/answer_revisions_dialog.dart';
import 'package:learning_pwa/widgets/community/qa_review_dialogs.dart';

part 'qa_sheet/faqs_tab.dart';
part 'qa_sheet/ask_tab.dart';
part 'qa_sheet/my_drafts_tab.dart';
part 'qa_sheet/review_queue_tab.dart';

/// Opens the in-context Concept Q&A sheet for learning screens (ECO-01 & ECO-02).
Future<void> showInContextQaSheet(
  BuildContext context, {
  String? conceptId,
  String? targetId,
  String? lessonId,
  String? topicTitle,
  CommunityQaService? service,
  ModerationService? moderationService,
  EducatorService? educatorService,
  EducatorReputationService? reputationService,
  CommunityBookmarkService? bookmarkService,
  bool isAdultConfirmed = false,
  bool answerHistoryEnabled = false,
  bool educatorProfilesEnabled = false,
}) {
  final width = MediaQuery.sizeOf(context).width;
  final effectiveService = service ?? CommunityQaService();
  final effectiveModService = moderationService ?? ModerationService();

  if (width < DesignTokens.breakpointTablet) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * 0.88,
        child: InContextQaSheet(
          key: ValueKey(effectiveService.currentUserId ?? 'anon'),
          conceptId: conceptId,
          targetId: targetId,
          lessonId: lessonId,
          topicTitle: topicTitle,
          service: effectiveService,
          moderationService: effectiveModService,
          educatorService: educatorService,
          reputationService: reputationService,
          bookmarkService: bookmarkService,
          isAdultConfirmed: isAdultConfirmed,
          answerHistoryEnabled: answerHistoryEnabled,
          educatorProfilesEnabled: educatorProfilesEnabled,
        ),
      ),
    );
  }

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.82,
        ),
        child: SizedBox(
          width: 640,
          child: InContextQaSheet(
            key: ValueKey(effectiveService.currentUserId ?? 'anon'),
            conceptId: conceptId,
            targetId: targetId,
            lessonId: lessonId,
            topicTitle: topicTitle,
            service: effectiveService,
            moderationService: effectiveModService,
            educatorService: educatorService,
            reputationService: reputationService,
            bookmarkService: bookmarkService,
            isAdultConfirmed: isAdultConfirmed,
            answerHistoryEnabled: answerHistoryEnabled,
            educatorProfilesEnabled: educatorProfilesEnabled,
          ),
        ),
      ),
    ),
  );
}

class InContextQaSheet extends StatefulWidget {
  final String? conceptId;
  final String? targetId;
  final String? lessonId;
  final String? topicTitle;
  final CommunityQaService service;
  final ModerationService? moderationService;
  final EducatorService? educatorService;
  final EducatorReputationService? reputationService;
  final CommunityBookmarkService? bookmarkService;
  final bool isAdultConfirmed;

  /// `learning.answer_revisions`: show earlier versions of resubmitted
  /// answers and link new resubmissions to them. Off: no extra requests.
  final bool answerHistoryEnabled;

  /// `learning.educator_profiles`: link answer authors to their profile.
  final bool educatorProfilesEnabled;

  const InContextQaSheet({
    super.key,
    this.conceptId,
    this.targetId,
    this.lessonId,
    this.topicTitle,
    required this.service,
    this.moderationService,
    this.educatorService,
    this.reputationService,
    this.bookmarkService,
    this.isAdultConfirmed = false,
    this.answerHistoryEnabled = false,
    this.educatorProfilesEnabled = false,
  });

  @override
  State<InContextQaSheet> createState() => InContextQaSheetState();
}

class InContextQaSheetState extends State<InContextQaSheet> with SingleTickerProviderStateMixin {
  @visibleForTesting
  Future<void> reloadReviewDataForTesting() => _reloadReviewData();

  @visibleForTesting
  Future<void> loadDataForTesting() => _loadData();

  TabController? _tabController;
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _activeUserId;
  int _authSessionGeneration = 0;
  int _loadDataSeq = 0;
  int _reloadReviewSeq = 0;

  BuildContext? _activeRevisionDialogContext;
  BuildContext? _activeRejectionDialogContext;
  BuildContext? _activeLaunchGateDialogContext;

  StreamSubscription<AuthState>? _authSubscription;

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isModerator = false;
  late bool _isAdultConfirmed;
  int _reviewSubTab = 0; // 0: Questions, 1: Answers, 2: Audit History
  String? _statusMessage;
  List<CommunityQuestion> _seedFaqs = [];
  List<CommunityQuestion> _myDrafts = [];
  List<CommunityAnswer> _myDraftAnswers = [];
  Map<String, AuthorReviewFeedback> _submissionFeedback = {};
  Map<String, List<CommunityAnswerRevision>> _answerRevisions = {};
  int _answerRevisionsSeq = 0;
  List<CommunityQuestion> _reviewQuestions = [];
  List<CommunityAnswer> _reviewAnswers = [];
  List<CommunityReviewAudit> _auditLogs = [];
  Map<String, String> _answerParentQuestionIds = {};
  Map<String, String> _questionTitles = {};
  final Map<String, List<CommunityAnswer>> _answersCache = {};
  final Set<String> _expandedQuestions = {};
  final Set<String> _userUpvoted = {};
  final SpamRateLimiter _spamLimiter = SpamRateLimiter();
  late final EducatorService _educatorService;
  late final EducatorReputationService _reputationService;
  late final CommunityBookmarkService _bookmarkService;
  final Map<String, List<EducatorVerification>> _authorVerificationsCache = {};
  final Map<String, EducatorProfile> _authorProfilesCache = {};
  final Map<String, EducatorReputation> _authorReputationsCache = {};

  Future<void> _handleReportQuestion(CommunityQuestion q) async {
    if (widget.moderationService == null) return;
    await ReportContentDialog.show(
      context,
      targetType: ModerationTargetType.communityQuestion,
      targetId: q.id,
      contentSnippet: q.title,
      moderationService: widget.moderationService!,
    );
  }

  Future<void> _handleReportAnswer(CommunityAnswer ans) async {
    if (widget.moderationService == null) return;
    await ReportContentDialog.show(
      context,
      targetType: ModerationTargetType.communityAnswer,
      targetId: ans.id,
      contentSnippet: ans.bodyMarkdown.length > 80
          ? '${ans.bodyMarkdown.substring(0, 80)}...'
          : ans.bodyMarkdown,
      moderationService: widget.moderationService!,
    );
  }

  bool _isSessionValid(int sessionGen, String? sessionUserId) {
    return mounted && sessionGen == _authSessionGeneration && widget.service.currentUserId == sessionUserId;
  }

  void _dismissActiveDialogs() {
    final revCtx = _activeRevisionDialogContext;
    _activeRevisionDialogContext = null;
    if (revCtx != null && revCtx.mounted) {
      Navigator.of(revCtx, rootNavigator: true).pop();
    }

    final rejCtx = _activeRejectionDialogContext;
    _activeRejectionDialogContext = null;
    if (rejCtx != null && rejCtx.mounted) {
      Navigator.of(rejCtx, rootNavigator: true).pop();
    }

    final gateCtx = _activeLaunchGateDialogContext;
    _activeLaunchGateDialogContext = null;
    if (gateCtx != null && gateCtx.mounted) {
      Navigator.of(gateCtx, rootNavigator: true).pop();
    }
  }

  String _formatAuthorId(String id) => formatQaAuthorId(id);

  /// For the tab extensions in qa_sheet/ (they may not call the protected
  /// setState directly).
  void _update(VoidCallback fn) => setState(fn);

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  @override
  void initState() {
    super.initState();
    _isAdultConfirmed = widget.isAdultConfirmed;
    _activeUserId = widget.service.currentUserId;
    _educatorService = widget.educatorService ?? EducatorService();
    _reputationService = widget.reputationService ?? EducatorReputationService(educatorService: _educatorService);
    _bookmarkService = widget.bookmarkService ?? CommunityBookmarkService();
    _subscribeToAuthChanges();
    _loadData();
  }

  void _subscribeToAuthChanges() {
    _authSubscription = widget.service.authStateChanges?.listen((event) {
      final newUserId = event.session?.user.id;
      if (newUserId != _activeUserId) {
        _onUserChanged(newUserId);
      }
    });
  }

  void _onUserChanged(String? newUserId) {
    if (!mounted) return;
    _authSessionGeneration++;
    _isAdultConfirmed = widget.isAdultConfirmed;
    _dismissActiveDialogs();
    _titleController.clear();
    _bodyController.clear();
    setState(() {
      _activeUserId = newUserId;
      _isSubmitting = false;
      _statusMessage = null;
      _myDrafts = [];
      _myDraftAnswers = [];
      _submissionFeedback = {};
      _answerRevisions = {};
      _reviewQuestions = [];
      _reviewAnswers = [];
      _auditLogs = [];
      _answerParentQuestionIds = {};
      _questionTitles = {};
      _answersCache.clear();
      _expandedQuestions.clear();
      _userUpvoted.clear();
      _isModerator = false;
      _isLoading = true;
    });
    _loadData();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _dismissActiveDialogs();
    _tabController?.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final int sessionGen = _authSessionGeneration;
    final int loadSeq = ++_loadDataSeq;
    final String? sessionUserId = widget.service.currentUserId;

    setState(() {
      _isLoading = true;
      _activeUserId = sessionUserId;
    });

    try {
      final faqs = await widget.service.fetchSeedFaqs(
        conceptId: widget.conceptId,
        targetId: widget.targetId,
        lessonId: widget.lessonId,
      );
      final drafts = await widget.service.fetchMyDrafts();
      final draftAnswers = await widget.service.fetchMyDraftAnswers();
      final feedbackMap = await widget.service.fetchLatestSubmissionFeedback();

      bool isMod = false;
      List<CommunityQuestion> reviewQuestions = [];
      List<CommunityAnswer> reviewAnswers = [];
      List<CommunityReviewAudit> auditLogs = [];
      Map<String, String> answerParentMap = {};
      Map<String, String> questionTitles = {};

      try {
        final modService = widget.moderationService ?? ModerationService();
        isMod = await modService.isModerator();
        if (isMod) {
          reviewQuestions = await widget.service.fetchUnderReviewQuestions();
          reviewAnswers = await widget.service.fetchUnderReviewAnswers();
          auditLogs = await widget.service.fetchReviewAuditHistory(limit: 25);

          final answerAuditTargetIds = auditLogs.where((l) => l.isAnswer).map((l) => l.targetId).toList();
          final rawAnswerParentMap = await widget.service.fetchAnswerParentQuestionMap(answerAuditTargetIds);
          answerParentMap = Map<String, String>.from(rawAnswerParentMap);
          for (final a in [...reviewAnswers, ...draftAnswers]) {
            answerParentMap[a.id] = a.questionId;
          }

          final questionIdsToResolve = <String>{
            ...reviewAnswers.map((a) => a.questionId),
            ...draftAnswers.map((a) => a.questionId),
            ...auditLogs.where((l) => l.isQuestion).map((l) => l.targetId),
            ...answerParentMap.values,
          }.toList();
          questionTitles = await widget.service.fetchQuestionTitles(questionIdsToResolve);
        } else if (draftAnswers.isNotEmpty) {
          for (final a in draftAnswers) {
            answerParentMap[a.id] = a.questionId;
          }
          final questionIdsToResolve = draftAnswers.map((a) => a.questionId).toSet().toList();
          questionTitles = await widget.service.fetchQuestionTitles(questionIdsToResolve);
        }
      } catch (_) {}

      if (!_isSessionValid(sessionGen, sessionUserId) || loadSeq != _loadDataSeq) {
        return;
      }

      final targetLength = isMod ? 4 : 3;
      if (_tabController == null || _tabController!.length != targetLength) {
        final oldController = _tabController;
        _tabController = TabController(length: targetLength, vsync: this);
        oldController?.dispose();
      }
      setState(() {
        _seedFaqs = faqs;
        _myDrafts = drafts;
        _myDraftAnswers = draftAnswers;
        _submissionFeedback = feedbackMap;
        _reviewQuestions = reviewQuestions;
        _reviewAnswers = reviewAnswers;
        _auditLogs = auditLogs;
        _answerParentQuestionIds = answerParentMap;
        _questionTitles = questionTitles;
        _isModerator = isMod;
        _isLoading = false;
      });
      unawaited(_refreshAnswerRevisions());
    } catch (_) {
      if (!_isSessionValid(sessionGen, sessionUserId) || loadSeq != _loadDataSeq) {
        return;
      }
      if (_tabController == null || _tabController!.length != 3) {
        final oldController = _tabController;
        _tabController = TabController(length: 3, vsync: this);
        oldController?.dispose();
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _reloadReviewData() async {
    final int sessionGen = _authSessionGeneration;
    final int reviewSeq = ++_reloadReviewSeq;
    final String? sessionUserId = widget.service.currentUserId;

    try {
      final reviewQuestions = await widget.service.fetchUnderReviewQuestions();
      final reviewAnswers = await widget.service.fetchUnderReviewAnswers();
      final auditLogs = await widget.service.fetchReviewAuditHistory(limit: 25);
      final faqs = await widget.service.fetchSeedFaqs(
        conceptId: widget.conceptId,
        targetId: widget.targetId,
        lessonId: widget.lessonId,
      );
      final answerAuditTargetIds = auditLogs.where((l) => l.isAnswer).map((l) => l.targetId).toList();
      final rawAnswerParentMap = await widget.service.fetchAnswerParentQuestionMap(answerAuditTargetIds);
      final answerParentMap = Map<String, String>.from(rawAnswerParentMap);
      for (final a in [...reviewAnswers, ..._myDraftAnswers]) {
        answerParentMap[a.id] = a.questionId;
      }
      final questionIdsToResolve = <String>{
        ...reviewAnswers.map((a) => a.questionId),
        ..._myDraftAnswers.map((a) => a.questionId),
        ...auditLogs.where((l) => l.isQuestion).map((l) => l.targetId),
        ...answerParentMap.values,
      }.toList();
      final questionTitles = await widget.service.fetchQuestionTitles(questionIdsToResolve);

      if (!_isSessionValid(sessionGen, sessionUserId) || reviewSeq != _reloadReviewSeq) {
        return;
      }

      setState(() {
        _reviewQuestions = reviewQuestions;
        _reviewAnswers = reviewAnswers;
        _auditLogs = auditLogs;
        _seedFaqs = faqs;
        _answerParentQuestionIds = answerParentMap;
        _questionTitles = questionTitles;
      });
      unawaited(_refreshAnswerRevisions());
    } catch (_) {}
  }

  /// Loads earlier versions for the learner's own answers and, for
  /// moderators, the review queue. Only when the gate is ON.
  Future<void> _refreshAnswerRevisions() async {
    if (!widget.answerHistoryEnabled) return;
    final int sessionGen = _authSessionGeneration;
    final int seq = ++_answerRevisionsSeq;
    final String? sessionUserId = widget.service.currentUserId;
    final ids = <String>{
      ..._myDraftAnswers.map((a) => a.id),
      ..._reviewAnswers.map((a) => a.id),
    }.toList();
    final revisions = await widget.service.fetchAnswerRevisions(ids);
    if (!mounted ||
        !_isSessionValid(sessionGen, sessionUserId) ||
        seq != _answerRevisionsSeq) {
      return;
    }
    setState(() => _answerRevisions = revisions);
  }

  Future<void> _loadAnswers(String questionId) async {
    if (_answersCache.containsKey(questionId)) return;
    final int sessionGen = _authSessionGeneration;
    final String? sessionUserId = widget.service.currentUserId;
    try {
      final answers = await widget.service.fetchAnswersForQuestion(questionId);
      if (!_isSessionValid(sessionGen, sessionUserId)) {
        return;
      }
      setState(() {
        _answersCache[questionId] = answers;
      });
      for (final a in answers) {
        if (a.authorId.isNotEmpty && a.authorId != 'offline-demo' && a.authorId != 'system') {
          _fetchAuthorVerifications(a.authorId);
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchAuthorVerifications(String authorId) async {
    if (_authorVerificationsCache.containsKey(authorId)) return;
    try {
      final vers = await _educatorService.fetchPublicVerifications(authorId);
      final profile = await _educatorService.fetchProfile(authorId);
      final rep = await _reputationService.fetchReputation(authorId);
      if (mounted) {
        setState(() {
          _authorVerificationsCache[authorId] = vers;
          if (profile != null) {
            _authorProfilesCache[authorId] = profile;
          }
          _authorReputationsCache[authorId] = rep;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleBookmark(CommunityAnswer ans, CommunityQuestion q) async {
    final isBookmarked = _bookmarkService.isBookmarked(ans.id);
    if (isBookmarked) {
      await _bookmarkService.removeBookmark(ans.id);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from saved bookmarks')),
        );
      }
    } else {
      final bmk = CommunityBookmark(
        id: 'bmk_${ans.id}',
        userId: widget.service.currentUserId ?? 'local_user',
        contentType: 'answer',
        contentId: ans.id,
        title: q.title,
        bodySnippet: ans.bodyMarkdown.length > 120
            ? '${ans.bodyMarkdown.substring(0, 120)}...'
            : ans.bodyMarkdown,
        conceptId: q.conceptId ?? widget.conceptId,
        authorId: ans.authorId,
        authorDisplayName: _authorProfilesCache[ans.authorId]?.displayName ?? (ans.isSeeded ? 'Curated FAQ' : 'Community Educator'),
        isVerifiedAuthor: _authorVerificationsCache[ans.authorId]?.any((v) => v.isVerified) ?? false,
        createdAt: DateTime.now(),
      );
      await _bookmarkService.addBookmark(bmk);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to bookmarks for study review')),
        );
      }
    }
  }

  void _openBookmarksSheet() {
    BookmarkedExplanationsSheet.show(
      context,
      bookmarkService: _bookmarkService,
      filterConceptId: widget.conceptId,
    );
  }

  Future<void> _openTeachThisTopicDialog(CommunityQuestion q) async {
    if (!_isAdultConfirmed) {
      final confirmed = await AdultAgeConfirmationDialog.show(context);
      if (confirmed != true) return;
      if (mounted) {
        setState(() => _isAdultConfirmed = true);
      }
    }

    if (widget.service.currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in as an adult contributor to teach this topic.'),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (_) => QaTeachTopicDialog(
        question: q,
        onSubmit: (text) => widget.service.createDraftAnswer(
          questionId: q.id,
          bodyMarkdown: text,
          submitForReview: true,
        ),
      ),
    );
    if (submitted != true) return;
    _answersCache.remove(q.id);
    await _loadAnswers(q.id);
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Answer submitted for editorial review!')),
      );
    }
  }

  Widget _buildTeachThisTopicBanner(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.school, color: Colors.teal, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Teach This Topic',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal),
                ),
                Text(
                  'Subject experts: share explanations and earn evidence-weighted reputation.',
                  style: TextStyle(fontSize: 11, color: Colors.teal.shade900),
                ),
              ],
            ),
          ),
          if (_seedFaqs.isNotEmpty)
            FilledButton.tonal(
              key: const Key('teach_first_topic_button'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              onPressed: () {
                final firstQ = _seedFaqs.first;
                _openTeachThisTopicDialog(firstQ);
              },
              child: const Text('Contribute', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Future<void> _handleVote(CommunityQuestion question) async {
    if (question.authorId == 'offline-demo') return;
    final int sessionGen = _authSessionGeneration;
    final String? sessionUserId = widget.service.currentUserId;
    try {
      final result = await widget.service.toggleVote(
        targetType: 'question',
        targetId: question.id,
      );
      if (!_isSessionValid(sessionGen, sessionUserId)) {
        return;
      }
      final bool voted = result['voted'] as bool? ?? false;
      final int newCount = result['upvote_count'] as int? ?? question.upvoteCount;

      setState(() {
        if (voted) {
          _userUpvoted.add(question.id);
        } else {
          _userUpvoted.remove(question.id);
        }
        final idx = _seedFaqs.indexWhere((q) => q.id == question.id);
        if (idx != -1) {
          _seedFaqs[idx] = _seedFaqs[idx].copyWith(upvoteCount: newCount);
        }
      });
    } catch (_) {}
  }

  Future<void> _handleAcceptAnswer(String answerId, String questionId) async {
    final int sessionGen = _authSessionGeneration;
    final String? sessionUserId = widget.service.currentUserId;
    try {
      await widget.service.acceptAnswer(answerId: answerId);
      final updatedAnswers = await widget.service.fetchAnswersForQuestion(questionId);
      if (!_isSessionValid(sessionGen, sessionUserId)) {
        return;
      }
      setState(() {
        _answersCache[questionId] = updatedAnswers;
      });
    } catch (_) {}
  }

  Future<void> _handleReviewQuestion(
    String questionId,
    String action, {
    String? notes,
    String? internalNotes,
  }) async {
    try {
      await widget.service.reviewQuestion(
        questionId: questionId,
        action: action,
        notes: notes,
        internalNotes: internalNotes,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Question review action "$action" recorded successfully.'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      await _reloadReviewData();
    } catch (e) {
      _handleReviewError(e, action: action, targetType: 'question');
    }
  }

  Future<void> _handleReviewAnswer(
    String answerId,
    String action, {
    String? notes,
    String? internalNotes,
  }) async {
    try {
      await widget.service.reviewAnswer(
        answerId: answerId,
        action: action,
        notes: notes,
        internalNotes: internalNotes,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Answer review action "$action" recorded successfully.'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      await _reloadReviewData();
    } catch (e) {
      _handleReviewError(e, action: action, targetType: 'answer');
    }
  }

  void _handleReviewError(dynamic error, {required String action, required String targetType}) {
    final errorString = error.toString();
    if (errorString.contains('Public learner UGC is currently disabled') || errorString.contains('22000')) {
      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (ctx) {
            _activeLaunchGateDialogContext = ctx;
            return AlertDialog(
              icon: const Icon(Icons.lock_clock, color: Colors.amber, size: 36),
              title: const Text('Phase 1 Launch Gate Active'),
              content: Text(
                'Public learner UGC is disabled during Phase 1 private testing. '
                'Learner $targetType items cannot be published publicly before operational launch clearance. '
                'The submission remains preserved under review.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Understood'),
                ),
              ],
            );
          },
        ).then((_) {
          _activeLaunchGateDialogContext = null;
        });
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red[800],
            content: Text('Failed to $action $targetType: $errorString'),
          ),
        );
      }
    }
  }

  Future<void> _showRejectionDialog({
    required String targetType,
    required String targetId,
    required String title,
  }) async {
    final result = await showDialog<(String?, String?)>(
      context: context,
      builder: (ctx) {
        _activeRejectionDialogContext = ctx;
        return QaRejectionDialog(targetType: targetType, title: title);
      },
    );
    _activeRejectionDialogContext = null;

    if (result != null) {
      final (effectiveNotes, effectiveInternalNotes) = result;
      if (targetType == 'question') {
        await _handleReviewQuestion(
          targetId,
          'reject',
          notes: effectiveNotes,
          internalNotes: effectiveInternalNotes,
        );
      } else {
        await _handleReviewAnswer(
          targetId,
          'reject',
          notes: effectiveNotes,
          internalNotes: effectiveInternalNotes,
        );
      }
    }
  }

  Future<void> _submitDraftQuestion() async {
    if (!_formKey.currentState!.validate()) return;
    final int sessionGen = _authSessionGeneration;
    final String? sessionUserId = widget.service.currentUserId;

    // Invariant 3: Adult age assurance gate
    if (!_isAdultConfirmed) {
      final isAdult = await AdultAgeConfirmationDialog.show(context);
      if (!isAdult) return;
      _isAdultConfirmed = true;
    }

    // Invariant 4: Spam rate limit check
    final rateLimitCheck = _spamLimiter.validateQuestionSubmission(
      userId: sessionUserId ?? 'anon',
      title: _titleController.text,
      body: _bodyController.text,
    );
    if (!rateLimitCheck.isAllowed) {
      setState(() {
        _statusMessage = rateLimitCheck.rejectionReason;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
    });

    try {
      final title = _titleController.text;
      final body = _bodyController.text;
      final newQuestion = await widget.service.createDraftQuestion(
        title: title,
        bodyMarkdown: body,
        conceptId: widget.conceptId,
        targetId: widget.targetId,
        lessonId: widget.lessonId,
        submitForReview: true,
      );

      if (!_isSessionValid(sessionGen, sessionUserId)) {
        return;
      }

      if (newQuestion != null) {
        _spamLimiter.recordQuestionSubmission(
          userId: sessionUserId ?? 'anon',
          title: title,
          body: body,
        );
        _titleController.clear();
        _bodyController.clear();
        setState(() {
          _myDrafts.insert(0, newQuestion);
          _statusMessage = 'Question saved as a private draft and queued for review.';
          _isSubmitting = false;
        });
        _tabController?.animateTo(2);
      } else {
        setState(() => _isSubmitting = false);
      }
    } catch (e) {
      if (!_isSessionValid(sessionGen, sessionUserId)) {
        return;
      }
      setState(() {
        _statusMessage = 'Unable to save question. Please try again.';
        _isSubmitting = false;
      });
    }
  }

  Future<void> _showAnswerRevisionDialog(CommunityAnswer rejectedAnswer) async {
    final String? dialogAuthorId = widget.service.currentUserId;
    final int sessionGen = _authSessionGeneration;
    final parentTitle = _questionTitles[rejectedAnswer.questionId] ?? 'Question';
    final feedback = _submissionFeedback[rejectedAnswer.id];

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        _activeRevisionDialogContext = dialogContext;
        return QaAnswerRevisionDialog(
          rejectedAnswer: rejectedAnswer,
          parentTitle: parentTitle,
          feedback: feedback,
          dialogAuthorId: dialogAuthorId,
          sessionGen: sessionGen,
          isSessionValid: _isSessionValid,
          onSubmitAnswer: (bodyMarkdown) async {
            final created = await widget.service.createDraftAnswer(
              questionId: rejectedAnswer.questionId,
              bodyMarkdown: bodyMarkdown,
              submitForReview: true,
            );
            if (created != null && widget.answerHistoryEnabled) {
              // Best effort: the resubmission is saved either way.
              await widget.service.linkAnswerResubmission(
                answerId: created.id,
                previousAnswerId: rejectedAnswer.id,
              );
            }
            return created;
          },
          onSuccess: (newAnswer) {
            setState(() {
              _myDraftAnswers.insert(0, newAnswer);
              _answerParentQuestionIds[newAnswer.id] = newAnswer.questionId;
              _statusMessage = 'Revised answer submitted for educator review.';
            });
            _tabController?.animateTo(2);
            unawaited(_refreshAnswerRevisions());
          },
        );
      },
    );
    _activeRevisionDialogContext = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.topicTitle ?? 'Concept Q&A & FAQs';

    if (_isLoading || _tabController == null) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final totalReviewCount = _reviewQuestions.length + _reviewAnswers.length;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.forum_outlined, color: Colors.blueAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Curated FAQs & In-Context Questions',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('open_bookmarks_button'),
                icon: const Icon(Icons.bookmark_outline),
                tooltip: 'Saved Explanations',
                onPressed: _openBookmarksSheet,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Close',
              ),
            ],
          ),
        ),

        // Private Engineering Phase Banner
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_outlined, size: 16, color: Colors.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Phase 1 Pilot: Open public community posting is disabled. Submissions remain private drafts.',
                  style: theme.textTheme.labelSmall?.copyWith(color: Colors.amber[800]),
                ),
              ),
            ],
          ),
        ),

        // Tabs
        TabBar(
          controller: _tabController,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blueAccent,
          tabs: [
            Tab(text: 'FAQs (${_seedFaqs.length})'),
            const Tab(text: 'Ask a Question'),
            Tab(text: 'My Drafts (${_myDrafts.length + _myDraftAnswers.length})'),
            if (_isModerator) Tab(text: 'Review Queue ($totalReviewCount)'),
          ],
        ),
        if (_statusMessage != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(child: Text(_statusMessage!, style: const TextStyle(fontSize: 12))),
                InkWell(
                  onTap: () => setState(() => _statusMessage = null),
                  child: const Icon(Icons.close, size: 16, color: Colors.blueGrey),
                ),
              ],
            ),
          ),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSeedFaqsTab(theme),
              _buildAskTab(theme),
              _buildMyDraftsTab(theme),
              if (_isModerator) _buildReviewQueueTab(theme),
            ],
          ),
        ),
      ],
    );
  }
}

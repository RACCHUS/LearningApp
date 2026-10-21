import 'package:flutter/material.dart';
import 'package:learning_pwa/models/community/community_question.dart';
import 'package:learning_pwa/models/community/community_answer.dart';
import 'package:learning_pwa/models/community/community_review_audit.dart';
import 'package:learning_pwa/services/community/community_qa_service.dart';
import 'package:learning_pwa/services/governance/moderation_service.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// Opens the in-context Concept Q&A sheet for learning screens (ECO-01 & ECO-02).
Future<void> showInContextQaSheet(
  BuildContext context, {
  String? conceptId,
  String? targetId,
  String? lessonId,
  String? topicTitle,
  CommunityQaService? service,
  ModerationService? moderationService,
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
          conceptId: conceptId,
          targetId: targetId,
          lessonId: lessonId,
          topicTitle: topicTitle,
          service: effectiveService,
          moderationService: effectiveModService,
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
            conceptId: conceptId,
            targetId: targetId,
            lessonId: lessonId,
            topicTitle: topicTitle,
            service: effectiveService,
            moderationService: effectiveModService,
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

  const InContextQaSheet({
    super.key,
    this.conceptId,
    this.targetId,
    this.lessonId,
    this.topicTitle,
    required this.service,
    this.moderationService,
  });

  @override
  State<InContextQaSheet> createState() => _InContextQaSheetState();
}

class _InContextQaSheetState extends State<InContextQaSheet> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isModerator = false;
  int _reviewSubTab = 0; // 0: Questions, 1: Answers, 2: Audit History
  String? _statusMessage;
  List<CommunityQuestion> _seedFaqs = [];
  List<CommunityQuestion> _myDrafts = [];
  List<CommunityQuestion> _reviewQuestions = [];
  List<CommunityAnswer> _reviewAnswers = [];
  List<CommunityReviewAudit> _auditLogs = [];
  final Map<String, List<CommunityAnswer>> _answersCache = {};
  final Set<String> _expandedQuestions = {};
  final Set<String> _userUpvoted = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final faqs = await widget.service.fetchSeedFaqs(
        conceptId: widget.conceptId,
        targetId: widget.targetId,
        lessonId: widget.lessonId,
      );
      final drafts = await widget.service.fetchMyDrafts();

      bool isMod = false;
      List<CommunityQuestion> reviewQuestions = [];
      List<CommunityAnswer> reviewAnswers = [];
      List<CommunityReviewAudit> auditLogs = [];
      try {
        final modService = widget.moderationService ?? ModerationService();
        isMod = await modService.isModerator();
        if (isMod) {
          reviewQuestions = await widget.service.fetchUnderReviewQuestions();
          reviewAnswers = await widget.service.fetchUnderReviewAnswers();
          auditLogs = await widget.service.fetchReviewAuditHistory(limit: 25);
        }
      } catch (_) {}

      if (mounted) {
        _tabController?.dispose();
        _tabController = TabController(length: isMod ? 4 : 3, vsync: this);
        setState(() {
          _seedFaqs = faqs;
          _myDrafts = drafts;
          _reviewQuestions = reviewQuestions;
          _reviewAnswers = reviewAnswers;
          _auditLogs = auditLogs;
          _isModerator = isMod;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        _tabController?.dispose();
        _tabController = TabController(length: 3, vsync: this);
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _reloadReviewData() async {
    try {
      final reviewQuestions = await widget.service.fetchUnderReviewQuestions();
      final reviewAnswers = await widget.service.fetchUnderReviewAnswers();
      final auditLogs = await widget.service.fetchReviewAuditHistory(limit: 25);
      final faqs = await widget.service.fetchSeedFaqs(
        conceptId: widget.conceptId,
        targetId: widget.targetId,
        lessonId: widget.lessonId,
      );
      if (mounted) {
        setState(() {
          _reviewQuestions = reviewQuestions;
          _reviewAnswers = reviewAnswers;
          _auditLogs = auditLogs;
          _seedFaqs = faqs;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAnswers(String questionId) async {
    if (_answersCache.containsKey(questionId)) return;
    try {
      final answers = await widget.service.fetchAnswersForQuestion(questionId);
      if (mounted) {
        setState(() {
          _answersCache[questionId] = answers;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleVote(CommunityQuestion question) async {
    if (question.authorId == 'offline-demo') return;
    try {
      final result = await widget.service.toggleVote(
        targetType: 'question',
        targetId: question.id,
      );
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
    try {
      await widget.service.acceptAnswer(answerId: answerId);
      final updatedAnswers = await widget.service.fetchAnswersForQuestion(questionId);
      if (mounted) {
        setState(() {
          _answersCache[questionId] = updatedAnswers;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleReviewQuestion(String questionId, String action, {String? notes}) async {
    try {
      await widget.service.reviewQuestion(
        questionId: questionId,
        action: action,
        notes: notes,
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

  Future<void> _handleReviewAnswer(String answerId, String action, {String? notes}) async {
    try {
      await widget.service.reviewAnswer(
        answerId: answerId,
        action: action,
        notes: notes,
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
          builder: (ctx) => AlertDialog(
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
          ),
        );
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
    final notesController = TextEditingController();
    final shouldReject = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject $targetType'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Provide feedback or an editorial rationale for rejecting "$title". This will be recorded in the moderation audit trail.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Editorial / Governance Notes',
                hintText: 'e.g., Needs revision: clarify distinction between blends and digraphs.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm Rejection', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldReject == true) {
      final notes = notesController.text.trim();
      final effectiveNotes = notes.isEmpty ? null : notes;
      if (targetType == 'question') {
        await _handleReviewQuestion(targetId, 'reject', notes: effectiveNotes);
      } else {
        await _handleReviewAnswer(targetId, 'reject', notes: effectiveNotes);
      }
    }
  }

  Future<void> _submitDraftQuestion() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
    });

    try {
      final newQuestion = await widget.service.createDraftQuestion(
        title: _titleController.text,
        bodyMarkdown: _bodyController.text,
        conceptId: widget.conceptId,
        targetId: widget.targetId,
        lessonId: widget.lessonId,
        submitForReview: true,
      );

      if (newQuestion != null && mounted) {
        _titleController.clear();
        _bodyController.clear();
        setState(() {
          _myDrafts.insert(0, newQuestion);
          _statusMessage = 'Question saved as a private draft and queued for review.';
          _isSubmitting = false;
        });
        _tabController?.animateTo(2);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Unable to save question. Please try again.';
          _isSubmitting = false;
        });
      }
    }
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
            Tab(text: 'My Drafts (${_myDrafts.length})'),
            if (_isModerator) Tab(text: 'Review Queue ($totalReviewCount)'),
          ],
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

  Widget _buildSeedFaqsTab(ThemeData theme) {
    if (_seedFaqs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lightbulb_outline, size: 40, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                'No FAQs Available For This Topic Yet',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Submit a private question in the "Ask a Question" tab to have educators review and expand our curated answers.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _seedFaqs.length,
      itemBuilder: (context, index) {
        final q = _seedFaqs[index];
        final isExpanded = _expandedQuestions.contains(q.id);
        final isUpvoted = _userUpvoted.contains(q.id);
        final isOfflineDemo = q.authorId == 'offline-demo';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              ListTile(
                title: Text(
                  q.title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isOfflineDemo
                              ? Colors.grey.withValues(alpha: 0.15)
                              : Colors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isOfflineDemo
                              ? 'Offline Demo Preview'
                              : (q.isSeeded ? 'Official FAQ' : 'Community FAQ'),
                          style: TextStyle(
                            color: isOfflineDemo ? Colors.grey[800] : Colors.blue[700],
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (!isOfflineDemo) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${q.upvoteCount} upvotes',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        isUpvoted ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                        size: 18,
                        color: isOfflineDemo ? Colors.grey[400] : (isUpvoted ? Colors.blueAccent : Colors.grey),
                      ),
                      onPressed: isOfflineDemo ? null : () => _handleVote(q),
                      tooltip: isOfflineDemo ? 'Voting disabled for offline preview' : 'Upvote',
                    ),
                    IconButton(
                      icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                      onPressed: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedQuestions.remove(q.id);
                          } else {
                            _expandedQuestions.add(q.id);
                            _loadAnswers(q.id);
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
              if (isExpanded) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        q.bodyMarkdown,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      if (_answersCache.containsKey(q.id)) ...[
                        for (final ans in _answersCache[q.id]!)
                          _buildAnswerCard(ans, q, isOfflineDemo, theme),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnswerCard(CommunityAnswer ans, CommunityQuestion q, bool isOfflineDemo, ThemeData theme) {
    final hasSourceAttribution = ans.bodyMarkdown.contains('Source:');
    String mainText = ans.bodyMarkdown;
    String? sourceText;

    if (hasSourceAttribution) {
      final sourceIdx = ans.bodyMarkdown.indexOf('Source:');
      mainText = ans.bodyMarkdown.substring(0, sourceIdx).trim();
      sourceText = ans.bodyMarkdown.substring(sourceIdx).trim();
    }

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (ans.isAccepted && !isOfflineDemo ? Colors.green : Colors.blueGrey).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (ans.isAccepted && !isOfflineDemo ? Colors.green : Colors.blueGrey).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: ans.isAccepted && !isOfflineDemo
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.grey.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          ans.isAccepted && !isOfflineDemo ? Icons.check_circle : Icons.chat_bubble_outline,
                          size: 12,
                          color: ans.isAccepted && !isOfflineDemo ? Colors.green[800] : Colors.grey[800],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          ans.isAccepted && !isOfflineDemo
                              ? 'Accepted Answer:'
                              : (isOfflineDemo ? 'Offline Example Answer:' : 'Community Answer:'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: ans.isAccepted && !isOfflineDemo ? Colors.green[800] : Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (ans.isSeeded || q.isSeeded)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, size: 12, color: Colors.blue),
                          SizedBox(width: 4),
                          Text(
                            'Platform Curated',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue),
                          ),
                        ],
                      ),
                    ),
                  if (ans.isAiGenerated)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome, size: 12, color: Colors.purple),
                          const SizedBox(width: 4),
                          Text(
                            ans.aiModelName != null ? 'AI: ${ans.aiModelName}' : 'AI Assisted',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.purple),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (!ans.isAccepted && _isModerator && !isOfflineDemo)
                TextButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                  label: const Text('Accept', style: TextStyle(fontSize: 11, color: Colors.green)),
                  onPressed: () => _handleAcceptAnswer(ans.id, q.id),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(mainText, style: const TextStyle(fontSize: 13, height: 1.4)),
          if (sourceText != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border(left: BorderSide(color: Colors.blueGrey[400]!, width: 3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.menu_book_outlined, size: 14, color: Colors.blueGrey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      sourceText,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.blueGrey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAskTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_statusMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_statusMessage!, style: const TextStyle(fontSize: 12))),
                  ],
                ),
              ),
            Text(
              'Ask a Question about this Topic',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Your question will be saved privately and reviewed by educators. It will not be posted publicly during Phase 1.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Question Title',
                hintText: 'e.g., How does blending consonant sounds work?',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().length < 5) {
                  return 'Title must be at least 5 characters';
                }
                if (v.trim().length > 200) {
                  return 'Title must not exceed 200 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bodyController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Details / Context',
                hintText: 'Describe what you find confusing or what you are trying to understand...',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().length < 10) {
                  return 'Details must be at least 10 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitDraftQuestion,
                icon: _isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: const Text('Save Private Question'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyDraftsTab(ThemeData theme) {
    if (_myDrafts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'You have not authored any private questions yet.',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _myDrafts.length,
      itemBuilder: (context, index) {
        final d = _myDrafts[index];
        final isUnderReview = d.status == 'under_review';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: ListTile(
            title: Text(d.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: Text(
              d.bodyMarkdown,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isUnderReview ? Colors.orange.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isUnderReview ? 'Under Review' : 'Draft',
                style: TextStyle(
                  color: isUnderReview ? Colors.orange[800] : Colors.grey[700],
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReviewQueueTab(ThemeData theme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: SegmentedButton<int>(
            segments: [
              ButtonSegment<int>(
                value: 0,
                label: Text('Questions (${_reviewQuestions.length})', style: const TextStyle(fontSize: 12)),
                icon: const Icon(Icons.help_outline, size: 14),
              ),
              ButtonSegment<int>(
                value: 1,
                label: Text('Answers (${_reviewAnswers.length})', style: const TextStyle(fontSize: 12)),
                icon: const Icon(Icons.question_answer_outlined, size: 14),
              ),
              ButtonSegment<int>(
                value: 2,
                label: Text('Audit Log (${_auditLogs.length})', style: const TextStyle(fontSize: 12)),
                icon: const Icon(Icons.history, size: 14),
              ),
            ],
            selected: {_reviewSubTab},
            onSelectionChanged: (set) {
              setState(() => _reviewSubTab = set.first);
            },
          ),
        ),
        Expanded(
          child: switch (_reviewSubTab) {
            0 => _buildReviewQuestionsList(theme),
            1 => _buildReviewAnswersList(theme),
            _ => _buildAuditLogList(theme),
          },
        ),
      ],
    );
  }

  Widget _buildReviewQuestionsList(ThemeData theme) {
    if (_reviewQuestions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, size: 36, color: Colors.green),
              const SizedBox(height: 8),
              Text(
                'No Questions Awaiting Review',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'All learner submitted questions have been reviewed.',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _reviewQuestions.length,
      itemBuilder: (context, index) {
        final q = _reviewQuestions[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Under Review',
                        style: TextStyle(
                          color: Colors.orange[800],
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (q.conceptId != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        q.conceptId!,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  q.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  q.bodyMarkdown,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.close, size: 14, color: Colors.red),
                      label: const Text('Reject', style: TextStyle(color: Colors.red, fontSize: 12)),
                      onPressed: () => _showRejectionDialog(
                        targetType: 'question',
                        targetId: q.id,
                        title: q.title,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 14),
                      label: const Text('Publish', style: TextStyle(fontSize: 12)),
                      onPressed: () => _handleReviewQuestion(q.id, 'publish'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReviewAnswersList(ThemeData theme) {
    if (_reviewAnswers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, size: 36, color: Colors.green),
              const SizedBox(height: 8),
              Text(
                'No Answers Awaiting Review',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'All submitted answers have been reviewed.',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _reviewAnswers.length,
      itemBuilder: (context, index) {
        final a = _reviewAnswers[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Under Review',
                        style: TextStyle(
                          color: Colors.orange[800],
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (a.isAiGenerated) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          a.aiModelName != null ? 'AI: ${a.aiModelName}' : 'AI Assisted',
                          style: const TextStyle(color: Colors.purple, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Parent Question ID: ${a.questionId}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.blueGrey),
                ),
                const SizedBox(height: 4),
                Text(
                  a.bodyMarkdown,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.close, size: 14, color: Colors.red),
                      label: const Text('Reject', style: TextStyle(color: Colors.red, fontSize: 12)),
                      onPressed: () => _showRejectionDialog(
                        targetType: 'answer',
                        targetId: a.id,
                        title: 'Answer',
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 14),
                      label: const Text('Publish', style: TextStyle(fontSize: 12)),
                      onPressed: () => _handleReviewAnswer(a.id, 'publish'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAuditLogList(ThemeData theme) {
    if (_auditLogs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.history_toggle_off, size: 36, color: Colors.grey),
              const SizedBox(height: 8),
              Text(
                'No Audit Records Yet',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Moderation decisions and review actions will appear here.',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _auditLogs.length,
      itemBuilder: (context, index) {
        final audit = _auditLogs[index];
        final actionColor = switch (audit.action) {
          'publish' => Colors.green,
          'reject' => Colors.red,
          'flag' => Colors.orange,
          _ => Colors.blueGrey,
        };

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: actionColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            audit.action.toUpperCase(),
                            style: TextStyle(
                              color: actionColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          audit.targetType == 'question' ? 'Question' : 'Answer',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    Text(
                      '${audit.createdAt.month}/${audit.createdAt.day} ${audit.createdAt.hour}:${audit.createdAt.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Status change: ${audit.previousStatus} -> ${audit.newStatus}',
                  style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                ),
                if (audit.notes != null && audit.notes!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.comment_outlined, size: 12, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            audit.notes!,
                            style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

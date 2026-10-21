import 'package:flutter/material.dart';
import 'package:learning_pwa/models/community/community_question.dart';
import 'package:learning_pwa/models/community/community_answer.dart';
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
  String? _statusMessage;
  List<CommunityQuestion> _seedFaqs = [];
  List<CommunityQuestion> _myDrafts = [];
  List<CommunityQuestion> _reviewQueue = [];
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
      List<CommunityQuestion> reviewItems = [];
      try {
        final modService = widget.moderationService ?? ModerationService();
        isMod = await modService.isModerator();
        if (isMod) {
          reviewItems = await widget.service.fetchUnderReviewQuestions();
        }
      } catch (_) {}

      if (mounted) {
        _tabController?.dispose();
        _tabController = TabController(length: isMod ? 4 : 3, vsync: this);
        setState(() {
          _seedFaqs = faqs;
          _myDrafts = drafts;
          _reviewQueue = reviewItems;
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

  Future<void> _handleReviewQuestion(String questionId, String action) async {
    try {
      await widget.service.reviewQuestion(questionId: questionId, action: action);
      final updatedQueue = await widget.service.fetchUnderReviewQuestions();
      final faqs = await widget.service.fetchSeedFaqs(
        conceptId: widget.conceptId,
        targetId: widget.targetId,
        lessonId: widget.lessonId,
      );
      if (mounted) {
        setState(() {
          _reviewQueue = updatedQueue;
          _seedFaqs = faqs;
        });
      }
    } catch (_) {}
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
            if (_isModerator) Tab(text: 'Review Queue (${_reviewQueue.length})'),
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
          child: Text(
            'No FAQs available for this specific topic yet.',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
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
                      const SizedBox(height: 10),
                      if (_answersCache.containsKey(q.id)) ...[
                        for (final ans in _answersCache[q.id]!) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                ans.isAccepted && !isOfflineDemo
                                    ? 'Accepted Answer:'
                                    : (isOfflineDemo ? 'Offline Example Answer:' : 'Community Answer:'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: ans.isAccepted && !isOfflineDemo
                                      ? Colors.green
                                      : Colors.blueGrey,
                                ),
                              ),
                              if (!ans.isAccepted && _isModerator && !isOfflineDemo)
                                TextButton.icon(
                                  icon: const Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                                  label: const Text('Accept', style: TextStyle(fontSize: 11, color: Colors.green)),
                                  onPressed: () => _handleAcceptAnswer(ans.id, q.id),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            margin: const EdgeInsets.only(top: 4, bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (ans.isAccepted && !isOfflineDemo
                                      ? Colors.green
                                      : Colors.blueGrey)
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(ans.bodyMarkdown, style: const TextStyle(fontSize: 13)),
                          ),
                        ],
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
    if (_reviewQueue.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, size: 36, color: Colors.green),
              const SizedBox(height: 8),
              Text(
                'Moderator Review Queue is Empty',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'No learner questions currently awaiting review.',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _reviewQueue.length,
      itemBuilder: (context, index) {
        final q = _reviewQueue[index];

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
                      onPressed: () => _handleReviewQuestion(q.id, 'reject'),
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
}

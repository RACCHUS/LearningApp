import 'package:flutter/material.dart';
import 'package:learning_pwa/models/community/community_question.dart';
import 'package:learning_pwa/models/community/community_answer.dart';
import 'package:learning_pwa/services/community/community_qa_service.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// Opens the in-context Concept Q&A sheet for learning screens (ECO-01).
Future<void> showInContextQaSheet(
  BuildContext context, {
  String? conceptId,
  String? targetId,
  String? lessonId,
  String? topicTitle,
  CommunityQaService? service,
}) {
  final width = MediaQuery.sizeOf(context).width;
  final effectiveService = service ?? CommunityQaService();

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
        ),
      ),
    );
  }

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.82,
        ),
        child: SizedBox(
          width: 620,
          child: InContextQaSheet(
            conceptId: conceptId,
            targetId: targetId,
            lessonId: lessonId,
            topicTitle: topicTitle,
            service: effectiveService,
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

  const InContextQaSheet({
    super.key,
    this.conceptId,
    this.targetId,
    this.lessonId,
    this.topicTitle,
    required this.service,
  });

  @override
  State<InContextQaSheet> createState() => _InContextQaSheetState();
}

class _InContextQaSheetState extends State<InContextQaSheet> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _statusMessage;
  List<CommunityQuestion> _seedFaqs = [];
  List<CommunityQuestion> _myDrafts = [];
  final Map<String, List<CommunityAnswer>> _answersCache = {};
  final Set<String> _expandedQuestions = {};
  final Set<String> _userUpvoted = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
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

      if (mounted) {
        setState(() {
          _seedFaqs = faqs;
          _myDrafts = drafts;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
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
        _tabController.animateTo(2); // Switch to My Questions tab
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
            Tab(text: 'Seed FAQs (${_seedFaqs.length})'),
            const Tab(text: 'Ask a Question'),
            Tab(text: 'My Drafts (${_myDrafts.length})'),
          ],
        ),

        // Tab Views
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSeedFaqsTab(theme),
                    _buildAskTab(theme),
                    _buildMyDraftsTab(theme),
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
            'No seed FAQs available for this specific topic yet.',
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
                          color: Colors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Official FAQ',
                          style: TextStyle(color: Colors.blue[700], fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${q.upvoteCount} upvotes',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
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
                        color: isUpvoted ? Colors.blueAccent : Colors.grey,
                      ),
                      onPressed: () => _handleVote(q),
                      tooltip: 'Upvote',
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
                        const Text(
                          'Verified Answer:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green),
                        ),
                        const SizedBox(height: 4),
                        for (final ans in _answersCache[q.id]!)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(ans.bodyMarkdown, style: const TextStyle(fontSize: 13)),
                          ),
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
}

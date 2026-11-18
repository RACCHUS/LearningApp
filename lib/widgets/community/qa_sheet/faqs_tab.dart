part of '../in_context_qa_sheet.dart';

// Seed FAQ tab and the answer card it shows.
// Moved unchanged from in_context_qa_sheet.dart (code-efficiency plan
// §14, Phase 2); setState calls go through the sheet's _update helper
// because extensions may not call the protected setState directly.
extension _QaFaqsTab on InContextQaSheetState {
  Widget _buildSeedFaqsTab(ThemeData theme) {
    if (_seedFaqs.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildTeachThisTopicBanner(theme),
          Center(
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
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _seedFaqs.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildTeachThisTopicBanner(theme);
        }
        final q = _seedFaqs[index - 1];
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
                    if (widget.moderationService != null && !isOfflineDemo)
                      IconButton(
                        key: Key('report_question_${q.id}'),
                        icon: const Icon(Icons.flag_outlined, size: 18),
                        onPressed: () => _handleReportQuestion(q),
                        tooltip: 'Report question',
                      ),
                    IconButton(
                      icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                      onPressed: () {
                        _update(() {
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
                      const SizedBox(height: 8),
                      Center(
                        child: OutlinedButton.icon(
                          key: Key('teach_topic_button_${q.id}'),
                          icon: const Icon(Icons.school_outlined, size: 16),
                          label: const Text('Teach This Topic: Contribute Answer', style: TextStyle(fontSize: 12)),
                          onPressed: isOfflineDemo ? null : () => _openTeachThisTopicDialog(q),
                        ),
                      ),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
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
                  if (ans.isSeeded && !isOfflineDemo)
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
                  if (_authorReputationsCache.containsKey(ans.authorId))
                    EducatorReputationBadge(
                      tier: _authorReputationsCache[ans.authorId]!.tier,
                      score: _authorReputationsCache[ans.authorId]!.score,
                      isCompact: true,
                    ),
                  if (_authorVerificationsCache.containsKey(ans.authorId) &&
                      _authorVerificationsCache[ans.authorId]!.isNotEmpty) ...[
                    for (final v in _authorVerificationsCache[ans.authorId]!)
                      EducatorCredentialBadge(verification: v, isCompact: true),
                  ],
                  if (widget.educatorProfilesEnabled &&
                      ans.authorId.isNotEmpty &&
                      ans.authorId != 'offline-demo' &&
                      ans.authorId != 'system')
                    TextButton(
                      key: Key('author_profile_${ans.id}'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      onPressed: () => context.push('/educators/${ans.authorId}'),
                      child: const Text('Contributor profile', style: TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: Key('bookmark_answer_${ans.id}'),
                    icon: Icon(
                      _bookmarkService.isBookmarked(ans.id) ? Icons.bookmark : Icons.bookmark_border,
                      size: 16,
                      color: _bookmarkService.isBookmarked(ans.id) ? Colors.amber[800] : null,
                    ),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    tooltip: _bookmarkService.isBookmarked(ans.id) ? 'Remove bookmark' : 'Bookmark answer',
                    onPressed: () => _toggleBookmark(ans, q),
                  ),
                  if (!ans.isAccepted && _isModerator && !isOfflineDemo)
                    TextButton.icon(
                      icon: const Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                      label: const Text('Accept', style: TextStyle(fontSize: 11, color: Colors.green)),
                      onPressed: () => _handleAcceptAnswer(ans.id, q.id),
                    ),
                  if (widget.moderationService != null && !isOfflineDemo)
                    IconButton(
                      key: Key('report_answer_${ans.id}'),
                      icon: const Icon(Icons.flag_outlined, size: 16),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      onPressed: () => _handleReportAnswer(ans),
                      tooltip: 'Report answer',
                    ),
                ],
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
}

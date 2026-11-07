import 'package:flutter/material.dart';
import 'package:learning_pwa/models/community/community_bookmark.dart';
import 'package:learning_pwa/services/community/community_bookmark_service.dart';

/// Modal bottom sheet or dialog to browse and manage saved educational bookmarks (ECO-04).
class BookmarkedExplanationsSheet extends StatefulWidget {
  final CommunityBookmarkService bookmarkService;
  final String? filterConceptId;
  final ValueChanged<CommunityBookmark>? onSelectBookmark;

  const BookmarkedExplanationsSheet({
    super.key,
    required this.bookmarkService,
    this.filterConceptId,
    this.onSelectBookmark,
  });

  static Future<void> show(
    BuildContext context, {
    required CommunityBookmarkService bookmarkService,
    String? filterConceptId,
    ValueChanged<CommunityBookmark>? onSelectBookmark,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * 0.75,
        child: BookmarkedExplanationsSheet(
          bookmarkService: bookmarkService,
          filterConceptId: filterConceptId,
          onSelectBookmark: onSelectBookmark,
        ),
      ),
    );
  }

  @override
  State<BookmarkedExplanationsSheet> createState() => _BookmarkedExplanationsSheetState();
}

class _BookmarkedExplanationsSheetState extends State<BookmarkedExplanationsSheet> {
  String? _selectedContentType; // null = all, 'answer', 'question', 'explanation'

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<List<CommunityBookmark>>(
      valueListenable: widget.bookmarkService.bookmarksListenable,
      builder: (context, allBookmarks, _) {
        final filtered = allBookmarks.where((b) {
          if (_selectedContentType != null && b.contentType != _selectedContentType) {
            return false;
          }
          if (widget.filterConceptId != null && b.conceptId != widget.filterConceptId) {
            return false;
          }
          return true;
        }).toList();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.bookmark, color: Colors.amber, size: 22),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Saved Explanations & Answers',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (allBookmarks.isNotEmpty)
                    TextButton(
                      onPressed: () => _confirmClearAll(context),
                      child: const Text('Clear All', style: TextStyle(fontSize: 12, color: Colors.red)),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All', style: TextStyle(fontSize: 12)),
                      selected: _selectedContentType == null,
                      onSelected: (_) => setState(() => _selectedContentType = null),
                    ),
                    const SizedBox(width: 6),
                    FilterChip(
                      label: const Text('Answers', style: TextStyle(fontSize: 12)),
                      selected: _selectedContentType == 'answer',
                      onSelected: (_) => setState(() => _selectedContentType = 'answer'),
                    ),
                    const SizedBox(width: 6),
                    FilterChip(
                      label: const Text('Questions', style: TextStyle(fontSize: 12)),
                      selected: _selectedContentType == 'question',
                      onSelected: (_) => setState(() => _selectedContentType = 'question'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 16),

              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bookmark_border, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            const Text(
                              'No saved items yet',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tap the bookmark icon on any answer to save it for study review.',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: item.contentType == 'answer'
                                  ? Colors.green.withValues(alpha: 0.15)
                                  : Colors.blue.withValues(alpha: 0.15),
                              child: Icon(
                                item.contentType == 'answer' ? Icons.check : Icons.help_outline,
                                size: 16,
                                color: item.contentType == 'answer' ? Colors.green[800] : Colors.blue[800],
                              ),
                            ),
                            title: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                  item.bodySnippet,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (item.authorDisplayName != null) ...[
                                      Text(
                                        item.authorDisplayName!,
                                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                      ),
                                      if (item.isVerifiedAuthor) ...[
                                        const SizedBox(width: 4),
                                        const Icon(Icons.verified, size: 11, color: Colors.teal),
                                      ],
                                      const SizedBox(width: 8),
                                    ],
                                    Text(
                                      'Saved ${item.createdAt.toLocal().toString().split(' ')[0]}',
                                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.bookmark_remove_outlined, size: 18),
                              tooltip: 'Remove bookmark',
                              onPressed: () => widget.bookmarkService.removeBookmark(item.contentId),
                            ),
                            onTap: () {
                              widget.onSelectBookmark?.call(item);
                              Navigator.of(context).pop();
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmClearAll(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Bookmarks?'),
        content: const Text('Are you sure you want to remove all saved answers and explanations?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              widget.bookmarkService.clearBookmarks();
              Navigator.of(ctx).pop();
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/providers/lesson_progress_provider.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// Enhanced lesson card with hover effects, category accent, and overflow menu.
class LessonCard extends ConsumerStatefulWidget {
  final Lesson lesson;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const LessonCard({
    super.key,
    required this.lesson,
    this.onDelete,
    this.onTap,
  });

  @override
  ConsumerState<LessonCard> createState() => _LessonCardState();
}

class _LessonCardState extends ConsumerState<LessonCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final lesson = widget.lesson;

    // Get lesson progress
    final progressAsync = ref.watch(lessonProgressProvider(lesson.id));
    final progress = progressAsync.when(
      data: (p) => p,
      loading: () => 0.0,
      error: (_, __) => 0.0,
    );

    // Granular mastery (null until the lesson has review items)
    final mastery = ref.watch(lessonMasteryProvider(lesson.id)).valueOrNull;

    // Get accent color based on primary tag
    final accentColor = lesson.tags.isNotEmpty
        ? DesignTokens.getTagColor(lesson.tags.first)
        : colorScheme.primary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: DesignTokens.durationNormal,
        curve: DesignTokens.curveDefault,
        margin: const EdgeInsets.symmetric(
          vertical: DesignTokens.space2,
          horizontal: DesignTokens.space4,
        ),
        transform: Matrix4.identity()..scale(_isHovered ? 1.01 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          border: Border.all(
            color: _isHovered
                ? accentColor.withValues(alpha: 0.4)
                : colorScheme.outline,
            width: _isHovered ? 1.5 : 1,
          ),
          boxShadow: _isHovered
              ? DesignTokens.glowEffect(accentColor)
              : DesignTokens.shadowNone,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
            onTap: widget.onTap ?? () => context.push('/lesson/${lesson.id}'),
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left accent stripe with progress overlay
                    Stack(
                      children: [
                        Container(
                          width: 4,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(DesignTokens.radiusLg),
                              bottomLeft:
                                  Radius.circular(DesignTokens.radiusLg),
                            ),
                          ),
                        ),
                        // Progress fill on accent stripe
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: FractionallySizedBox(
                            heightFactor: progress,
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              decoration: BoxDecoration(
                                color: accentColor,
                                borderRadius: BorderRadius.only(
                                  topLeft: progress >= 1.0
                                      ? const Radius.circular(
                                          DesignTokens.radiusLg)
                                      : Radius.zero,
                                  bottomLeft: const Radius.circular(
                                      DesignTokens.radiusLg),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Main content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(DesignTokens.space4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title and menu row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Emoji prefix (picture-superiority effect):
                                // gives the lesson a quick visual anchor
                                // before users parse the title text.
                                if (lesson.emoji != null &&
                                    lesson.emoji!.isNotEmpty) ...[
                                  Text(
                                    lesson.emoji!,
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                  const SizedBox(width: DesignTokens.space2),
                                ],
                                Expanded(
                                  child: Text(
                                    lesson.title,
                                    style: textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: DesignTokens.space2),
                                _buildOverflowMenu(context, colorScheme),
                              ],
                            ),

                            // Description - use Expanded to fill available space
                            if (lesson.description != null &&
                                lesson.description!.isNotEmpty) ...[
                              const SizedBox(height: DesignTokens.space2),
                              Expanded(
                                child: Text(
                                  lesson.description!,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.7),
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ] else
                              const Spacer(),

                            // Bottom row: date and tags
                            Row(
                              children: [
                                // Date
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                                const SizedBox(width: DesignTokens.space1),
                                Text(
                                  _formatDate(lesson.createdAt),
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),

                                // Mastery label (spaced-repetition derived)
                                if (mastery != null) ...[
                                  const SizedBox(width: DesignTokens.space3),
                                  Icon(Icons.trending_up,
                                      size: 14, color: accentColor),
                                  const SizedBox(width: DesignTokens.space1),
                                  Text(
                                    '${(mastery * 100).round()}% mastered',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: accentColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],

                                // Tags
                                if (lesson.tags.isNotEmpty) ...[
                                  const SizedBox(width: DesignTokens.space3),
                                  Expanded(
                                    child: _buildTagsList(
                                        context, lesson.tags, colorScheme),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Right chevron indicator
                    AnimatedOpacity(
                      opacity: _isHovered ? 1.0 : 0.5,
                      duration: DesignTokens.durationFast,
                      child: Container(
                        width: 40,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.chevron_right,
                          color: _isHovered
                              ? accentColor
                              : colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverflowMenu(BuildContext context, ColorScheme colorScheme) {
    return SizedBox(
      width: 32,
      height: 32,
      child: PopupMenuButton<String>(
        icon: Icon(
          Icons.more_vert,
          size: 20,
          color: colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        padding: EdgeInsets.zero,
        splashRadius: 16,
        tooltip: 'More options',
        onSelected: (value) {
          if (value == 'delete' && widget.onDelete != null) {
            _showDeleteConfirmation(context);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: colorScheme.error,
                ),
                const SizedBox(width: DesignTokens.space2),
                Text(
                  'Delete',
                  style: TextStyle(color: colorScheme.error),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsList(
      BuildContext context, List<String> tags, ColorScheme colorScheme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tags.take(3).map((tag) {
          final tagColor = DesignTokens.getTagColor(tag);
          final chipBackground =
              Color.alphaBlend(tagColor.withValues(alpha: 0.22), colorScheme.surfaceContainerLow);
          final chipTextColor =
              DesignTokens.readableOn(chipBackground).withValues(alpha: 0.92);
          return Padding(
            padding: const EdgeInsets.only(right: DesignTokens.space1),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.space2,
                vertical: DesignTokens.space1,
              ),
              decoration: BoxDecoration(
                color: chipBackground,
                borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
                border: Border.all(
                  color: tagColor.withValues(alpha: 0.45),
                  width: 1,
                ),
              ),
              child: Text(
                tag,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: chipTextColor,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Lesson'),
        content: Text(
          'Are you sure you want to delete "${widget.lesson.title}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              widget.onDelete?.call();
            },
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return 'Just now';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks${weeks == 1 ? ' week' : ' weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months${months == 1 ? ' month' : ' months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years${years == 1 ? ' year' : ' years'} ago';
    }
  }
}

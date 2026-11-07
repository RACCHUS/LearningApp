import 'package:flutter/material.dart';
import '../../models/community/community_resource.dart';

/// Card displaying a community-authored resource with author attribution,
/// citation badges, and study action (ECO-06, Phase 3).
class ResourceCard extends StatelessWidget {
  final CommunityResource resource;
  final VoidCallback? onTap;

  const ResourceCard({
    super.key,
    required this.resource,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      key: Key('resource_card_${resource.id}'),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Content type badge & status
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getContentIcon(resource.contentType),
                          size: 14,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          resource.contentType.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (resource.isAiAssisted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer
                            .withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'AI Assisted',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                  const Spacer(),
                  _buildStatusChip(context, resource.status),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                resource.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (resource.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  resource.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Author attribution & citations
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor:
                            theme.colorScheme.primary.withOpacity(0.15),
                        child: Text(
                          resource.authorName.isNotEmpty
                              ? resource.authorName[0].toUpperCase()
                              : 'E',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        resource.authorName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (resource.citations.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.gavel,
                              size: 11, color: theme.colorScheme.secondary),
                          const SizedBox(width: 4),
                          Text(
                            resource.citations.first.authorityCode,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Footer: counts & ratings
              Row(
                children: [
                  if (resource.contentType ==
                      CommunityResourceContentType.flashcardSet)
                    Text(
                      '${resource.flashcards.length} cards',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    )
                  else if (resource.contentType ==
                      CommunityResourceContentType.studyGuide)
                    Text(
                      '${resource.guideSections.length} sections',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    )
                  else
                    Text(
                      resource.topic,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  const Spacer(),
                  if (resource.feedbackCount > 0) ...[
                    const Icon(Icons.star, size: 14, color: Colors.amber),
                    const SizedBox(width: 3),
                    Text(
                      resource.averageRating.toStringAsFixed(1),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      ' (${resource.feedbackCount})',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getContentIcon(CommunityResourceContentType type) {
    switch (type) {
      case CommunityResourceContentType.lesson:
        return Icons.menu_book;
      case CommunityResourceContentType.flashcardSet:
        return Icons.style;
      case CommunityResourceContentType.studyGuide:
        return Icons.auto_stories;
      case CommunityResourceContentType.cheatSheet:
        return Icons.article;
    }
  }

  Widget _buildStatusChip(BuildContext context, CommunityResourceStatus status) {
    final theme = Theme.of(context);
    Color color;
    switch (status) {
      case CommunityResourceStatus.published:
        color = Colors.green;
        break;
      case CommunityResourceStatus.submittedForReview:
      case CommunityResourceStatus.underReview:
        color = Colors.orange;
        break;
      case CommunityResourceStatus.approved:
        color = Colors.blue;
        break;
      case CommunityResourceStatus.draft:
      case CommunityResourceStatus.archived:
        color = theme.colorScheme.outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}


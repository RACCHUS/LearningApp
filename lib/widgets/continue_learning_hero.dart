import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/providers/lesson_progress_provider.dart';
import 'package:learning_pwa/theme/design_tokens.dart';
import 'package:learning_pwa/utils/haptic_utils.dart';

/// A hero section that shows the user's most recently studied incomplete lesson
/// Provides quick access to continue where they left off
class ContinueLearningHero extends ConsumerWidget {
  const ContinueLearningHero({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionAsync = ref.watch(continueLearningSuggestionProvider);
    
    return suggestionAsync.when(
      data: (suggestion) {
        if (suggestion == null) return const SizedBox.shrink();
        return _buildHeroCard(context, suggestion);
      },
      loading: () => const SizedBox.shrink(), // Don't show loading state
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildHeroCard(BuildContext context, ContinueLearningSuggestion suggestion) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.space4,
        vertical: DesignTokens.space2,
      ),
      child: Material(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          onTap: () {
            HapticUtils.light();
            context.push('/study/${suggestion.lessonId}');
          },
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.space4),
            child: Row(
              children: [
                // Left icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                  ),
                  child: Icon(
                    Icons.play_circle_outline_rounded,
                    color: colorScheme.primary,
                    size: 28,
                  ),
                ),
                
                const SizedBox(width: DesignTokens.space3),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Continue Learning',
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        suggestion.lessonTitle,
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.history,
                            size: 14,
                            color: colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            suggestion.timeAgo,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
                            ),
                          ),
                          if (suggestion.questionsAnswered > 0) ...[
                            const SizedBox(width: DesignTokens.space2),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: DesignTokens.space2),
                            Text(
                              '${suggestion.questionsAnswered} questions done',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Right arrow
                Icon(
                  Icons.arrow_forward_rounded,
                  color: colorScheme.primary,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

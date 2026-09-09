import 'package:flutter/material.dart';

/// Content type selector with tabs for different content types
/// 
/// Extracted from LessonBuilderWidget to improve maintainability.
/// Handles the tab selection for Terms, Questions, and Concepts.
class ContentTypeSelector extends StatelessWidget {
  final TabController tabController;
  final int contentItemsCount;

  const ContentTypeSelector({
    super.key,
    required this.tabController,
    required this.contentItemsCount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Header with content count
            Row(
              children: [
                Text(
                  'Lesson Content',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$contentItemsCount items',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Content type tabs
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.primary,
                ),
                labelColor: Theme.of(context).colorScheme.onPrimary,
                unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.book),
                    text: 'Terms',
                    height: 60,
                  ),
                  Tab(
                    icon: Icon(Icons.quiz),
                    text: 'Questions',
                    height: 60,
                  ),
                  Tab(
                    icon: Icon(Icons.lightbulb),
                    text: 'Concepts',
                    height: 60,
                  ),
                ],
              ),
            ),
            
            if (contentItemsCount == 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Select a content type above and start adding items to your lesson',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
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
  }
}

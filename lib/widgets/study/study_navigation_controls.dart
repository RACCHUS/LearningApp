import 'package:flutter/material.dart';
import 'package:learning_pwa/theme/app_theme.dart';

/// Study navigation controls widget
/// 
/// Provides previous/next navigation for study sessions
/// with appropriate button states and styling.
class StudyNavigationControls extends StatelessWidget {
  final int currentIndex;
  final int totalItems;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onFinish;

  const StudyNavigationControls({
    super.key,
    required this.currentIndex,
    required this.totalItems,
    this.onPrevious,
    this.onNext,
    this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final isFirst = currentIndex <= 0;
    final isLast = currentIndex >= totalItems - 1;
    
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous button
          FilledButton.tonal(
            onPressed: isFirst ? null : onPrevious,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back, size: 18),
                SizedBox(width: 8),
                Text('Previous'),
              ],
            ),
          ),
          
          // Progress indicator
          _ProgressIndicator(
            current: currentIndex + 1,
            total: totalItems,
          ),
          
          // Next/Finish button
          isLast
            ? FilledButton(
                onPressed: onFinish,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Finish'),
                    SizedBox(width: 8),
                    Icon(Icons.check, size: 18),
                  ],
                ),
              )
            : FilledButton(
                onPressed: onNext,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Next'),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// Progress indicator showing current position in study session
class _ProgressIndicator extends StatelessWidget {
  final int current;
  final int total;

  const _ProgressIndicator({
    required this.current,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$current of $total',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

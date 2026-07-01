import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/spaced_repetition.dart';
import 'package:learning_pwa/services/spaced_repetition_service.dart';
import 'package:learning_pwa/utils/haptic_utils.dart';

/// Main review screen for spaced repetition
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _showAnswer = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    // Start review session when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reviewSessionProvider.notifier).startSession();
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _toggleAnswer() {
    setState(() {
      _showAnswer = !_showAnswer;
    });
    if (_showAnswer) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    HapticUtils.light();
  }

  void _handleQualitySelected(RecallQuality quality) {
    ref.read(reviewSessionProvider.notifier).processCurrentReview(quality);
    
    // Reset card state for next item
    setState(() {
      _showAnswer = false;
    });
    _flipController.reset();

    if (quality.value >= 4) {
      HapticUtils.success();
    } else if (quality.value >= 3) {
      HapticUtils.light();
    } else {
      HapticUtils.error();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(reviewSessionProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Review'),
        actions: [
          if (!session.isComplete && session.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${session.currentIndex + 1}/${session.items.length}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(context, session, theme),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ReviewSessionState session,
    ThemeData theme,
  ) {
    if (session.isLoading && session.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (session.items.isEmpty) {
      return _buildEmptyState(context, theme);
    }

    if (session.isComplete) {
      return _buildCompletionState(context, session, theme);
    }

    return _buildReviewCard(context, session, theme);
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.celebration_outlined,
              size: 80,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'All Caught Up!',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You have no items due for review right now.\nKeep studying to build your review queue!',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Learning'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionState(
    BuildContext context,
    ReviewSessionState session,
    ThemeData theme,
  ) {
    final accuracy = (session.sessionAccuracy * 100).toInt();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primaryContainer,
              ),
              child: Icon(
                Icons.emoji_events,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Session Complete!',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You reviewed ${session.reviewedCount} items',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            // Accuracy display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    accuracy >= 80
                        ? Icons.star
                        : accuracy >= 50
                            ? Icons.star_half
                            : Icons.star_border,
                    color: accuracy >= 80
                        ? Colors.amber
                        : theme.colorScheme.primary,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$accuracy% Accuracy',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${session.correctCount}/${session.reviewedCount} correct',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.check),
              label: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(
    BuildContext context,
    ReviewSessionState session,
    ThemeData theme,
  ) {
    final item = session.currentItem;
    if (item == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: session.currentIndex / session.items.length,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
          const SizedBox(height: 8),
          // Content type badge
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              label: Text(
                item.contentType.displayName,
                style: theme.textTheme.labelSmall,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(height: 16),
          // Flashcard
          Expanded(
            child: GestureDetector(
              onTap: _toggleAnswer,
              child: AnimatedBuilder(
                animation: _flipAnimation,
                builder: (context, child) {
                  final isBack = _flipAnimation.value > 0.5;
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(_flipAnimation.value * 3.14159),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!isBack) ...[
                              Icon(
                                Icons.lightbulb_outline,
                                size: 48,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                item.title,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Tap to reveal answer',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ] else ...[
                              // Back of card (mirrored)
                              Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()..rotateY(3.14159),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline,
                                      size: 48,
                                      color: theme.colorScheme.secondary,
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      item.subtitle ?? 'No additional info',
                                      style: theme.textTheme.titleLarge,
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'How well did you remember?',
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Quality buttons
          if (_showAnswer) _buildQualityButtons(theme),
          if (!_showAnswer)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      ref.read(reviewSessionProvider.notifier).skipCurrentItem();
                      HapticUtils.light();
                    },
                    icon: const Icon(Icons.skip_next),
                    label: const Text('Skip'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQualityButtons(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _QualityButton(
                  quality: RecallQuality.blackout,
                  color: Colors.red,
                  onPressed: () =>
                      _handleQualitySelected(RecallQuality.blackout),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QualityButton(
                  quality: RecallQuality.incorrect,
                  color: Colors.orange,
                  onPressed: () =>
                      _handleQualitySelected(RecallQuality.incorrect),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QualityButton(
                  quality: RecallQuality.difficult,
                  color: Colors.amber,
                  onPressed: () =>
                      _handleQualitySelected(RecallQuality.difficult),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _QualityButton(
                  quality: RecallQuality.hesitant,
                  color: Colors.lightGreen,
                  onPressed: () =>
                      _handleQualitySelected(RecallQuality.hesitant),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QualityButton(
                  quality: RecallQuality.good,
                  color: Colors.green,
                  onPressed: () =>
                      _handleQualitySelected(RecallQuality.good),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QualityButton(
                  quality: RecallQuality.perfect,
                  color: Colors.teal,
                  onPressed: () =>
                      _handleQualitySelected(RecallQuality.perfect),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QualityButton extends StatelessWidget {
  final RecallQuality quality;
  final Color color;
  final VoidCallback onPressed;

  const _QualityButton({
    required this.quality,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.2),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            quality.value.toString(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            quality.shortLabel,
            style: const TextStyle(fontSize: 10),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Extension for short labels on quality buttons
extension RecallQualityLabels on RecallQuality {
  String get shortLabel {
    switch (this) {
      case RecallQuality.blackout:
        return 'Forgot';
      case RecallQuality.incorrect:
        return 'Wrong';
      case RecallQuality.difficult:
        return 'Hard';
      case RecallQuality.hesitant:
        return 'Okay';
      case RecallQuality.good:
        return 'Good';
      case RecallQuality.perfect:
        return 'Easy';
    }
  }
}

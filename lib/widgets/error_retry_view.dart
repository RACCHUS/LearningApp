import 'package:flutter/material.dart';

/// A reusable, user-friendly error view with an optional retry action.
///
/// Use this in `AsyncValue.when(error: ...)` branches and `FutureBuilder`
/// error states instead of dumping raw exception strings to the screen.
class ErrorRetryView extends StatelessWidget {
  /// Short, human-readable description of what went wrong.
  final String message;

  /// Optional technical detail (only shown when [showDetails] is true).
  final Object? error;

  /// Whether to reveal the raw error text (handy in debug builds).
  final bool showDetails;

  /// Called when the user taps "Try again". When null, no retry button shows.
  final VoidCallback? onRetry;

  /// Optional override for the retry button label.
  final String retryLabel;

  /// Optional icon shown above the message.
  final IconData icon;

  const ErrorRetryView({
    super.key,
    this.message = 'Something went wrong.',
    this.error,
    this.showDetails = false,
    this.onRetry,
    this.retryLabel = 'Try again',
    this.icon = Icons.error_outline,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Semantics(
          liveRegion: true,
          container: true,
          label: 'Error: $message',
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (showDetails && error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(retryLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

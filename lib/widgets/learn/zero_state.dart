import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/theme/design_tokens.dart';
import 'package:learning_pwa/widgets/targets/create_target_dialog.dart';

/// Calm, restrained First-Run & Selection Surface.
///
/// Keeps Learn quiet and focused:
/// "What do you want to learn?" -> [ Find something to learn ] -> /library
/// with a subtle "Create your own →" action.
/// The rich multi-destination taxonomy lives cleanly in Library, keeping Learn
/// free of cognitive overload and distracting lists.
class LearnZeroState extends StatelessWidget {
  final bool catalogEmpty;

  const LearnZeroState({super.key, this.catalogEmpty = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (catalogEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space4,
            vertical: DesignTokens.space6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.flag_outlined,
                  size: 28,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: DesignTokens.space4),
              Text(
                'Set your first learning goal',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DesignTokens.space2),
              Text(
                'Create your own exam, course, certification, or subject to start learning.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DesignTokens.space5),
              FilledButton.icon(
                key: const Key('zero-create-goal-btn'),
                onPressed: () => CreateTargetDialog.show(context),
                icon: const Icon(Icons.add),
                label: const Text('Create a goal'),
              ),
              const SizedBox(height: DesignTokens.space3),
              TextButton(
                key: const Key('zero-explore-library-link'),
                onPressed: () => context.go('/library'),
                child: const Text('Explore library →'),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space4,
          vertical: DesignTokens.space6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.compass_calibration_outlined,
                size: 28,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: DesignTokens.space4),
            Text(
              'What do you want to learn?',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.space2),
            Text(
              'Find an exam, certification, course, or subject and start from there.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.space5),
            FilledButton.icon(
              key: const Key('zero-explore-learning-btn'),
              onPressed: () => context.go('/library'),
              icon: const Icon(Icons.explore_outlined),
              label: const Text('Find something to learn'),
            ),
            const SizedBox(height: DesignTokens.space3),
            TextButton(
              key: const Key('zero-create-own-link'),
              onPressed: () => CreateTargetDialog.show(context),
              child: const Text('Create your own →'),
            ),
          ],
        ),
      ),
    );
  }
}

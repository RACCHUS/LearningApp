import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/next_action_provider.dart';
import 'package:learning_pwa/services/next_action_engine.dart';
import 'package:learning_pwa/theme/design_tokens.dart';
import 'package:learning_pwa/widgets/account_actions.dart';
import 'package:learning_pwa/widgets/app_shell.dart';
import 'package:learning_pwa/widgets/learn/context_switcher.dart';
import 'package:learning_pwa/widgets/learn/continue_card.dart';
import 'package:learning_pwa/widgets/learn/review_prompt.dart';
import 'package:learning_pwa/widgets/learn/zero_state.dart';

/// Doing, not managing. One primary action, one secondary, and a review prompt
/// only when there is something to review.
class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // One-time, idempotent backfill of contexts for pre-existing learners.
    ref.watch(learningBootstrapProvider);

    final contextsState = ref.watch(learningContextsProvider);
    final action = ref.watch(nextActionProvider);
    final engine = ref.watch(nextActionEngineProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: DesignTokens.space4,
        title: ContextSwitcher(state: contextsState),
        actions: const [AccountActions()],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(learningContextsProvider.notifier).load();
          ref.invalidate(nextActionProvider);
        },
        child: ListView(
          children: [
            LearnColumn(
              child: action.when(
                loading: () => const _LearnLoading(),
                error: (e, _) => _LearnError(
                  onRetry: () => ref.invalidate(nextActionProvider),
                ),
                data: (next) => _LearnBody(
                  action: next,
                  showReviewPrompt: engine.showSecondaryReviewPrompt(
                    next,
                    ref.watch(activeDueCountProvider).valueOrNull ?? 0,
                  ),
                  dueCount: ref.watch(activeDueCountProvider).valueOrNull ?? 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LearnBody extends StatelessWidget {
  final NextAction action;
  final bool showReviewPrompt;
  final int dueCount;

  const _LearnBody({
    required this.action,
    required this.showReviewPrompt,
    required this.dueCount,
  });

  @override
  Widget build(BuildContext context) {
    if (action is ChooseSomething) {
      return LearnZeroState(
        catalogEmpty: (action as ChooseSomething).catalogEmpty,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ContinueCard(action: action),
        if (showReviewPrompt) ...[
          const SizedBox(height: DesignTokens.space5),
          const Divider(height: 1),
          const SizedBox(height: DesignTokens.space5),
          ReviewPrompt(dueCount: dueCount),
        ],
      ],
    );
  }
}

class _LearnLoading extends StatelessWidget {
  const _LearnLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: DesignTokens.space7),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _LearnError extends StatelessWidget {
  final VoidCallback onRetry;
  const _LearnError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: DesignTokens.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Could not work out what to do next.',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: DesignTokens.space2),
          Text(
            'Your learning is safe. This is usually a connection problem.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: DesignTokens.space4),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ),
          const SizedBox(height: DesignTokens.space3),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => context.go('/library'),
              child: const Text('Go to Library'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper used by widgets that need the active context label.
String contextLabelOf(LearningContext? context) => context?.label ?? 'Learn';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/companion/goal_coverage.dart';
import 'package:learning_pwa/models/content_generation/coverage_matrix.dart';
import 'package:learning_pwa/providers/learner_resource_provider.dart';
import 'package:learning_pwa/providers/learning_target_provider.dart';
import 'package:learning_pwa/theme/design_tokens.dart';
import 'package:learning_pwa/widgets/targets/target_coverage_card.dart';

/// Opens LearningApp's own lesson for one objective: the lesson itself when
/// there is exactly one, otherwise the goal's outline to choose from.
Future<void> openObjectiveInLearningApp(
  BuildContext context,
  WidgetRef ref, {
  required String targetId,
  required String objectiveId,
}) async {
  final router = GoRouter.of(context);
  var path = '/target/$targetId/outline';
  try {
    final lessons = await ref.read(nodeLessonsProvider(objectiveId).future);
    if (lessons.length == 1) path = '/lesson/${lessons.single.lessonId}';
  } catch (_) {
    // The outline still gets the learner there.
  }
  router.push(path);
}

/// What the learner's outside resources leave out of a goal, and the
/// smallest way to fill each gap (companion plan v1.0 §3.1 "Fill", EX-2):
/// a LearningApp lesson where one exists, otherwise ask for one or make a
/// private version. Also names what LearningApp cannot check yet.
class GoalGapsScreen extends ConsumerWidget {
  const GoalGapsScreen({super.key, required this.goal});

  final GoalRef goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final coverage = ref.watch(goalCoverageProvider(goal));
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final c = coverage.valueOrNull;

    Widget section(String title, String note, List<GoalCoverageEntry> entries, String keyName, _GapAction action) {
      if (entries.isEmpty) return const SizedBox.shrink();
      return Column(
        key: Key('goal_gaps_$keyName'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: DesignTokens.space4),
          Text(
            '$title (${entries.length})',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: DesignTokens.space1),
          Text(note, style: muted),
          for (final e in entries) _GapTile(entry: e, action: action, goal: goal),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Gaps in what you use')),
      body: c == null
          ? Center(
              child: coverage.isLoading
                  ? const CircularProgressIndicator()
                  : const Text("Couldn't load this. Check your connection and try again."),
            )
          : ListView(
              padding: const EdgeInsets.all(DesignTokens.space4),
              children: [
                Text(
                  c.of(GoalCoverageKind.appOnly).isEmpty && c.of(GoalCoverageKind.nothing).isEmpty
                      ? 'What you use covers every objective of this goal.'
                      : 'These objectives are not in anything you added for this goal.',
                  key: const Key('goal_gaps_intro'),
                  style: theme.textTheme.bodyMedium,
                ),
                if (!c.appContentKnown)
                  Padding(
                    padding: const EdgeInsets.only(top: DesignTokens.space2),
                    child: Text(
                      "LearningApp's own content for this goal couldn't be read, so lessons are not suggested here.",
                      key: const Key('goal_gaps_app_unknown'),
                      style: muted,
                    ),
                  ),
                section(
                  'LearningApp can fill these',
                  'LearningApp has lessons for them.',
                  c.of(GoalCoverageKind.appOnly),
                  'app_only',
                  _GapAction.openLesson,
                ),
                section(
                  'Not covered by anything yet',
                  'Neither what you use nor LearningApp covers them. They are never counted as done or as zero.',
                  c.of(GoalCoverageKind.nothing),
                  'nothing',
                  _GapAction.request,
                ),
                section(
                  "LearningApp can't check these yet",
                  'You study them outside, but LearningApp has no independent checks for them, so they '
                      "can't count toward readiness yet.",
                  c.uncheckable,
                  'uncheckable',
                  _GapAction.request,
                ),
              ],
            ),
    );
  }
}

enum _GapAction { openLesson, request }

class _GapTile extends ConsumerWidget {
  const _GapTile({required this.entry, required this.action, required this.goal});

  final GoalCoverageEntry entry;
  final _GapAction action;
  final GoalRef goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final row = entry.row;
    final key = entry.item.key;
    return Padding(
      padding: const EdgeInsets.only(top: DesignTokens.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.item.label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          if (entry.outsideTitles.isNotEmpty)
            Text('In: ${entry.outsideTitles.join(', ')}', style: theme.textTheme.bodySmall),
          Wrap(
            spacing: DesignTokens.space2,
            children: [
              if (action == _GapAction.openLesson && row != null)
                TextButton.icon(
                  key: Key('gap_open_$key'),
                  onPressed: () => openObjectiveInLearningApp(
                    context,
                    ref,
                    targetId: goal.targetId,
                    objectiveId: row.objectiveId,
                  ),
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: const Text('Open the LearningApp lesson'),
                ),
              if (action == _GapAction.request) ...[
                if (row != null)
                  TextButton.icon(
                    key: Key('gap_make_own_$key'),
                    onPressed: () => openMakeMyOwnVersion(
                      context,
                      need: CoverageNeed(row: row, missing: row.gaps),
                      targetVersionId: goal.targetVersionId,
                    ),
                    icon: const Icon(Icons.edit_note, size: 18),
                    label: const Text('Make my own version'),
                  ),
                TextButton.icon(
                  key: Key('gap_ask_$key'),
                  onPressed: () => GoRouter.of(context).push('/community/wanted'),
                  icon: const Icon(Icons.campaign_outlined, size: 18),
                  label: const Text('Ask for it'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

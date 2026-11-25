import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/companion/goal_coverage.dart';
import 'package:learning_pwa/models/companion/learner_resource.dart';
import 'package:learning_pwa/models/objective_readiness.dart';
import 'package:learning_pwa/providers/learner_resource_provider.dart';
import 'package:learning_pwa/providers/learning_support_controller_provider.dart';
import 'package:learning_pwa/providers/learning_target_provider.dart';
import 'package:learning_pwa/providers/target_readiness_provider.dart';
import 'package:learning_pwa/screens/companion/goal_gaps_screen.dart';
import 'package:learning_pwa/screens/companion/resource_outline_screen.dart';
import 'package:learning_pwa/theme/design_tokens.dart';
import 'package:learning_pwa/widgets/help/help_action.dart';

/// Opens the companion for a resource from a link that carries only ids
/// (`/target/<target>/companion/<resource>`): resolves the goal first.
class CompanionRouteScreen extends ConsumerWidget {
  const CompanionRouteScreen({
    super.key,
    required this.targetId,
    required this.resourceId,
  });

  final String targetId;
  final String resourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(targetDetailProvider(targetId));
    final version = ref.watch(targetVersionProvider(targetId));
    final t = target.valueOrNull, v = version.valueOrNull;
    if (t == null || v == null || !ref.watch(learnerResourcesEnabledProvider)) {
      return Scaffold(
        appBar: AppBar(actions: const [HelpAction()]),
        body: Center(
          child: target.isLoading || version.isLoading
              ? const CircularProgressIndicator()
              : const Text(
                  "This can't be shown right now.",
                  key: Key('companion_unavailable'),
                ),
        ),
      );
    }
    return CompanionScreen(
      goal: (targetId: t.id, targetVersionId: v.id, targetSlug: t.slug),
      resourceId: resourceId,
    );
  }
}

/// The step-by-step companion to one outside resource (companion plan v1.0
/// §3.1, §5.3, EX-4): one part at a time, what to look for in it, a "done
/// studying" mark and LearningApp's own check for each objective. It picks
/// up at the first part not yet marked. One column, so it stays usable in a
/// narrow split-view pane. "Studied" is the learner's own note: only
/// LearningApp's checks move readiness.
class CompanionScreen extends ConsumerWidget {
  const CompanionScreen({
    super.key,
    required this.goal,
    required this.resourceId,
  });

  final GoalRef goal;
  final String resourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final resources = ref.watch(learnerResourcesProvider(goal.targetId));
    final nodes = ref.watch(
      targetCurriculumNodesProvider(goal.targetVersionId),
    );
    final readiness = ref
        .watch(objectiveReadinessProvider(goal.targetVersionId))
        .valueOrNull;
    final resource = resources.valueOrNull
        ?.where((r) => r.id == resourceId)
        .firstOrNull;

    if (resource == null) {
      return Scaffold(
        appBar: AppBar(actions: const [HelpAction()]),
        body: Center(
          child: resources.isLoading
              ? const CircularProgressIndicator()
              : const Text(
                  'This is no longer in your list.',
                  key: Key('companion_missing'),
                ),
        ),
      );
    }

    final outline = ResourceOutline.fromNodes(nodes.valueOrNull ?? const []);
    final labelByKey = {
      for (final g in outline.groups)
        for (final i in g.items) i.key: i.label,
    };
    final codeByKey = {
      for (final g in outline.groups)
        for (final i in g.items) i.key: i.code,
    };
    final statusByCode = <String, ObjectiveReadinessStatus>{
      for (final d in readiness?.domains ?? const <DomainReadiness>[]) ...{
        if (d.code.isNotEmpty) d.code: d.status,
        for (final o in d.objectives)
          if (o.code.isNotEmpty) o.code: o.status,
      },
    };
    final entryByKey = {
      for (final e
          in ref.watch(goalCoverageProvider(goal)).valueOrNull?.entries ??
              const <GoalCoverageEntry>[])
        e.item.key: e,
    };
    final sections = resource.sections;
    final next = resource.nextSectionIndex;
    final store = ref.read(learnerResourceStoreProvider);

    Future<void> mark(int index, bool studied) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await store.setSectionStudied(resource.id, index, studied);
      } catch (_) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't save that. Check your connection and try again.",
            ),
          ),
        );
      }
      ref.invalidate(learnerResourcesProvider(goal.targetId));
    }

    Future<void> open() async {
      var ok = false;
      try {
        ok = await ref.read(externalLinkLauncherProvider)(
          Uri.parse(resource.url!),
        );
      } catch (_) {}
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't open the link.")),
        );
      }
    }

    void editOutline() => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ResourceOutlineScreen(goal: goal, resourceId: resource.id),
      ),
    );

    final remaining = resource.remainingMinutes;
    final noEstimate = resource.remainingWithoutEstimate;
    final String summary;
    if (sections.isEmpty) {
      summary =
          'Add the list of chapters, units or videos to get a step-by-step plan.';
    } else if (next == null) {
      summary =
          'You have marked every part studied. '
          'Check yourself in LearningApp to see where you stand.';
    } else {
      final time = remaining == 0
          ? ''
          : noEstimate == 0
          ? ' About ${formatStudyMinutes(remaining)} of outside study left.'
          : ' At least ${formatStudyMinutes(remaining)} of outside study left '
                '($noEstimate ${noEstimate == 1 ? 'part has' : 'parts have'} no time estimate).';
      summary =
          '${resource.studiedSectionCount} of ${sections.length} parts studied.$time';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(resource.title),
        actions: [
          if (sections.isNotEmpty)
            IconButton(
              key: const Key('companion_edit_outline'),
              tooltip: 'Edit outline',
              icon: const Icon(Icons.format_list_numbered),
              onPressed: editOutline,
            ),
          const HelpAction(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(DesignTokens.space3),
        children: [
          Text(
            summary,
            key: const Key('companion_summary'),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: DesignTokens.space2),
          Wrap(
            spacing: DesignTokens.space2,
            runSpacing: DesignTokens.space2,
            children: [
              if (resource.url != null)
                FilledButton.tonalIcon(
                  key: const Key('companion_open'),
                  onPressed: open,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open (leaves LearningApp)'),
                ),
              if (sections.isEmpty)
                OutlinedButton.icon(
                  key: const Key('companion_add_outline'),
                  onPressed: editOutline,
                  icon: const Icon(Icons.format_list_numbered),
                  label: const Text('Paste its outline'),
                ),
            ],
          ),
          for (final (i, s) in sections.indexed)
            Card(
              // The key changes when the resume point moves, so the new
              // current part opens and the one just finished closes.
              key: ValueKey('companion_step_${i}_${i == next}'),
              margin: const EdgeInsets.only(top: DesignTokens.space2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                side: BorderSide(
                  color: i == next
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                  width: i == next ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                key: Key('companion_tile_$i'),
                initiallyExpanded: i == next,
                shape: const Border(),
                collapsedShape: const Border(),
                leading: Icon(
                  s.studied ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: s.studied
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(s.title),
                subtitle: Text(
                  [
                    if (i == next) 'Next',
                    if (s.studied) 'Studied',
                    if (s.minutes != null)
                      'about ${formatStudyMinutes(s.minutes!)}',
                  ].join(' · '),
                  key: Key('companion_state_$i'),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(
                  DesignTokens.space3,
                  0,
                  DesignTokens.space3,
                  DesignTokens.space3,
                ),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.objectiveKeys.any(labelByKey.containsKey)
                        ? 'In this part, look for:'
                        : 'No objectives are matched to this part.',
                    style: muted,
                  ),
                  for (final key in labelByKey.keys.where(
                    s.objectiveKeys.contains,
                  ))
                    _CompanionObjective(
                      stepIndex: i,
                      objectiveKey: key,
                      label: labelByKey[key]!,
                      status: codeByKey[key] == null
                          ? null
                          : statusByCode[codeByKey[key]],
                      hasIndependentChecks:
                          entryByKey[key]?.appHasChecks == true,
                      onCheck: entryByKey[key]?.appHasLessons == true
                          ? () => openObjectiveInLearningApp(
                              context,
                              ref,
                              targetId: goal.targetId,
                              objectiveId: entryByKey[key]!.row!.objectiveId,
                            )
                          : null,
                    ),
                  const SizedBox(height: DesignTokens.space2),
                  if (s.studied)
                    TextButton(
                      key: Key('companion_undo_$i'),
                      onPressed: () => mark(i, false),
                      child: const Text('Not studied yet'),
                    )
                  else
                    FilledButton.icon(
                      key: Key('companion_done_$i'),
                      onPressed: () => mark(i, true),
                      icon: const Icon(Icons.check),
                      label: const Text('Done studying this part'),
                    ),
                ],
              ),
            ),
          const SizedBox(height: DesignTokens.space3),
          Text(
            'Studied is your own note. LearningApp cannot see what you do outside it, '
            "so only LearningApp's checks count toward readiness.",
            key: const Key('companion_self_report_note'),
            style: muted,
          ),
        ],
      ),
    );
  }
}

class _CompanionObjective extends StatelessWidget {
  const _CompanionObjective({
    required this.stepIndex,
    required this.objectiveKey,
    required this.label,
    required this.status,
    required this.hasIndependentChecks,
    required this.onCheck,
  });

  final int stepIndex;
  final String objectiveKey;
  final String label;
  final ObjectiveReadinessStatus? status;
  final bool hasIndependentChecks;

  /// Opens LearningApp's lesson for this objective; null when it has none.
  final VoidCallback? onCheck;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: DesignTokens.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          if (status != null)
            Text(
              'LearningApp checks: ${status!.label}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (onCheck != null)
            TextButton.icon(
              key: Key('companion_check_${stepIndex}_$objectiveKey'),
              onPressed: onCheck,
              icon: const Icon(Icons.fact_check_outlined, size: 18),
              label: Text(
                hasIndependentChecks
                    ? 'Check this in LearningApp'
                    : 'Practise this in LearningApp',
              ),
            ),
        ],
      ),
    );
  }
}

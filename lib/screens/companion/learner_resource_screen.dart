import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/companion/goal_coverage.dart';
import 'package:learning_pwa/models/companion/learner_resource.dart';
import 'package:learning_pwa/models/objective_readiness.dart';
import 'package:learning_pwa/providers/learner_resource_provider.dart';
import 'package:learning_pwa/providers/learning_support_controller_provider.dart';
import 'package:learning_pwa/providers/learning_target_provider.dart';
import 'package:learning_pwa/providers/target_readiness_provider.dart';
import 'package:learning_pwa/theme/design_tokens.dart';
import 'package:learning_pwa/screens/companion/companion_screen.dart';
import 'package:learning_pwa/screens/companion/goal_gaps_screen.dart';
import 'package:learning_pwa/screens/companion/resource_outline_screen.dart';
import 'package:learning_pwa/widgets/companion/learner_resources_card.dart';

/// One outside resource beside its goal (companion plan v1.0, EX-1): the
/// learner ticks which objectives it covers and marks parts studied. A
/// "studied" mark is the learner's own note. Only LearningApp's checks move
/// readiness, which is shown here read-only next to each objective.
class LearnerResourceScreen extends ConsumerWidget {
  const LearnerResourceScreen({super.key, required this.goal, required this.resourceId});

  final GoalRef goal;
  final String resourceId;

  String get targetId => goal.targetId;
  String get targetVersionId => goal.targetVersionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final resources = ref.watch(learnerResourcesProvider(targetId));
    final nodes = ref.watch(targetCurriculumNodesProvider(targetVersionId));
    final readiness = ref.watch(objectiveReadinessProvider(targetVersionId)).valueOrNull;
    final resource = resources.valueOrNull?.where((r) => r.id == resourceId).firstOrNull;
    // LearningApp's own content per objective, for the per-objective check.
    final entryByKey = {
      for (final e in ref.watch(goalCoverageProvider(goal)).valueOrNull?.entries ?? const <GoalCoverageEntry>[])
        e.item.key: e,
    };

    if (resource == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: resources.isLoading
              ? const CircularProgressIndicator()
              : const Text('This is no longer in your list.', key: Key('learner_resource_missing')),
        ),
      );
    }

    final outline = ResourceOutline.fromNodes(nodes.valueOrNull ?? const []);
    final covered = resource.objectives.keys.toSet();
    final coveredHere = outline.keys.where(covered.contains).length;
    final statusByCode = <String, ObjectiveReadinessStatus>{
      // Areas too: in a goal without objectives the areas are what is ticked.
      for (final d in readiness?.domains ?? const <DomainReadiness>[]) ...{
        if (d.code.isNotEmpty) d.code: d.status,
        for (final o in d.objectives)
          if (o.code.isNotEmpty) o.code: o.status,
      },
    };
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final store = ref.read(learnerResourceStoreProvider);

    Future<void> run(Future<void> Function() change) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await change();
      } catch (_) {
        messenger.showSnackBar(
          const SnackBar(content: Text("Couldn't save that. Check your connection and try again.")),
        );
      }
      ref.invalidate(learnerResourcesProvider(targetId));
    }

    Future<void> open() async {
      var ok = false;
      try {
        ok = await ref.read(externalLinkLauncherProvider)(Uri.parse(resource.url!));
      } catch (_) {}
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't open the link. Use Copy link instead.")),
        );
      }
    }

    Future<void> remove() async {
      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Remove this?'),
          content: Text(
            '"${resource.title}" and your ticks for it will be removed. Your LearningApp progress is not affected.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Keep')),
            FilledButton(
              key: const Key('learner_resource_confirm_remove'),
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (yes != true) return;
      await run(() => store.delete(resource.id));
      if (context.mounted) Navigator.of(context).pop();
    }

    final sharePercent = (outline.coverageShare(covered) * 100).round();
    final access = resource.access;

    return Scaffold(
      appBar: AppBar(
        title: Text(resource.title),
        actions: [
          IconButton(
            key: const Key('learner_resource_edit'),
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showLearnerResourceDialog(context, ref, targetId: targetId, existing: resource),
          ),
          IconButton(
            key: const Key('learner_resource_remove'),
            tooltip: 'Remove',
            icon: const Icon(Icons.delete_outline),
            onPressed: remove,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(DesignTokens.space4),
        children: [
          Text(
            access == null ? resource.kind.label : '${resource.kind.label} · ${access.label}',
            style: theme.textTheme.bodyMedium,
          ),
          if (resource.url != null) ...[
            const SizedBox(height: DesignTokens.space2),
            Wrap(
              spacing: DesignTokens.space2,
              children: [
                FilledButton.tonalIcon(
                  key: const Key('learner_resource_open'),
                  onPressed: open,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open (leaves LearningApp)'),
                ),
                TextButton.icon(
                  key: const Key('learner_resource_copy'),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(ClipboardData(text: resource.url!));
                    messenger.showSnackBar(const SnackBar(content: Text('Link copied.')));
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy link'),
                ),
              ],
            ),
            Text(resource.url!, style: muted),
          ],
          const SizedBox(height: DesignTokens.space3),
          Text(
            outline.itemCount == 0
                ? 'This goal has no objectives to tick yet.'
                : outline.usesWeights
                ? 'Covers $coveredHere of ${outline.itemCount} objectives, about $sharePercent% of this goal by weight. '
                      '${resource.studiedCount} marked studied.'
                : 'Covers $coveredHere of ${outline.itemCount} objectives. ${resource.studiedCount} marked studied.',
            key: const Key('learner_resource_summary'),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: DesignTokens.space2),
          Text(
            'Tick what this covers. When you have studied a part, mark it Studied. '
            "Studied is your own note. Only LearningApp's checks count toward readiness.",
            key: const Key('learner_resource_self_report_note'),
            style: muted,
          ),
          const SizedBox(height: DesignTokens.space2),
          Wrap(
            spacing: DesignTokens.space2,
            runSpacing: DesignTokens.space2,
            children: [
              OutlinedButton.icon(
                key: const Key('learner_resource_check'),
                onPressed: () => context.push('/target/$targetId/outline'),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Check yourself in LearningApp'),
              ),
              if (resource.sections.isNotEmpty)
                FilledButton.tonalIcon(
                  key: const Key('learner_resource_companion'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CompanionScreen(goal: goal, resourceId: resource.id),
                    ),
                  ),
                  icon: const Icon(Icons.playlist_play),
                  label: Text(
                    resource.nextSectionIndex == null
                        ? 'Study plan'
                        : 'Continue: ${resource.sections[resource.nextSectionIndex!].title}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (outline.itemCount > 0)
                OutlinedButton.icon(
                  key: const Key('learner_resource_outline'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ResourceOutlineScreen(goal: goal, resourceId: resource.id),
                    ),
                  ),
                  icon: const Icon(Icons.format_list_numbered),
                  label: Text(
                    resource.sections.isEmpty
                        ? 'Paste its outline to tick faster'
                        : 'Edit outline (${resource.sections.length == 1 ? '1 part' : '${resource.sections.length} parts'})',
                  ),
                ),
            ],
          ),
          if (nodes.isLoading)
            const Padding(
              padding: EdgeInsets.all(DesignTokens.space4),
              child: Center(child: CircularProgressIndicator()),
            ),
          for (final g in outline.groups) ...[
            const SizedBox(height: DesignTokens.space4),
            Text(g.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            for (final item in g.items)
              _ObjectiveRow(
                item: item,
                covered: covered.contains(item.key),
                studied: resource.objectives[item.key] != null,
                status: item.code == null ? null : statusByCode[item.code],
                sections: covered.contains(item.key) ? resource.sectionTitlesFor(item.key) : const [],
                onCovers: (v) => run(
                  () => store.setObjectives(resource.id, v ? {...covered, item.key} : ({...covered}..remove(item.key))),
                ),
                onStudied: (v) => run(() => store.setStudied(resource.id, item.key, v)),
                hasIndependentChecks: entryByKey[item.key]?.appHasChecks == true,
                onCheck: entryByKey[item.key]?.appHasLessons == true
                    ? () => openObjectiveInLearningApp(
                        context,
                        ref,
                        targetId: targetId,
                        objectiveId: entryByKey[item.key]!.row!.objectiveId,
                      )
                    : null,
              ),
          ],
          if (outline.itemCount > coveredHere && coveredHere > 0) ...[
            const SizedBox(height: DesignTokens.space4),
            Text(
              '${outline.itemCount - coveredHere} objectives are not covered by this.',
              key: const Key('learner_resource_uncovered_note'),
              style: muted,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('learner_resource_gaps'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => GoalGapsScreen(goal: goal)),
                ),
                icon: const Icon(Icons.checklist_rtl, size: 18),
                label: const Text('See the gaps for this goal'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ObjectiveRow extends StatelessWidget {
  const _ObjectiveRow({
    required this.item,
    required this.covered,
    required this.studied,
    required this.status,
    required this.onCovers,
    required this.onStudied,
    required this.onCheck,
    required this.hasIndependentChecks,
    this.sections = const [],
  });

  /// Where in the resource the learner said this is, from their outline.
  final List<String> sections;

  final ResourceOutlineItem item;
  final bool covered;
  final bool studied;
  final ObjectiveReadinessStatus? status;
  final ValueChanged<bool> onCovers;
  final ValueChanged<bool> onStudied;

  /// Opens LearningApp's lesson for this objective; null when it has none.
  final VoidCallback? onCheck;

  /// False when LearningApp has lessons but no independent checks for it:
  /// the lesson then offers practice, which is not called a check.
  final bool hasIndependentChecks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(
          key: Key('covers_${item.key}'),
          value: covered,
          onChanged: (v) => onCovers(v ?? false),
          semanticLabel: 'Covers ${item.label}',
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: DesignTokens.space1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: theme.textTheme.bodyMedium),
                if (sections.isNotEmpty)
                  Text(
                    sections.length > 2
                        ? 'In: ${sections.take(2).join('; ')} and ${sections.length - 2} more'
                        : 'In: ${sections.join('; ')}',
                    key: Key('sections_${item.key}'),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                if (status != null)
                  Text(
                    'LearningApp checks: ${status!.label}',
                    key: Key('readiness_${item.key}'),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                if (covered && onCheck != null)
                  TextButton.icon(
                    key: Key('check_${item.key}'),
                    onPressed: onCheck,
                    icon: const Icon(Icons.fact_check_outlined, size: 18),
                    label: Text(
                      hasIndependentChecks ? 'Check this in LearningApp' : 'Practise this in LearningApp',
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (covered)
          FilterChip(
            key: Key('studied_${item.key}'),
            label: const Text('Studied'),
            selected: studied,
            onSelected: onStudied,
          ),
      ],
    );
  }
}

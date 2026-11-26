import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/companion/learner_resource.dart';
import 'package:learning_pwa/models/learning_support/external_companion.dart';
import 'package:learning_pwa/providers/learner_resource_provider.dart';
import 'package:learning_pwa/screens/companion/add_resource_screen.dart';
import 'package:learning_pwa/screens/companion/companion_screen.dart';
import 'package:learning_pwa/screens/companion/goal_gaps_screen.dart';
import 'package:learning_pwa/screens/companion/learner_resource_screen.dart';
import 'package:learning_pwa/services/companion/learner_resource_store.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// "Studying somewhere else?" on a goal (companion plan v1.0, EX-1): the
/// learner's own courses, videos and books for this goal. Shown only while
/// `content.learner_resources` is on; otherwise it takes no space.
class LearnerResourcesCard extends ConsumerWidget {
  const LearnerResourcesCard({
    super.key,
    required this.targetId,
    required this.targetVersionId,
    required this.targetSlug,
  });

  final String targetId;
  final String targetVersionId;
  final String targetSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(learnerResourcesEnabledProvider)) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final resources = ref.watch(learnerResourcesProvider(targetId));
    final stranded = ref.watch(strandedLocalResourcesProvider).valueOrNull ?? 0;
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final GoalRef goal = (targetId: targetId, targetVersionId: targetVersionId, targetSlug: targetSlug);

    Future<void> add() async {
      final id = await showLearnerResourceDialog(context, ref, targetId: targetId);
      if (id == null || !context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LearnerResourceScreen(goal: goal, resourceId: id),
        ),
      );
    }

    Future<void> moveToAccount() async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        final moved = await moveLocalResourcesToAccount(
          ref.read(localLearnerResourceStoreProvider),
          ref.read(learnerResourceStoreProvider),
        );
        messenger.showSnackBar(SnackBar(content: Text('Moved $moved to your account.')));
      } catch (_) {
        messenger.showSnackBar(
          const SnackBar(content: Text("Couldn't move everything. The rest is still on this device.")),
        );
      }
      ref.invalidate(strandedLocalResourcesProvider);
      ref.invalidate(learnerResourcesProvider);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.space3),
      child: Card(
        key: const Key('learner_resources_card'),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(DesignTokens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Studying somewhere else?',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: DesignTokens.space1),
              Text(
                'Add a course, video or book you use for this goal. LearningApp shows what it '
                'covers and checks what you have learned.',
                style: muted,
              ),
              if (resources.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: DesignTokens.space2),
                  child: Text(
                    "Couldn't load what you added. Check your connection and try again.",
                    key: const Key('learner_resources_error'),
                    style: muted,
                  ),
                ),
              for (final r in resources.valueOrNull ?? const <LearnerResource>[])
                ListTile(
                  key: Key('learner_resource_${r.id}'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.bookmark_outline),
                  title: Text(r.title),
                  subtitle: Text(
                    '${r.kind.label} · covers ${r.objectives.length} · ${r.studiedCount} marked studied',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LearnerResourceScreen(goal: goal, resourceId: r.id),
                    ),
                  ),
                ),
              // Resume point: the first part of each resource not yet marked studied.
              for (final r in resources.valueOrNull ?? const <LearnerResource>[])
                if (r.nextSectionIndex != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: Key('learner_resource_continue_${r.id}'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CompanionScreen(goal: goal, resourceId: r.id),
                        ),
                      ),
                      icon: const Icon(Icons.playlist_play, size: 18),
                      label: Text(
                        'Continue: ${r.sections[r.nextSectionIndex!].title}'
                        '${r.sections[r.nextSectionIndex!].minutes == null ? '' : ' (about ${formatStudyMinutes(r.sections[r.nextSectionIndex!].minutes!)})'}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              if ((resources.valueOrNull ?? const []).isNotEmpty) _GoalCoverageSummary(goal: goal),
              if (stranded > 0) ...[
                const SizedBox(height: DesignTokens.space2),
                Text(
                  '$stranded saved on this device ${stranded == 1 ? 'is' : 'are'} not in your account yet.',
                  key: const Key('learner_resources_stranded'),
                  style: muted,
                ),
                TextButton(
                  key: const Key('learner_resources_move'),
                  onPressed: moveToAccount,
                  child: const Text('Move to my account'),
                ),
              ],
              const SizedBox(height: DesignTokens.space2),
              OutlinedButton.icon(
                key: const Key('learner_resources_add'),
                onPressed: add,
                icon: const Icon(Icons.add),
                label: const Text("Add something you're using"),
              ),
              if (ref.watch(companionCaptureEnabledProvider))
                TextButton.icon(
                  key: const Key('learner_resources_capture'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const AddResourceScreen()),
                  ),
                  icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                  label: const Text('Add from another page with one tap'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How the goal is covered once the learner has added something: the share
/// in what they use, the share LearningApp can fill, and the share nothing
/// covers yet, with a way to the gaps.
class _GoalCoverageSummary extends ConsumerWidget {
  const _GoalCoverageSummary({required this.goal});
  final GoalRef goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(goalCoverageProvider(goal)).valueOrNull;
    if (c == null || c.outline.itemCount == 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final p = c.percents;
    final basis = c.outline.usesWeights ? 'by weight' : 'by number of objectives';
    return Padding(
      padding: const EdgeInsets.only(top: DesignTokens.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How this goal is covered ($basis)',
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text('In what you use: ${p.outside}%', key: const Key('goal_coverage_outside')),
          if (c.appContentKnown) ...[
            Text(
              'Not in what you use, but LearningApp has lessons: ${p.appOnly}%',
              key: const Key('goal_coverage_app_only'),
            ),
            Text('Not covered by anything yet: ${p.nothing}%', key: const Key('goal_coverage_nothing')),
          ] else
            Text('Not in what you use: ${100 - p.outside}%', key: const Key('goal_coverage_rest')),
          TextButton.icon(
            key: const Key('goal_coverage_gaps'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => GoalGapsScreen(goal: goal)),
            ),
            icon: const Icon(Icons.checklist_rtl, size: 18),
            label: const Text('See the gaps'),
          ),
        ],
      ),
    );
  }
}

/// Adds a resource, or edits [existing]. Returns its id, or null if the
/// learner cancelled.
Future<String?> showLearnerResourceDialog(
  BuildContext context,
  WidgetRef ref, {
  required String targetId,
  LearnerResource? existing,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _LearnerResourceDialog(targetId: targetId, existing: existing),
  );
}

class _LearnerResourceDialog extends ConsumerStatefulWidget {
  const _LearnerResourceDialog({required this.targetId, this.existing});
  final String targetId;
  final LearnerResource? existing;

  @override
  ConsumerState<_LearnerResourceDialog> createState() => _LearnerResourceDialogState();
}

class _LearnerResourceDialogState extends ConsumerState<_LearnerResourceDialog> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _link = TextEditingController(text: widget.existing?.url ?? '');
  late LearnerResourceKind _kind = widget.existing?.kind ?? LearnerResourceKind.course;
  late ExternalAccess? _access = widget.existing?.access;
  String? _titleError;
  String? _linkError;
  String? _saveError;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final link = normalizeLearnerLink(_link.text);
    setState(() {
      _titleError = title.isEmpty
          ? 'Give it a name.'
          : (title.length > LearnerResource.maxTitleLength ? 'Use a shorter name.' : null);
      _linkError = link.error;
      _saveError = null;
    });
    if (_titleError != null || _linkError != null) return;
    setState(() => _saving = true);
    try {
      final id = await ref.read(learnerResourceStoreProvider).save(
        id: widget.existing?.id,
        targetId: widget.targetId,
        title: title,
        kind: _kind,
        url: link.url,
        access: _access,
        catalogId: widget.existing?.catalogId,
      );
      ref.invalidate(learnerResourcesProvider(widget.targetId));
      if (mounted) Navigator.of(context).pop(id);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = "Couldn't save. Check your connection and try again.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.existing == null ? "Add something you're using" : 'Edit'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('learner_resource_title'),
              controller: _title,
              autofocus: true,
              maxLength: LearnerResource.maxTitleLength,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'The course, video or book',
                errorText: _titleError,
              ),
            ),
            DropdownButtonFormField<LearnerResourceKind>(
              key: const Key('learner_resource_kind'),
              isExpanded: true,
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'What is it?'),
              items: [
                for (final k in LearnerResourceKind.values) DropdownMenuItem(value: k, child: Text(k.label)),
              ],
              onChanged: (k) => setState(() => _kind = k ?? _kind),
            ),
            const SizedBox(height: DesignTokens.space2),
            TextField(
              key: const Key('learner_resource_link'),
              controller: _link,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Link (optional)',
                hintText: 'https://',
                errorText: _linkError,
              ),
            ),
            const SizedBox(height: DesignTokens.space2),
            DropdownButtonFormField<ExternalAccess?>(
              key: const Key('learner_resource_access'),
              isExpanded: true,
              initialValue: _access,
              decoration: const InputDecoration(labelText: 'Cost'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Not sure')),
                for (final a in ExternalAccess.values) DropdownMenuItem(value: a, child: Text(a.label)),
              ],
              onChanged: (a) => setState(() => _access = a),
            ),
            const SizedBox(height: DesignTokens.space3),
            Text(
              'Only you can see this. LearningApp does not read the page behind the link.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (_saveError != null)
              Padding(
                padding: const EdgeInsets.only(top: DesignTokens.space2),
                child: Text(
                  _saveError!,
                  key: const Key('learner_resource_save_error'),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          key: const Key('learner_resource_save'),
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

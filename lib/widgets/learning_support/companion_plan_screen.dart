import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/learning_support/companion_plan.dart';
import 'package:learning_pwa/providers/companion_plan_provider.dart';
import 'package:learning_pwa/providers/learning_support_controller_provider.dart';
import 'package:learning_pwa/widgets/learning_support/bridge_check_card.dart';

/// A full companion plan (master plan v2.6 §9.2 level 4): the steps of an
/// outside course in order, each with what to look for and short checks,
/// plus LearningApp fill-in lessons where the course skips something
/// (level 3). The learner ticks steps off; ticks stay on this device and
/// are never counted as progress or evidence.
class CompanionPlanScreen extends ConsumerWidget {
  const CompanionPlanScreen({super.key, required this.plan});

  final CompanionPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final done = ref.watch(companionPlanProgressProvider(plan.planId));
    final bridges = ref.watch(bridgeLibraryProvider).valueOrNull;
    final companions = ref.watch(externalCompanionLibraryProvider).valueOrNull;
    final ticked = plan.parts.where((p) => done.contains(p.partId)).length;

    return Scaffold(
      appBar: AppBar(title: Text(plan.title)),
      body: bridges == null || companions == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(plan.intro, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                Text(
                  '$ticked of ${plan.parts.length} steps ticked. Your ticks stay on this '
                  'device; reading outside is never tracked or counted as progress.',
                  key: const Key('companion-plan-progress'),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                for (final (i, part) in plan.parts.indexed)
                  _PartCard(
                    number: i + 1,
                    part: part,
                    done: done.contains(part.partId),
                    onToggle: () => ref
                        .read(companionPlanProgressProvider(plan.planId).notifier)
                        .toggle(part.partId),
                  ),
              ],
            ),
    );
  }
}

class _PartCard extends ConsumerWidget {
  const _PartCard({
    required this.number,
    required this.part,
    required this.done,
    required this.onToggle,
  });

  final int number;
  final CompanionPlanPart part;
  final bool done;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bridge = ref.watch(bridgeLibraryProvider).valueOrNull?[part.bridgeId];
    final companion =
        ref.watch(externalCompanionLibraryProvider).valueOrNull?.forBridge(part.bridgeId);
    if (bridge == null) return const SizedBox.shrink();
    final outside = part.kind == CompanionPlanPartKind.outsideSection && companion != null;
    final r = companion?.resource;

    Future<void> open() async {
      var ok = false;
      try {
        ok = await ref.read(externalLinkLauncherProvider)(Uri.parse(r!.url));
      } catch (_) {}
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Couldn't open the link. You can copy it from below."),
        ));
      }
    }

    return Card(
      key: Key('companion-plan-part-${part.partId}'),
      child: ExpansionTile(
        leading: Checkbox(
          key: Key('companion-plan-done-${part.partId}'),
          value: done,
          onChanged: (_) => onToggle(),
          semanticLabel: 'Step $number done',
        ),
        title: Text(outside
            ? 'Step $number: ${r!.section ?? r.title}'
            : 'Step $number: ${bridge.title} (short LearningApp lesson)'),
        subtitle: Text(outside
            ? '${r!.publisher}: ${r.title} · ${r.access.label}'
            : 'The outside course skips this; read it here.'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (outside) ...[
            Text('What to look for: ${companion.focusNote}', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              key: Key('companion-plan-open-${part.partId}'),
              onPressed: open,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open (leaves LearningApp)'),
            ),
            SelectableText(r!.url, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Text('Check yourself after reading (practice only):', style: theme.textTheme.bodyMedium),
            for (final (i, c) in companion.checks.indexed) BridgeCheckCard(check: c, index: i),
          ] else ...[
            Text(bridge.objectiveStatement, style: theme.textTheme.bodyMedium),
            for (final b in [...bridge.teach, ...bridge.examples])
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(b.text, style: theme.textTheme.bodyMedium),
              ),
            const SizedBox(height: 8),
            Text('Check yourself (practice only):', style: theme.textTheme.bodyMedium),
            for (final (i, c) in bridge.checks.indexed) BridgeCheckCard(check: c, index: i),
          ],
        ],
      ),
    );
  }
}

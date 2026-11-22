import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/content_generation/coverage_matrix.dart';
import 'package:learning_pwa/providers/target_coverage_provider.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// Opens the private "make my own version" flow for one objective: a
/// personal lesson attached to that topic, never published by this action.
void openMakeMyOwnVersion(
  BuildContext context, {
  required CoverageNeed need,
  required String targetVersionId,
}) {
  final uri = Uri(
    path: '/create-lesson',
    queryParameters: {
      'nodeId': need.row.objectiveId,
      'nodeTitle': need.row.title,
      'targetVersionId': targetVersionId,
      'attachmentIntent': 'personal_study',
    },
  );
  GoRouter.of(context).push(uri.toString());
}

/// Target Detail coverage chips (master plan v2.6 §4.2, §13.0): per role,
/// how many objectives are reviewed, imported, outside, gaps or not yet
/// verified, always as text and never by colour alone; then Need cards for
/// the objectives with missing pieces.
class TargetCoverageCard extends ConsumerStatefulWidget {
  const TargetCoverageCard({
    super.key,
    required this.targetSlug,
    required this.targetVersionId,
  });

  final String targetSlug;
  final String targetVersionId;

  @override
  ConsumerState<TargetCoverageCard> createState() => _TargetCoverageCardState();
}

class _TargetCoverageCardState extends ConsumerState<TargetCoverageCard> {
  static const _collapsedNeeds = 3;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(targetCoverageProvider(widget.targetSlug)).valueOrNull;
    // Nothing published to measure (or the lookup failed): show nothing
    // rather than an empty or misleading matrix.
    if (summary == null || summary.rows.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final needs = summary.needs;
    final shown = _showAll ? needs : needs.take(_collapsedNeeds).toList();

    return Card(
      key: const Key('target-coverage-card'),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("What's here for this goal",
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: DesignTokens.space1),
            Text(
              'Across ${summary.rows.length} topics. "Imported" means taken from an open '
              'textbook and not yet reviewed here.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: DesignTokens.space2),
            Wrap(
              spacing: DesignTokens.space2,
              runSpacing: DesignTokens.space2,
              children: [
                for (final role in CoverageRole.values)
                  _RoleChip(role: role, counts: summary.countsFor(role)),
              ],
            ),
            if (needs.isNotEmpty) ...[
              const SizedBox(height: DesignTokens.space3),
              Text('Missing pieces (${needs.length})',
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: DesignTokens.space1),
              for (final n in shown)
                NeedCard(need: n, targetVersionId: widget.targetVersionId),
              if (needs.length > _collapsedNeeds)
                TextButton(
                  key: const Key('target-coverage-show-all'),
                  onPressed: () => setState(() => _showAll = !_showAll),
                  child: Text(_showAll ? 'Show fewer' : 'Show all ${needs.length}'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role, required this.counts});

  final CoverageRole role;
  final Map<CoverageState, int> counts;

  @override
  Widget build(BuildContext context) {
    final parts = [
      for (final s in CoverageState.values)
        if ((counts[s] ?? 0) > 0) '${s.icon} ${counts[s]} ${s.label.toLowerCase()}',
    ];
    final text = '${role.label}: ${parts.join(' · ')}';
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Chip(
        key: Key('coverage-chip-${role.name}'),
        label: Text(text),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// One objective's missing pieces with the smallest useful actions: make a
/// private version, or ask for it on the Wanted Board.
class NeedCard extends StatelessWidget {
  const NeedCard({super.key, required this.need, required this.targetVersionId});

  final CoverageNeed need;
  final String targetVersionId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final code = need.row.code;
    return Card(
      key: Key('need-card-${need.row.objectiveId}'),
      elevation: 0,
      // The primary colour is tuned for 4.5:1 on surfaceContainerLow; a
      // darker fill made these buttons 3.9:1 (accessibility review P3.3).
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(code == null ? need.row.title : '$code ${need.row.title}',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            Text('${CoverageState.gap.icon} Not available yet: ${need.missingLabel}',
                style: theme.textTheme.bodySmall),
            Wrap(
              spacing: DesignTokens.space2,
              children: [
                TextButton.icon(
                  key: Key('need-make-own-${need.row.objectiveId}'),
                  onPressed: () => openMakeMyOwnVersion(context,
                      need: need, targetVersionId: targetVersionId),
                  icon: const Icon(Icons.edit_note, size: 18),
                  label: const Text('Make my own version'),
                ),
                TextButton.icon(
                  key: Key('need-ask-${need.row.objectiveId}'),
                  onPressed: () => GoRouter.of(context).push('/community/wanted'),
                  icon: const Icon(Icons.campaign_outlined, size: 18),
                  label: const Text('Ask for it'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

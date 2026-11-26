import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/companion/learner_resource.dart';
import 'package:learning_pwa/models/companion/resource_catalog.dart';
import 'package:learning_pwa/models/governance/site_feature_keys.dart';
import 'package:learning_pwa/providers/learner_resource_provider.dart';
import 'package:learning_pwa/providers/learning_support_controller_provider.dart';
import 'package:learning_pwa/providers/learning_target_provider.dart';
import 'package:learning_pwa/providers/site_feature_provider.dart';
import 'package:learning_pwa/screens/companion/learner_resource_screen.dart';
import 'package:learning_pwa/services/governance/site_feature_service.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// Switch `content.resource_recommendations` (default OFF): "Ways to study
/// this" on a goal (companion plan v1.0 §3.5, EX-5). A client feature; "Use
/// this" saves through the learner-resources server gate.
final resourceRecommendationsEnabledProvider = Provider<bool>((ref) {
  return isSiteFeatureEnabled(
    ref.watch(siteFeatureSnapshotProvider).valueOrNull,
    SiteFeatureKeys.contentResourceRecommendations,
    runtimeReady: SiteFeatureRuntime.snapshotEnabled,
  );
});

/// The reviewed catalog bundled with the app (tool/build_resource_catalog.py).
final resourceCatalogProvider = FutureProvider<ResourceCatalog>((ref) async {
  final raw = await rootBundle.loadString(
    'assets/companion/resource_catalog.json',
  );
  return ResourceCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
});

/// "Ways to study this": reviewed outside resources for a goal, best free
/// route first, each with why it is listed and when it was checked.
class WaysToStudyCard extends ConsumerWidget {
  const WaysToStudyCard({super.key, required this.goal});

  final GoalRef goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(resourceRecommendationsEnabledProvider)) {
      return const SizedBox.shrink();
    }
    final catalog = ref.watch(resourceCatalogProvider).valueOrNull;
    final nodes = ref
        .watch(targetCurriculumNodesProvider(goal.targetVersionId))
        .valueOrNull;
    if (catalog == null || nodes == null) return const SizedBox.shrink();
    final outline = ResourceOutline.fromNodes(nodes);
    final ways = waysToStudy(
      targetSlug: goal.targetSlug,
      outline: outline,
      catalog: catalog,
    );
    if (ways.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final mine =
        ref.watch(learnerResourcesProvider(goal.targetId)).valueOrNull ??
        const <LearnerResource>[];
    final canSave = ref.watch(learnerResourcesEnabledProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.space3),
      child: Card(
        key: const Key('ways_to_study_card'),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Other ways to study this',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: DesignTokens.space1),
              Text(
                'Free routes first. Listed for what they cover, not paid to be here. '
                "LearningApp's own checks still decide your readiness.",
                style: muted,
              ),
              for (final (i, w) in ways.indexed)
                _WayTile(
                  way: w,
                  bestFree: i == 0 && w.free,
                  alreadyAdded: mine.any(
                    (r) => r.url != null && r.url == w.resource.url,
                  ),
                  canSave: canSave,
                  goal: goal,
                  outline: outline,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WayTile extends ConsumerWidget {
  const _WayTile({
    required this.way,
    required this.bestFree,
    required this.alreadyAdded,
    required this.canSave,
    required this.goal,
    required this.outline,
  });

  final WayToStudy way;
  final bool bestFree;
  final bool alreadyAdded;
  final bool canSave;
  final GoalRef goal;
  final ResourceOutline outline;

  Future<void> _use(BuildContext context, WidgetRef ref) async {
    final store = ref.read(learnerResourceStoreProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final r = way.resource;
    final keyByCode = {
      for (final g in outline.groups)
        for (final i in g.items) i.code ?? i.key: i.key,
    };
    // The map's parts, once each in order, with the objectives each covers.
    final parts = <String, Set<String>>{};
    final starts = <String, int?>{};
    for (final e in way.map.coverage.entries) {
      final key = keyByCode[e.key];
      if (key == null) continue;
      for (final s in e.value) {
        (parts[s.label] ??= <String>{}).add(key);
        starts.putIfAbsent(s.label, () => s.startSeconds);
      }
    }
    final ordered = parts.keys.toList()..sort(_naturalCompare);
    try {
      final id = await store.save(
        targetId: goal.targetId,
        title: r.title == r.publisher ? r.title : '${r.title} (${r.publisher})',
        kind: r.kind,
        url: r.url,
        access: r.access,
      );
      if (ordered.isNotEmpty) {
        await store.setSections(id, [
          for (final label in ordered.take(ResourceSection.maxSections))
            ResourceSection(
              title: label,
              objectiveKeys: parts[label]!
                  .take(ResourceSection.maxKeysPerSection)
                  .toSet(),
              startSeconds: starts[label],
            ),
        ]);
      }
      ref.invalidate(learnerResourcesProvider(goal.targetId));
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => LearnerResourceScreen(goal: goal, resourceId: id),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't add it. Check your connection and try again.",
          ),
        ),
      );
    }
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    var ok = false;
    try {
      ok = await ref.read(externalLinkLauncherProvider)(
        Uri.parse(way.resource.url!),
      );
    } catch (_) {}
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Couldn't open the link.")));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final r = way.resource;
    final reviewed = r.reviewerKind == 'human'
        ? 'reviewed by a person'
        : 'reviewed by AI';
    return Padding(
      key: Key('way_${r.id}'),
      padding: const EdgeInsets.only(top: DesignTokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bestFree)
            Text(
              'Best free route',
              key: const Key('way_best_free'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          Text(
            '${r.title} · ${r.publisher}',
            style: theme.textTheme.titleSmall,
          ),
          Text(
            way.reasons.join(' · '),
            key: Key('way_reasons_${r.id}'),
            style: theme.textTheme.bodyMedium,
          ),
          Text(
            'Checked ${r.checkedOn}, $reviewed. Not affiliated with ${r.publisher}.',
            key: Key('way_checked_${r.id}'),
            style: muted,
          ),
          Wrap(
            spacing: DesignTokens.space2,
            children: [
              if (r.url != null)
                TextButton.icon(
                  key: Key('way_open_${r.id}'),
                  onPressed: () => _open(context, ref),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open (leaves LearningApp)'),
                ),
              if (alreadyAdded)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: DesignTokens.space2,
                  ),
                  child: Text(
                    'In your list',
                    key: Key('way_added_${r.id}'),
                    style: muted,
                  ),
                )
              else if (canSave)
                OutlinedButton.icon(
                  key: Key('way_use_${r.id}'),
                  onPressed: () => _use(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Use this'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "1.2 x" before "1.10 y": compares the leading section numbers as numbers.
int _naturalCompare(String a, String b) {
  List<int> nums(String s) => [
    for (final m
        in RegExp(r'^(\d+(?:\.\d+)*)').firstMatch(s)?.group(1)?.split('.') ??
            const <String>[])
      int.parse(m),
  ];
  final na = nums(a), nb = nums(b);
  for (var i = 0; i < na.length && i < nb.length; i++) {
    if (na[i] != nb[i]) return na[i].compareTo(nb[i]);
  }
  if (na.length != nb.length) return na.length.compareTo(nb.length);
  return a.compareTo(b);
}

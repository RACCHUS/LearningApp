import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/learning_strategy_provider.dart';
import '../../providers/site_feature_provider.dart';

/// Read-only entry control that launches `/overview/:targetId` without creating
/// or switching a [LearningContext] (`TEL-01A`, `TEL-03`).
class QuickOverviewEntry extends ConsumerWidget {
  final String targetId;
  final String? targetSlug;
  final bool compact;

  const QuickOverviewEntry({
    super.key,
    required this.targetId,
    this.targetSlug,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(telFeatureFlagsProvider);
    final experimental = isSiteFeatureExperimental(
      ref.watch(siteFeatureSnapshotProvider).valueOrNull,
      'tel.overview',
    );
    final planner = ref.watch(overviewPlannerProvider);

    final isEnabled =
        flags.isOverviewEnabledForTarget(targetId) ||
        (targetSlug != null && flags.isOverviewEnabledForTarget(targetSlug));
    if (!isEnabled) {
      return const SizedBox.shrink();
    }

    final outline =
        planner.findOutlineForTarget(targetId) ??
        planner.findOutlineForTarget(targetSlug);
    if (outline == null) {
      return const SizedBox.shrink();
    }

    final routeParam = targetSlug?.isNotEmpty == true ? targetSlug! : targetId;

    if (compact) {
      return Semantics(
        button: true,
        label: 'Quick overview for ${outline.title}',
        child: TextButton.icon(
          key: Key('quick-overview-entry-$targetId'),
          onPressed: () => context.push('/overview/$routeParam'),
          icon: const Icon(Icons.explore_outlined, size: 18),
          label: Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('Quick overview'),
            if (experimental)
              const Text(
                'Experimental',
                key: Key('overview-experimental-disclosure'),
                style: TextStyle(fontSize: 11),
              ),
          ],
        ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: 'Quick overview for ${outline.title}: get oriented in minutes',
      child: OutlinedButton.icon(
        key: Key('quick-overview-entry-$targetId'),
        onPressed: () => context.push('/overview/$routeParam'),
        icon: const Icon(Icons.explore_outlined),
        label: Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('Quick overview'),
            if (experimental)
              const Text(
                'Experimental',
                key: Key('overview-experimental-disclosure'),
                style: TextStyle(fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}

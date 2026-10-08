import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/learning_context.dart';
import '../../providers/learning_context_provider.dart';
import '../../providers/learning_target_provider.dart';
import '../../providers/version_governance_provider.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/governance/target_version_migration_dialog.dart';
import '../../widgets/targets/target_readiness_card.dart';
import '../../widgets/targets/diagnostic_launch_banner.dart';
import '../../widgets/taxonomy/career_crosswalk_sheet.dart';
import '../governance/version_staging_dashboard_screen.dart';

class TargetDetailScreen extends ConsumerWidget {
  final String targetId;

  const TargetDetailScreen({super.key, required this.targetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetAsync = ref.watch(targetDetailProvider(targetId));
    final versionAsync = ref.watch(targetVersionProvider(targetId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Target Details'),
      ),
      body: targetAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Failed to load target: $err'),
        ),
        data: (target) {
          if (target == null) {
            return const Center(child: Text('Target not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(DesignTokens.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header badge row
                Row(
                  children: [
                    if (target.emoji != null) ...[
                      Text(target.emoji!, style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: DesignTokens.space3),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DesignTokens.space2,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              target.targetType.displayName,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: DesignTokens.space1),
                          Text(
                            target.title,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DesignTokens.space3),

                // Subtitle metadata
                if (target.providerName != null || target.jurisdiction != null) ...[
                  Row(
                    children: [
                      if (target.providerName != null) ...[
                        Icon(Icons.business, size: 16, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          target.providerName!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: DesignTokens.space3),
                      ],
                      if (target.jurisdiction != null) ...[
                        Icon(Icons.place, size: 16, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          target.jurisdiction!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: DesignTokens.space4),
                ],

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('target-start-learning-button'),
                        onPressed: () async {
                          final version = versionAsync.valueOrNull;
                          final userId = ref.read(learnerIdProvider);

                          // Switch or create active LearningContext
                          await ref.read(learningContextsProvider.notifier).createOrSwitch(
                                userId: userId,
                                label: target.title,
                                rootType: ContextRootType.target,
                                rootId: target.id,
                                emoji: target.emoji,
                                targetVersionId: version?.id,
                              );

                          if (context.mounted) {
                            context.go('/learn');
                          }
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Learning'),
                      ),
                    ),
                    const SizedBox(width: DesignTokens.space3),
                    OutlinedButton.icon(
                      key: const Key('target-view-outline-button'),
                      onPressed: () {
                        context.push('/target/${target.id}/outline');
                      },
                      icon: const Icon(Icons.list_alt),
                      label: const Text('Outline'),
                    ),
                  ],
                ),
                const SizedBox(height: DesignTokens.space5),
                const Divider(),
                const SizedBox(height: DesignTokens.space4),

                // Description
                if (target.description != null) ...[
                  Text(
                    'About this Target',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space2),
                  Text(
                    target.description!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space5),
                ],

                // Target Version info
                versionAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => const SizedBox.shrink(),
                  data: (ver) {
                    if (ver == null) return const SizedBox.shrink();

                    final activeCtx = ref.watch(activeLearningContextProvider);
                    final isContextActive = activeCtx != null &&
                        activeCtx.rootType == ContextRootType.target &&
                        activeCtx.rootId == target.id;
                    final updateInfo = isContextActive
                        ? ref.watch(contextVersionUpdateProvider(activeCtx.id)).valueOrNull
                        : null;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(DesignTokens.space3),
                            child: Row(
                              children: [
                                const Icon(Icons.verified, color: Colors.green),
                                const SizedBox(width: DesignTokens.space3),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Curriculum Version ${ver.versionCode}',
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (ver.title != null)
                                        Text(
                                          ver.title!,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (updateInfo != null && updateInfo.needsUpgrade) ...[
                          const SizedBox(height: DesignTokens.space3),
                          Card(
                            elevation: 0,
                            color: theme.colorScheme.primary.withValues(alpha: 0.08),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: theme.colorScheme.primary.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.upgrade, color: theme.colorScheme.primary),
                                      const SizedBox(width: 8),
                                      Text(
                                        'New Blueprint Edition Available',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    updateInfo.upgradeReason,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton.tonalIcon(
                                    key: const Key('target-upgrade-version-button'),
                                    onPressed: () {
                                      TargetVersionMigrationDialog.show(
                                        context,
                                        updateInfo: updateInfo,
                                      );
                                    },
                                    icon: const Icon(Icons.auto_awesome),
                                    label: Text(
                                      'Upgrade to ${updateInfo.latestVersionCode ?? "New Edition"}',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: DesignTokens.space4),
                        if (ver.isPublished) ...[
                          DiagnosticLaunchBanner(
                            targetId: target.id,
                            targetVersionId: ver.id,
                          ),
                          const SizedBox(height: DesignTokens.space3),
                        ],
                        TargetReadinessCard(targetVersionId: ver.id),
                        const SizedBox(height: DesignTokens.space3),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            key: const Key('target-career-crosswalk-button'),
                            onPressed: () {
                              CareerCrosswalkSheet.show(
                                context,
                                targetId: target.id,
                                targetTitle: target.title,
                              );
                            },
                            icon: const Icon(Icons.work_outline),
                            label: const Text('Career & Labor Market Pathways'),
                          ),
                        ),
                        const SizedBox(height: DesignTokens.space3),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            key: const Key('target-version-governance-button'),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => VersionStagingDashboardScreen(
                                    initialVersionId: ver.id,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.verified_outlined),
                            label: const Text('QA Readiness & Version Governance'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

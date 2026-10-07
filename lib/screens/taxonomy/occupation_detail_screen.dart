import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/learning_context.dart';
import '../../models/taxonomy/taxonomy.dart';
import '../../providers/learning_context_provider.dart';
import '../../providers/taxonomy_provider.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/taxonomy/cip_detail_sheet.dart';

/// Comprehensive Occupation Detail View
/// Displays BLS SOC and O*NET labor market classifications, Job Zone requirements,
/// crosswalked educational programs (CIP), and connected Learning Targets.
class OccupationDetailScreen extends ConsumerWidget {
  final String occupationCode;

  const OccupationDetailScreen({
    super.key,
    required this.occupationCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final occAsync = ref.watch(occupationByCodeProvider(occupationCode));
    final cipCrosswalksAsync =
        ref.watch(cipCrosswalksForOccupationProvider(occupationCode));
    final targetsAsync =
        ref.watch(targetsForOccupationProvider(occupationCode));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Occupation Details'),
      ),
      body: occAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Failed to load occupation: $err',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ),
        data: (occ) {
          if (occ == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.work_off_outlined,
                      size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text('Occupation $occupationCode not found.'),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(DesignTokens.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusMd),
                      ),
                      child: Icon(
                        Icons.work_outline,
                        color: theme.colorScheme.onPrimaryContainer,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: DesignTokens.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  occ.code,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              if (occ.isOnetExtension) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'O*NET 31.0',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber,
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              Text(
                                occ.level.replaceAll('_', ' ').toUpperCase(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            occ.title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DesignTokens.space4),

                // Job Zone Card
                _buildJobZoneCard(theme, occ.jobZone),
                const SizedBox(height: DesignTokens.space4),

                // Description
                if (occ.description != null && occ.description!.isNotEmpty) ...[
                  Text(
                    'Official Description',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space2),
                  Text(
                    occ.description!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space4),
                ],

                const Divider(),
                const SizedBox(height: DesignTokens.space3),

                // Aligned Learning Targets Section
                Text(
                  'Aligned Learning Targets in App',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Curricula and certifications preparing for this career pathway:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: DesignTokens.space3),

                targetsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, _) => Text('Error loading targets: $e'),
                  data: (targets) {
                    if (targets.isEmpty) {
                      return Card(
                        elevation: 0,
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.35),
                        child: Padding(
                          padding: const EdgeInsets.all(DesignTokens.space3),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 18, color: theme.disabledColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No curriculum target currently linked to this occupation.',
                                  style: TextStyle(color: theme.disabledColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: targets.map((target) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.25),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(DesignTokens.space3),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (target.emoji != null) ...[
                                      Text(
                                        target.emoji!,
                                        style: const TextStyle(fontSize: 22),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Expanded(
                                      child: Text(
                                        target.targetTitle,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: target.isPrimary
                                            ? Colors.green
                                                .withValues(alpha: 0.12)
                                            : theme.colorScheme
                                                .surfaceContainerHighest,
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        target.isPrimary
                                            ? 'Primary Alignment'
                                            : 'Supporting Alignment',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: target.isPrimary
                                              ? Colors.green
                                              : theme
                                                  .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.tonalIcon(
                                        onPressed: () async {
                                          final userId =
                                              ref.read(learnerIdProvider);
                                          await ref
                                              .read(learningContextsProvider
                                                  .notifier)
                                              .createOrSwitch(
                                                userId: userId,
                                                label: target.targetTitle,
                                                rootType:
                                                    ContextRootType.target,
                                                rootId: target.targetId,
                                                emoji: target.emoji,
                                              );
                                          if (context.mounted) {
                                            context.go('/learn');
                                          }
                                        },
                                        icon: const Icon(Icons.play_arrow,
                                            size: 16),
                                        label: const Text('Start Learning'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        context.push(
                                            '/target/${target.targetId}/outline');
                                      },
                                      icon: const Icon(Icons.list_alt,
                                          size: 16),
                                      label: const Text('Outline'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: DesignTokens.space4),

                const Divider(),
                const SizedBox(height: DesignTokens.space3),

                // Crosswalked CIP Educational Programs
                Text(
                  'Crosswalked Educational Programs (NCES CIP 2020)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Official instructional disciplines leading to this occupation:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: DesignTokens.space3),

                cipCrosswalksAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, _) => Text('Error loading CIP crosswalks: $e'),
                  data: (cipPrograms) {
                    if (cipPrograms.isEmpty) {
                      return Card(
                        elevation: 0,
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.35),
                        child: Padding(
                          padding: const EdgeInsets.all(DesignTokens.space3),
                          child: Row(
                            children: [
                              Icon(Icons.school_outlined,
                                  size: 18, color: theme.disabledColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No direct CIP educational program crosswalk recorded.',
                                  style: TextStyle(color: theme.disabledColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: cipPrograms.map((cip) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: theme.dividerColor.withValues(alpha: 0.5),
                            ),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'CIP ${cip.code}',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      theme.colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                            title: Text(
                              cip.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: cip.definition != null
                                ? Text(
                                    cip.definition!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  )
                                : null,
                            trailing: const Icon(Icons.info_outline, size: 18),
                            onTap: () {
                              final cipNode = ExternalClassificationNode(
                                id: 'cip-${cip.code}',
                                sourceReleaseId: 'rel-cip-2020',
                                system: 'cip',
                                version: '2020',
                                code: cip.code,
                                levelCode: 'program',
                                title: cip.title,
                                definition: cip.definition,
                              );
                              CipDetailSheet.show(context, cipNode: cipNode);
                            },
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: DesignTokens.space5),

                // Pedagogical safeguards notice
                _buildPedagogicalSafeguardsNotice(theme),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildJobZoneCard(ThemeData theme, int? jobZone) {
    String title;
    String subtitle;
    String education;
    Color color;

    switch (jobZone) {
      case 1:
        title = 'Job Zone 1: Little or No Preparation Needed';
        subtitle = 'Little or no previous work-related skill, knowledge, or experience is needed.';
        education = 'Most require high school diploma or GED.';
        color = Colors.amber.shade700;
        break;
      case 2:
        title = 'Job Zone 2: Some Preparation Needed';
        subtitle = 'Some previous work-related skill, knowledge, or experience is usually needed.';
        education = 'High school diploma and vocational certificates.';
        color = Colors.blue.shade700;
        break;
      case 3:
        title = 'Job Zone 3: Medium Preparation Needed';
        subtitle = 'Previous work-related skill, knowledge, or experience is required for these occupations.';
        education = 'Vocational training, on-the-job experience, or an associate\'s degree.';
        color = Colors.indigo.shade600;
        break;
      case 4:
        title = 'Job Zone 4: Considerable Preparation Needed';
        subtitle = 'A considerable amount of work-related skill, knowledge, or experience is needed.';
        education = 'Most occupations require a four-year bachelor\'s degree (B.S./B.A.).';
        color = Colors.teal.shade700;
        break;
      case 5:
        title = 'Job Zone 5: Extensive Preparation Needed';
        subtitle = 'Extensive skill, knowledge, and experience (often 5+ years) are required.';
        education = 'Graduate school (Master\'s degree, Ph.D., M.D., or J.D.).';
        color = Colors.purple.shade700;
        break;
      default:
        title = 'Standard Preparation Level';
        subtitle = 'Standard workforce preparation required.';
        education = 'Standard educational credentials.';
        color = theme.colorScheme.primary;
    }

    return Container(
      padding: const EdgeInsets.all(DesignTokens.space3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.stars, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.school, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Typical Education: $education',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPedagogicalSafeguardsNotice(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Crosswalk alignments derive from published federal qualitative matrices (NCES/BLS). They reflect educational-to-labor associations and do not represent individual hiring guarantees.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

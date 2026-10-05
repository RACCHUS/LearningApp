import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/governance/governance.dart';
import '../../providers/learning_context_provider.dart';
import '../../providers/version_governance_provider.dart';

/// Interactive modal dialog allowing learners to review concept transfer retention
/// and safely upgrade their active LearningContext to a newer TargetVersion.
class TargetVersionMigrationDialog extends ConsumerStatefulWidget {
  final TargetVersionUpdateInfo updateInfo;

  const TargetVersionMigrationDialog({
    super.key,
    required this.updateInfo,
  });

  static Future<bool?> show(
    BuildContext context, {
    required TargetVersionUpdateInfo updateInfo,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TargetVersionMigrationDialog(updateInfo: updateInfo),
    );
  }

  @override
  ConsumerState<TargetVersionMigrationDialog> createState() =>
      _TargetVersionMigrationDialogState();
}

class _TargetVersionMigrationDialogState
    extends ConsumerState<TargetVersionMigrationDialog> {
  bool _isMigrating = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = widget.updateInfo;

    final evalParams = MigrationEvaluationParams(
      userId: info.userId,
      fromVersionId: info.currentVersionId,
      toVersionId: info.latestVersionId ?? info.currentVersionId,
    );

    final evalAsync = ref.watch(migrationEvaluationProvider(evalParams));

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.upgrade_outlined,
                            color: theme.colorScheme.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Blueprint Version Upgrade',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                info.targetTitle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Version Transition Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildVersionPill(theme, info.currentVersionCode, isCurrent: true),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Icon(
                              Icons.arrow_forward,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          _buildVersionPill(theme, info.latestVersionCode ?? 'New Edition', isCurrent: false),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Explanatory Banner
                    Text(
                      info.upgradeReason,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),

                    const SizedBox(height: 20),

                    // Transfer Evaluation
                    evalAsync.when(
                      data: (eval) => _buildEvaluationCard(theme, eval),
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (err, _) => Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Could not load transfer preview: $err',
                          style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Safeguards Notice
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Progress Preservation Guarantee: Your historical spaced repetition flashcards, question results, and learning history are never discarded (Invariant 6).',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Actions
                    FilledButton.icon(
                      key: const Key('confirm-migration-button'),
                      onPressed: _isMigrating ? null : _handleMigration,
                      icon: _isMigrating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(_isMigrating ? 'Migrating Blueprint...' : 'Upgrade to New Blueprint'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextButton(
                      onPressed: _isMigrating ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Keep Current Edition for Now'),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVersionPill(ThemeData theme, String code, {required bool isCurrent}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isCurrent
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        code,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: isCurrent ? theme.textTheme.bodyMedium?.color : theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildEvaluationCard(ThemeData theme, TargetVersionMigrationEvaluation eval) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mastery Carry-Forward Projection',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: eval.isHighRetention
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${eval.transferRetentionPct.toStringAsFixed(1)}% Retained',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: eval.isHighRetention ? Colors.green : Colors.orange,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (eval.transferRetentionPct / 100.0).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: eval.isHighRetention ? Colors.green : Colors.orange,
            ),
          ),

          const SizedBox(height: 14),

          // Chips breakdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricChip(
                theme,
                count: eval.retainedConceptsCount,
                label: 'Retained Concepts',
                color: Colors.green,
              ),
              _buildMetricChip(
                theme,
                count: eval.newConceptsCount,
                label: 'New Topics',
                color: theme.colorScheme.primary,
              ),
              _buildMetricChip(
                theme,
                count: eval.removedConceptsCount,
                label: 'Retired Topics',
                color: Colors.grey,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(
    ThemeData theme, {
    required int count,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Future<void> _handleMigration() async {
    final info = widget.updateInfo;
    final toVersionId = info.latestVersionId;
    if (toVersionId == null) return;

    setState(() {
      _isMigrating = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(versionGovernanceServiceProvider);
      await service.migrateUserContext(
        userId: info.userId,
        contextId: info.contextId,
        toVersionId: toVersionId,
      );

      // Invalidate context provider so UI refreshes with the upgraded target version
      ref.invalidate(activeLearningContextProvider);
      ref.invalidate(contextVersionUpdateProvider(info.contextId));

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully upgraded to ${info.latestVersionCode ?? "new blueprint"}!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isMigrating = false;
          _errorMessage = 'Migration failed: $e';
        });
      }
    }
  }
}

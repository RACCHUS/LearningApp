import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/governance/governance.dart';
import '../../providers/version_governance_provider.dart';

/// Staging dashboard and QA readiness audit screen for draft and review_ready target versions.
class VersionStagingDashboardScreen extends ConsumerStatefulWidget {
  final String? initialVersionId;

  const VersionStagingDashboardScreen({
    super.key,
    this.initialVersionId,
  });

  @override
  ConsumerState<VersionStagingDashboardScreen> createState() =>
      _VersionStagingDashboardScreenState();
}

class _VersionStagingDashboardScreenState
    extends ConsumerState<VersionStagingDashboardScreen> {
  String? _selectedVersionId;
  bool _isProcessing = false;
  String? _statusFeedback;

  @override
  void initState() {
    super.initState();
    _selectedVersionId = widget.initialVersionId;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stagedListAsync = ref.watch(stagedTargetVersionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Version Governance & QA'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(stagedTargetVersionsProvider);
              if (_selectedVersionId != null) {
                ref.invalidate(targetVersionAuditProvider(_selectedVersionId!));
              }
            },
          ),
        ],
      ),
      body: stagedListAsync.when(
        data: (stagedVersions) {
          if (stagedVersions.isEmpty && _selectedVersionId == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 48, color: theme.disabledColor),
                    const SizedBox(height: 12),
                    Text(
                      'No versions currently in draft or review staging.',
                      style: theme.textTheme.titleSmall?.copyWith(color: theme.disabledColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'All official target blueprints are actively published.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.disabledColor),
                    ),
                  ],
                ),
              ),
            );
          }

          final activeId = _selectedVersionId ??
              (stagedVersions.isNotEmpty ? stagedVersions.first['id'] as String : null);

          return Row(
            children: [
              // Version Selector Sidebar (if multiple)
              if (stagedVersions.length > 1) ...[
                SizedBox(
                  width: 260,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: stagedVersions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = stagedVersions[index];
                      final id = item['id'] as String;
                      final isSelected = id == activeId;
                      final targetTitle = (item['learning_targets'] is Map)
                          ? (item['learning_targets']['title'] as String? ?? 'Target')
                          : 'Target';

                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.dividerColor.withValues(alpha: 0.4),
                          ),
                        ),
                        title: Text(
                          item['version_code'] as String? ?? id,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          targetTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: _buildStatusChip(theme, item['status'] as String? ?? 'draft'),
                        onTap: () {
                          setState(() {
                            _selectedVersionId = id;
                            _statusFeedback = null;
                          });
                        },
                      );
                    },
                  ),
                ),
                const VerticalDivider(width: 1),
              ],

              // Audit Report View
              Expanded(
                child: activeId == null
                    ? const Center(child: Text('Select a version to inspect.'))
                    : _buildAuditReportView(theme, activeId),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading staged versions: $err')),
      ),
    );
  }

  Widget _buildAuditReportView(ThemeData theme, String versionId) {
    final auditAsync = ref.watch(targetVersionAuditProvider(versionId));

    return auditAsync.when(
      data: (report) => _buildAuditDetails(theme, report),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Audit failed: $err')),
    );
  }

  Widget _buildAuditDetails(ThemeData theme, TargetVersionAuditReport report) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Title Banner
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.targetTitle,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Edition: ${report.versionCode}',
                        style: TextStyle(fontFamily: 'monospace', color: theme.colorScheme.primary),
                      ),
                      const SizedBox(width: 12),
                      _buildStatusChip(theme, report.status),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        if (_statusFeedback != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _statusFeedback!,
              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Domain Balance & Weight Validation Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: report.isDomainWeightBalanced
                  ? Colors.green.withValues(alpha: 0.5)
                  : theme.colorScheme.error,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  report.isDomainWeightBalanced ? Icons.check_circle : Icons.error_outline,
                  color: report.isDomainWeightBalanced ? Colors.green : theme.colorScheme.error,
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.isDomainWeightBalanced
                            ? 'Domain Weights Balanced (100.0%)'
                            : 'Domain Weights Unbalanced (${report.domainWeightSum}%)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${report.domainCount} root domain(s) comprising ${report.leafObjectiveCount} leaf objective(s).',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Metrics Grid
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                theme,
                title: 'Lessons & Blocks',
                value: '${report.lessonCount} / ${report.lessonBlockCount}',
                subtitle: 'Lessons / Blocks',
                icon: Icons.menu_book,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                theme,
                title: 'Assessments',
                value: '${report.assessmentItemCount}',
                subtitle: '${report.stimulusCount} shared stimuli',
                icon: Icons.quiz_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                theme,
                title: 'Concept Coverage',
                value: '${report.conceptAssessmentCoveragePct.toStringAsFixed(0)}%',
                subtitle: '${report.conceptCoverageCount} concepts',
                icon: Icons.hub_outlined,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Blockers & Warnings
        if (report.blockingIssues.isNotEmpty) ...[
          Text(
            'Blocking Issues (${report.blockingIssues.length})',
            style: TextStyle(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ...report.blockingIssues.map((issue) => _buildIssueRow(theme, issue, isError: true)),
          const SizedBox(height: 16),
        ],

        if (report.warnings.isNotEmpty) ...[
          Text(
            'Pedagogical QA Warnings (${report.warnings.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ...report.warnings.map((warn) => _buildIssueRow(theme, warn, isError: false)),
          const SizedBox(height: 16),
        ],

        const SizedBox(height: 20),

        // Action Toolbar
        _buildActionToolbar(theme, report),
      ],
    );
  }

  Widget _buildMetricTile(
    ThemeData theme, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(title, style: theme.textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueRow(ThemeData theme, String text, {required bool isError}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.cancel : Icons.warning_amber_rounded,
            size: 18,
            color: isError ? theme.colorScheme.error : Colors.amber.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13, height: 1.3)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(ThemeData theme, String status) {
    Color color;
    switch (status) {
      case 'published':
        color = Colors.green;
        break;
      case 'review_ready':
        color = Colors.blue;
        break;
      case 'retired':
        color = Colors.grey;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: color,
        ),
      ),
    );
  }

  Widget _buildActionToolbar(ThemeData theme, TargetVersionAuditReport report) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (report.status == 'draft') ...[
          FilledButton.icon(
            key: const Key('stage-review-button'),
            onPressed: (_isProcessing || !report.canStageReview)
                ? null
                : () => _handleStageReview(report),
            icon: const Icon(Icons.rate_review_outlined),
            label: const Text('Advance to Review Ready'),
          ),
        ],
        if (report.status == 'review_ready') ...[
          FilledButton.icon(
            key: const Key('publish-version-button'),
            onPressed: (_isProcessing || !report.canPublish)
                ? null
                : () => _handlePublish(report),
            icon: const Icon(Icons.publish_outlined),
            label: const Text('Promote to Published'),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
        if (report.status == 'published') ...[
          OutlinedButton.icon(
            key: const Key('retire-version-button'),
            onPressed: _isProcessing ? null : () => _handleRetire(report),
            icon: const Icon(Icons.archive_outlined),
            label: const Text('Retire Blueprint Edition'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ],
    );
  }

  Future<void> _handleStageReview(TargetVersionAuditReport report) async {
    setState(() => _isProcessing = true);
    try {
      final service = ref.read(versionGovernanceServiceProvider);
      await service.stageReview(report.targetVersionId);
      ref.invalidate(targetVersionAuditProvider(report.targetVersionId));
      ref.invalidate(stagedTargetVersionsProvider);
      setState(() {
        _isProcessing = false;
        _statusFeedback = 'Version successfully advanced to review_ready.';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusFeedback = 'Action failed: $e';
      });
    }
  }

  Future<void> _handlePublish(TargetVersionAuditReport report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publish Blueprint Edition'),
        content: Text(
          'Promoting "${report.versionCode}" to published enforces permanent database immutability. Prior editions will be retired.\n\nProceed with publication?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Publish & Retire Previous'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      final service = ref.read(versionGovernanceServiceProvider);
      await service.publishVersion(report.targetVersionId, retirePrevious: true);
      ref.invalidate(targetVersionAuditProvider(report.targetVersionId));
      ref.invalidate(stagedTargetVersionsProvider);
      setState(() {
        _isProcessing = false;
        _statusFeedback = 'Version promoted to published and prior edition retired.';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusFeedback = 'Publish failed: $e';
      });
    }
  }

  Future<void> _handleRetire(TargetVersionAuditReport report) async {
    setState(() => _isProcessing = true);
    try {
      final service = ref.read(versionGovernanceServiceProvider);
      await service.retireVersion(report.targetVersionId);
      ref.invalidate(targetVersionAuditProvider(report.targetVersionId));
      ref.invalidate(stagedTargetVersionsProvider);
      setState(() {
        _isProcessing = false;
        _statusFeedback = 'Version marked retired.';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusFeedback = 'Retire failed: $e';
      });
    }
  }
}

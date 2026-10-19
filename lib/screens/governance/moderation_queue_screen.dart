import 'package:flutter/material.dart';
import 'package:learning_pwa/models/governance/moderation_report.dart';
import 'package:learning_pwa/services/governance/moderation_service.dart';
import 'package:learning_pwa/widgets/error_retry_view.dart';

class ModerationQueueScreen extends StatefulWidget {
  final ModerationService? moderationService;

  const ModerationQueueScreen({super.key, this.moderationService});

  @override
  State<ModerationQueueScreen> createState() => _ModerationQueueScreenState();
}

class _ModerationQueueScreenState extends State<ModerationQueueScreen> {
  late final ModerationService _service;

  bool _isCheckingAuth = true;
  bool _isModerator = false;
  bool _isLoadingReports = false;
  Object? _error;

  ReportStatus? _selectedStatus;
  List<ModerationReport> _reports = const [];

  @override
  void initState() {
    super.initState();
    _service = widget.moderationService ?? ModerationService();
    _checkAccessAndLoad();
  }

  Future<void> _checkAccessAndLoad() async {
    setState(() {
      _isCheckingAuth = true;
      _error = null;
    });

    try {
      final isMod = await _service.isModerator();
      if (!mounted) return;

      setState(() {
        _isModerator = isMod;
        _isCheckingAuth = false;
      });

      if (isMod) {
        await _loadReports();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isCheckingAuth = false;
      });
    }
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoadingReports = true;
      _error = null;
    });

    try {
      final reports = await _service.fetchReports(statusFilter: _selectedStatus);
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _isLoadingReports = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isLoadingReports = false;
      });
    }
  }

  Future<void> _showActionDialog(ModerationReport report) async {
    ModerationActionType selectedAction = report.reason == ReportReason.minorSafety
        ? ModerationActionType.delete
        : ModerationActionType.hide;

    final reasonController = TextEditingController(
      text: 'Violates platform safety policy (${report.reason.displayName})',
    );
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;

            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.gavel, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text('Take Moderation Action'),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Report Target: ${report.targetType.displayName} (${report.targetId})',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Reported Reason: ${report.reason.displayName}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Select Action (Administrative Decision)',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<ModerationActionType>(
                          value: selectedAction,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          items: ModerationActionType.values.map((act) {
                            return DropdownMenuItem(
                              value: act,
                              child: Text(act.displayName),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedAction = val);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Public / Standard Reason *',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: reasonController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Required rationale for this decision',
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Reason is required for audit integrity';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Internal Audit Notes (Optional)',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: notesController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Internal details or evidence references',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Option A Governance: Moderation actions are recorded as administrative decisions in the compliance audit trail. Automated cascading content deletion will activate when public UGC is enabled.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSubmitting = true);

                          try {
                            await _service.applyModerationAction(
                              reportId: report.id,
                              action: selectedAction,
                              reason: reasonController.text.trim(),
                              notes: notesController.text.trim().isEmpty
                                  ? null
                                  : notesController.text.trim(),
                            );

                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();

                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Action applied: ${selectedAction.displayName}',
                                ),
                                backgroundColor: Colors.green.shade800,
                              ),
                            );
                            await _loadReports();
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to apply action: $e'),
                                backgroundColor: colorScheme.error,
                              ),
                            );
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(isSubmitting ? 'Applying...' : 'Apply Action'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChips(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            label: const Text('All Reports'),
            selected: _selectedStatus == null,
            onSelected: (_) {
              setState(() => _selectedStatus = null);
              _loadReports();
            },
          ),
          const SizedBox(width: 8),
          ...ReportStatus.values.map((status) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(status.displayName),
                selected: _selectedStatus == status,
                onSelected: (_) {
                  setState(() => _selectedStatus = status);
                  _loadReports();
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildReportCard(ModerationReport report, ThemeData theme) {
    final colorScheme = theme.colorScheme;

    final isSevere = report.reason == ReportReason.minorSafety;

    Color statusColor;
    switch (report.status) {
      case ReportStatus.pending:
        statusColor = Colors.orange;
        break;
      case ReportStatus.underReview:
        statusColor = Colors.blue;
        break;
      case ReportStatus.actioned:
        statusColor = Colors.green;
        break;
      case ReportStatus.dismissed:
        statusColor = Colors.grey;
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSevere
            ? BorderSide(color: colorScheme.error, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _getTargetIcon(report.targetType),
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${report.targetType.displayName} #${report.targetId}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text(
                              report.status.displayName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            backgroundColor: statusColor.withValues(alpha: 0.12),
                            side: BorderSide(
                              color: statusColor.withValues(alpha: 0.3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reported ${report.createdAt.toLocal().toString().split('.').first}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSevere
                    ? colorScheme.errorContainer
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSevere ? Icons.warning : Icons.flag,
                    size: 14,
                    color: isSevere
                        ? colorScheme.onErrorContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Reason: ${report.reason.displayName}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSevere
                          ? colorScheme.onErrorContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (report.description != null &&
                report.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Reporter notes: "${report.description}"',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!report.status.isTerminal)
                  FilledButton.icon(
                    onPressed: () => _showActionDialog(report),
                    icon: const Icon(Icons.gavel, size: 18),
                    label: const Text('Review Action'),
                  )
                else
                  Text(
                    'Status: ${report.status.displayName}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTargetIcon(ModerationTargetType type) {
    switch (type) {
      case ModerationTargetType.course:
        return Icons.school;
      case ModerationTargetType.lesson:
        return Icons.menu_book;
      case ModerationTargetType.studySet:
        return Icons.style;
      case ModerationTargetType.wordList:
        return Icons.spellcheck;
      case ModerationTargetType.curriculum:
        return Icons.account_tree;
      case ModerationTargetType.resource:
        return Icons.folder_shared;
      case ModerationTargetType.question:
        return Icons.help_outline;
      case ModerationTargetType.profile:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trust & Safety Console'),
        actions: [
          if (_isModerator)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Queue',
              onPressed: _loadReports,
            ),
        ],
      ),
      body: _buildBody(theme, colorScheme),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme colorScheme) {
    if (_isCheckingAuth) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ErrorRetryView(
        message: 'Failed to authenticate or load moderation queue',
        error: _error,
        showDetails: true,
        onRetry: _checkAccessAndLoad,
      );
    }

    if (!_isModerator) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, size: 64, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'Access Denied',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You must have the "moderator" or "admin" role to view and process reports in the Trust & Safety Console.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _checkAccessAndLoad,
                icon: const Icon(Icons.refresh),
                label: const Text('Check Access Again'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Governance Notice Banner
        Container(
          width: double.infinity,
          color: colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.policy_outlined,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ECO-00B Governance Mode — Public UGC is currently disabled pending operational review. Actions taken here are logged permanently to the compliance audit trail.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildFilterChips(theme),
        Expanded(
          child: _isLoadingReports
              ? const Center(child: CircularProgressIndicator())
              : _reports.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 48,
                            color: Colors.green.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Queue is empty',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No reports matching the selected filter.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadReports,
                      child: ListView.builder(
                        itemCount: _reports.length,
                        itemBuilder: (context, index) {
                          return _buildReportCard(_reports[index], theme);
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

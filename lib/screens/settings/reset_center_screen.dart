import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/data_snapshot.dart';
import '../../providers/reset_provider.dart';
import '../../widgets/reset_pickers.dart';

/// Screen for managing resets and reverts
class ResetCenterScreen extends ConsumerWidget {
  const ResetCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availableReverts = ref.watch(availableRevertsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Center'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Warning card
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reset & Revert',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                        Text(
                          'Resets mark your progress as unverified. You have 30 days to revert a reset.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Reset options section
          const Text(
            'Reset Options',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          _ResetOptionCard(
            icon: Icons.psychology,
            title: 'Reset a Skill',
            description:
                'Reset all assessment scores for a specific skill back to level 1.',
            onTap: () => _showResetSkillDialog(context, ref),
          ),
          const SizedBox(height: 8),

          _ResetOptionCard(
            icon: Icons.school,
            title: 'Reset a Course',
            description:
                'Reset all progress for a specific course, including lessons and assessments.',
            onTap: () => _showResetCourseDialog(context, ref),
          ),
          const SizedBox(height: 8),

          _ResetOptionCard(
            icon: Icons.work,
            title: 'Reset a Career Path',
            description:
                'Reset all progress for an entire career path, including all courses within it.',
            onTap: () => _showResetCareerPathDialog(context, ref),
          ),
          const SizedBox(height: 8),

          _ResetOptionCard(
            icon: Icons.restart_alt,
            title: 'Reset All Progress',
            description:
                'Start fresh! Reset all your skills, courses, and career paths.',
            color: Colors.red,
            onTap: () => _showResetAllDialog(context, ref),
          ),

          const SizedBox(height: 32),

          // Available reverts section
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Available Reverts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(availableRevertsProvider),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 12),

          availableReverts.when(
            data: (snapshots) {
              if (snapshots.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.history,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'No reverts available',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'When you reset progress, you\'ll be able to revert within 30 days.',
                          style: TextStyle(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: snapshots.map((snapshot) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _RevertCard(snapshot: snapshot),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error loading reverts: $e'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showResetSkillDialog(BuildContext context, WidgetRef ref) async {
    final skillId = await showSkillPicker(context);
    if (skillId == null || !context.mounted) return;

    final confirmed = await _showResetConfirmation(
      context,
      title: 'Reset Skill',
      message: 'All assessment attempts for this skill will be marked as unverified and your level will be reset to 0.',
    );

    if (confirmed == true) {
      await ref.read(resetProvider.notifier).resetSkill(skillId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Skill reset! You can revert within 30 days.')),
        );
        ref.invalidate(availableRevertsProvider);
      }
    }
  }

  Future<void> _showResetCourseDialog(BuildContext context, WidgetRef ref) async {
    final courseId = await showCoursePicker(context);
    if (courseId == null || !context.mounted) return;

    final confirmed = await _showResetConfirmation(
      context,
      title: 'Reset Course',
      message: 'All progress for this course will be reset, including lessons and study time.',
    );

    if (confirmed == true) {
      await ref.read(resetProvider.notifier).resetCourse(courseId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Course reset! You can revert within 30 days.')),
        );
        ref.invalidate(availableRevertsProvider);
      }
    }
  }

  Future<void> _showResetCareerPathDialog(BuildContext context, WidgetRef ref) async {
    final pathId = await showCareerPathPicker(context);
    if (pathId == null || !context.mounted) return;

    final confirmed = await _showResetConfirmation(
      context,
      title: 'Reset Career Path',
      message: 'All progress for this career path and its courses will be reset.',
    );

    if (confirmed == true) {
      await ref.read(resetProvider.notifier).resetCareerPath(pathId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Career path reset! You can revert within 30 days.')),
        );
        ref.invalidate(availableRevertsProvider);
      }
    }
  }

  Future<bool?> _showResetConfirmation(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can revert this action within 30 days.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _showResetAllDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Reset All Progress'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will reset ALL your progress:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• All skill levels and assessment scores'),
            const Text('• All course progress'),
            const Text('• All career path progress'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You will be able to revert this within 30 days.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(resetProvider.notifier).resetAll();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All progress reset! You can revert within 30 days.')),
        );
        ref.invalidate(availableRevertsProvider);
      }
    }
  }
}

class _ResetOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final Color? color;

  const _ResetOptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? Theme.of(context).colorScheme.primary;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: cardColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cardColor,
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cardColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _RevertCard extends ConsumerWidget {
  final UserDataSnapshot snapshot;

  const _RevertCard({required this.snapshot});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getIconForType(snapshot.snapshotType),
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getTitleForType(snapshot.snapshotType),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (snapshot.targetId != null)
                        Text(
                          'ID: ${snapshot.targetId}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: snapshot.daysRemaining <= 7
                        ? Colors.red.shade100
                        : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${snapshot.daysRemaining} days left',
                    style: TextStyle(
                      fontSize: 12,
                      color: snapshot.daysRemaining <= 7
                          ? Colors.red.shade700
                          : Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Reset on ${_formatDate(snapshot.createdAt)}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRevertOptions(context, ref),
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('Revert'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(SnapshotType type) {
    switch (type) {
      case SnapshotType.skillReset:
        return Icons.psychology;
      case SnapshotType.careerReset:
        return Icons.work;
      case SnapshotType.courseReset:
        return Icons.school;
      case SnapshotType.fullReset:
        return Icons.restart_alt;
    }
  }

  String _getTitleForType(SnapshotType type) {
    switch (type) {
      case SnapshotType.skillReset:
        return 'Skill Reset';
      case SnapshotType.careerReset:
        return 'Career Path Reset';
      case SnapshotType.courseReset:
        return 'Course Reset';
      case SnapshotType.fullReset:
        return 'Full Reset';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _showRevertOptions(BuildContext context, WidgetRef ref) async {
    final scope = await showDialog<RevertScope>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Revert Scope'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.undo),
              title: const Text('Revert Single Attempt'),
              subtitle: const Text('Only revert the last assessment attempt'),
              onTap: () => Navigator.of(context).pop(RevertScope.singleAttempt),
            ),
            ListTile(
              leading: const Icon(Icons.replay),
              title: const Text('Revert All Attempts'),
              subtitle: const Text('Revert all attempts since the reset'),
              onTap: () => Navigator.of(context).pop(RevertScope.allAttempts),
            ),
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Full Revert'),
              subtitle: const Text('Restore everything to before the reset'),
              onTap: () => Navigator.of(context).pop(RevertScope.full),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (scope != null && context.mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Revert'),
          content: Text(
            'Are you sure you want to revert? This will restore your previous ${_getScopeDescription(scope)}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Revert'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await ref.read(revertProvider.notifier).revertFromSnapshot(snapshot.id, scope: scope);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Successfully reverted!')),
          );
          ref.invalidate(availableRevertsProvider);
        }
      }
    }
  }

  String _getScopeDescription(RevertScope scope) {
    switch (scope) {
      case RevertScope.singleAttempt:
        return 'attempt';
      case RevertScope.allAttempts:
        return 'attempts';
      case RevertScope.full:
        return 'progress';
    }
  }
}

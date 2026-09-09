import 'package:flutter/material.dart';
import '../models/skill.dart';
import 'skill_badges.dart';

/// Compact skill stat card for dashboard/home screen display.
/// Shows skill name, level, and progress in a minimal footprint.
class SkillStatCard extends StatelessWidget {
  final UserSkillStats skill;
  final VoidCallback? onTap;

  const SkillStatCard({
    super.key,
    required this.skill,
    this.onTap,
  });

  /// Get skill name from joined skill or fallback
  String get _skillName => skill.skill?.name ?? 'Unknown Skill';
  
  /// Calculate progress within current tier (0.0 to 1.0)
  double get _tierProgress {
    final tier = SkillBadgeTier.fromLevel(skill.level);
    return tier.progressInTier(skill.level);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tier = SkillBadgeTier.fromLevel(skill.level);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Skill badge
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      tier.color,
                      tier.color.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    tier.icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Skill info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _skillName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Level ${skill.level}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tier.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${skill.totalAssessments} assessments',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Progress indicator
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: _tierProgress,
                      strokeWidth: 3,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(tier.color),
                    ),
                    Text(
                      '${(_tierProgress * 100).round()}%',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal scrollable list of top skills for dashboard.
class TopSkillsStrip extends StatelessWidget {
  final List<UserSkillStats> skills;
  final int maxDisplay;
  final void Function(UserSkillStats)? onSkillTap;
  final VoidCallback? onViewAll;

  const TopSkillsStrip({
    super.key,
    required this.skills,
    this.maxDisplay = 5,
    this.onSkillTap,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displaySkills = skills.take(maxDisplay).toList();

    if (displaySkills.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.psychology_outlined,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Start learning to build your skills!',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Skills',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (onViewAll != null && skills.length > maxDisplay)
                TextButton(
                  onPressed: onViewAll,
                  child: const Text('View All'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: displaySkills.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final skill = displaySkills[index];
              return _CompactSkillChip(
                skill: skill,
                onTap: onSkillTap != null ? () => onSkillTap!(skill) : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CompactSkillChip extends StatelessWidget {
  final UserSkillStats skill;
  final VoidCallback? onTap;

  const _CompactSkillChip({
    required this.skill,
    this.onTap,
  });

  String get _skillName => skill.skill?.name ?? 'Skill';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tier = SkillBadgeTier.fromLevel(skill.level);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: tier.color.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              tier.icon,
              color: tier.color,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              _skillName,
              style: theme.textTheme.labelSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text(
              'Lv ${skill.level}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: tier.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Summary card showing overall skill statistics.
class SkillsSummaryCard extends StatelessWidget {
  final List<UserSkillStats> skills;
  final VoidCallback? onTap;

  const SkillsSummaryCard({
    super.key,
    required this.skills,
    this.onTap,
  });

  int get _totalAssessments => skills.fold<int>(0, (sum, s) => sum + s.totalAssessments);
  int get _avgLevel => skills.isEmpty 
      ? 0 
      : (skills.fold<int>(0, (sum, s) => sum + s.level) / skills.length).round();
  int get _masteredCount => skills.where((s) => s.level >= 81).length; // Expert tier

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.insights,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Skills Overview',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _StatItem(
                    label: 'Skills',
                    value: '${skills.length}',
                    icon: Icons.psychology,
                  ),
                  _StatItem(
                    label: 'Assessments',
                    value: '$_totalAssessments',
                    icon: Icons.quiz,
                  ),
                  _StatItem(
                    label: 'Avg Level',
                    value: '$_avgLevel',
                    icon: Icons.trending_up,
                  ),
                  _StatItem(
                    label: 'Mastered',
                    value: '$_masteredCount',
                    icon: Icons.workspace_premium,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            size: 20,
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Recent activity card showing latest skill progress.
class RecentSkillActivityCard extends StatelessWidget {
  final List<UserSkillStats> skills;
  final int maxItems;

  const RecentSkillActivityCard({
    super.key,
    required this.skills,
    this.maxItems = 3,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Sort by last assessed (most recent first), filter out null dates
    final recentSkills = skills
        .where((s) => s.lastAssessedAt != null)
        .toList()
      ..sort((a, b) => b.lastAssessedAt!.compareTo(a.lastAssessedAt!));
    final displaySkills = recentSkills.take(maxItems).toList();

    if (displaySkills.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  color: theme.colorScheme.secondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recent Activity',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...displaySkills.map((skill) => _RecentActivityItem(skill: skill)),
          ],
        ),
      ),
    );
  }
}

class _RecentActivityItem extends StatelessWidget {
  final UserSkillStats skill;

  const _RecentActivityItem({required this.skill});

  String get _skillName => skill.skill?.name ?? 'Skill';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tier = SkillBadgeTier.fromLevel(skill.level);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            tier.icon,
            color: tier.color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _skillName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (skill.lastAssessedAt != null)
                  Text(
                    _formatTimeAgo(skill.lastAssessedAt!),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            'Best: ${skill.bestScore}%',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }
}

/// Career path progress widget for dashboard.
class CareerProgressWidget extends StatelessWidget {
  final String careerName;
  final double progress;
  final int completedCourses;
  final int totalCourses;
  final VoidCallback? onTap;

  const CareerProgressWidget({
    super.key,
    required this.careerName,
    required this.progress,
    required this.completedCourses,
    required this.totalCourses,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.route,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      careerName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${(progress * 100).round()}%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$completedCourses of $totalCourses courses completed',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mini leaderboard widget for dashboard.
class MiniLeaderboardWidget extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  final String currentUserId;
  final VoidCallback? onViewFull;

  const MiniLeaderboardWidget({
    super.key,
    required this.entries,
    required this.currentUserId,
    this.onViewFull,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topEntries = entries.take(3).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.leaderboard,
                      color: theme.colorScheme.tertiary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Leaderboard',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (onViewFull != null)
                  TextButton(
                    onPressed: onViewFull,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('View All'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (topEntries.isEmpty)
              Text(
                'No rankings yet',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              )
            else
              ...topEntries.asMap().entries.map((entry) {
                final rank = entry.key + 1;
                final item = entry.value;
                final isCurrentUser = item.userId == currentUserId;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      _RankBadge(rank: rank),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.displayName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: isCurrentUser ? FontWeight.bold : null,
                            color: isCurrentUser ? theme.colorScheme.primary : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${item.xp} XP',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;

  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    String emoji;
    Color? bgColor;
    
    switch (rank) {
      case 1:
        emoji = '🥇';
        bgColor = Colors.amber.shade100;
        break;
      case 2:
        emoji = '🥈';
        bgColor = Colors.grey.shade200;
        break;
      case 3:
        emoji = '🥉';
        bgColor = Colors.orange.shade100;
        break;
      default:
        emoji = '$rank';
        bgColor = theme.colorScheme.surfaceContainerHighest;
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: rank <= 3
            ? Text(emoji, style: const TextStyle(fontSize: 16))
            : Text(
                emoji,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

/// Simple leaderboard entry model for the widget.
class LeaderboardEntry {
  final String userId;
  final String displayName;
  final int xp;
  final int rank;

  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.xp,
    required this.rank,
  });
}

import 'package:flutter/material.dart';

/// Skill tier badges with icons and colors
enum SkillBadgeTier {
  novice(0, 20, 'Novice', Icons.spa, Color(0xFF9E9E9E)),
  beginner(21, 40, 'Beginner', Icons.eco, Color(0xFF4CAF50)),
  intermediate(41, 60, 'Intermediate', Icons.psychology, Color(0xFF2196F3)),
  advanced(61, 80, 'Advanced', Icons.bolt, Color(0xFF9C27B0)),
  expert(81, 100, 'Expert', Icons.diamond, Color(0xFFFF9800));

  final int minLevel;
  final int maxLevel;
  final String label;
  final IconData icon;
  final Color color;

  const SkillBadgeTier(this.minLevel, this.maxLevel, this.label, this.icon, this.color);

  static SkillBadgeTier fromLevel(int level) {
    if (level <= 20) return novice;
    if (level <= 40) return beginner;
    if (level <= 60) return intermediate;
    if (level <= 80) return advanced;
    return expert;
  }

  /// Progress within this tier (0.0 to 1.0)
  double progressInTier(int level) {
    if (level < minLevel) return 0.0;
    if (level > maxLevel) return 1.0;
    return (level - minLevel) / (maxLevel - minLevel + 1);
  }
}

/// Achievement types for skill milestones
enum SkillAchievement {
  firstAssessment('First Steps', 'Complete your first assessment', Icons.flag, Color(0xFF4CAF50)),
  perfectScore('Perfect Score', 'Score 100% on an assessment', Icons.star, Color(0xFFFFD700)),
  speedDemon('Speed Demon', 'Complete assessment under time limit', Icons.timer, Color(0xFF2196F3)),
  consistent('Consistent', 'Complete 5 assessments for one skill', Icons.repeat, Color(0xFF9C27B0)),
  skillMaster('Skill Master', 'Reach Expert level in a skill', Icons.workspace_premium, Color(0xFFFF9800)),
  multiTalent('Multi-Talent', 'Reach Intermediate in 5 skills', Icons.auto_awesome, Color(0xFFE91E63)),
  dedicated('Dedicated', 'Complete 10 assessments total', Icons.military_tech, Color(0xFF00BCD4)),
  perfectWeek('Perfect Week', '7 day assessment streak', Icons.local_fire_department, Color(0xFFFF5722));

  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const SkillAchievement(this.title, this.description, this.icon, this.color);
}

/// User's earned achievement
class EarnedAchievement {
  final SkillAchievement achievement;
  final DateTime earnedAt;
  final String? skillName;

  const EarnedAchievement({
    required this.achievement,
    required this.earnedAt,
    this.skillName,
  });

  factory EarnedAchievement.fromJson(Map<String, dynamic> json) {
    return EarnedAchievement(
      achievement: SkillAchievement.values.firstWhere(
        (a) => a.name == json['achievement'],
        orElse: () => SkillAchievement.firstAssessment,
      ),
      earnedAt: DateTime.parse(json['earned_at'] as String),
      skillName: json['skill_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'achievement': achievement.name,
    'earned_at': earnedAt.toIso8601String(),
    'skill_name': skillName,
  };
}

/// Compact skill badge widget
class SkillBadge extends StatelessWidget {
  final int level;
  final double size;
  final bool showLabel;

  const SkillBadge({
    super.key,
    required this.level,
    this.size = 40,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final tier = SkillBadgeTier.fromLevel(level);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tier.color.withValues(alpha: 0.8),
                tier.color,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: tier.color.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            tier.icon,
            color: Colors.white,
            size: size * 0.5,
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 4),
          Text(
            tier.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: tier.color,
            ),
          ),
        ],
      ],
    );
  }
}

/// Large skill badge with level and progress
class SkillBadgeLarge extends StatelessWidget {
  final int level;
  final String? skillName;
  final bool showProgress;

  const SkillBadgeLarge({
    super.key,
    required this.level,
    this.skillName,
    this.showProgress = true,
  });

  @override
  Widget build(BuildContext context) {
    final tier = SkillBadgeTier.fromLevel(level);
    final progress = tier.progressInTier(level);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tier.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tier.color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Badge icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tier.color.withValues(alpha: 0.7),
                  tier.color,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: tier.color.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              tier.icon,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 12),

          // Level
          Text(
            'Level $level',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          // Tier name
          Text(
            tier.label,
            style: TextStyle(
              fontSize: 16,
              color: tier.color,
              fontWeight: FontWeight.w600,
            ),
          ),

          if (skillName != null) ...[
            const SizedBox(height: 4),
            Text(
              skillName!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],

          // Progress to next tier
          if (showProgress && tier != SkillBadgeTier.expert) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: 120,
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation(tier.color),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${tier.maxLevel - level + 1} to ${_nextTierName(tier)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _nextTierName(SkillBadgeTier current) {
    switch (current) {
      case SkillBadgeTier.novice:
        return 'Beginner';
      case SkillBadgeTier.beginner:
        return 'Intermediate';
      case SkillBadgeTier.intermediate:
        return 'Advanced';
      case SkillBadgeTier.advanced:
        return 'Expert';
      case SkillBadgeTier.expert:
        return 'Max';
    }
  }
}

/// Achievement badge widget
class AchievementBadge extends StatelessWidget {
  final SkillAchievement achievement;
  final bool earned;
  final DateTime? earnedAt;
  final double size;

  const AchievementBadge({
    super.key,
    required this.achievement,
    this.earned = true,
    this.earnedAt,
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: earned
          ? '${achievement.title}: ${achievement.description}'
          : 'Locked: ${achievement.description}',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: earned
              ? achievement.color.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.1),
          border: Border.all(
            color: earned ? achievement.color : Colors.grey.shade400,
            width: 2,
          ),
        ),
        child: Icon(
          achievement.icon,
          color: earned ? achievement.color : Colors.grey.shade400,
          size: size * 0.5,
        ),
      ),
    );
  }
}

/// Grid of user achievements
class AchievementsGrid extends StatelessWidget {
  final List<EarnedAchievement> earned;
  final bool showLocked;

  const AchievementsGrid({
    super.key,
    required this.earned,
    this.showLocked = true,
  });

  @override
  Widget build(BuildContext context) {
    final earnedTypes = earned.map((e) => e.achievement).toSet();

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: SkillAchievement.values.map((achievement) {
        final isEarned = earnedTypes.contains(achievement);
        if (!showLocked && !isEarned) return const SizedBox.shrink();

        final earnedData = earned.firstWhere(
          (e) => e.achievement == achievement,
          orElse: () => EarnedAchievement(
            achievement: achievement,
            earnedAt: DateTime.now(),
          ),
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AchievementBadge(
              achievement: achievement,
              earned: isEarned,
              earnedAt: isEarned ? earnedData.earnedAt : null,
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 70,
              child: Text(
                achievement.title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isEarned ? Colors.black87 : Colors.grey,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

/// Compact achievement summary for profile
class AchievementsSummary extends StatelessWidget {
  final int earnedCount;
  final int totalCount;
  final VoidCallback? onTap;

  const AchievementsSummary({
    super.key,
    required this.earnedCount,
    this.totalCount = 8,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.emoji_events, color: Colors.amber),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Achievements',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '$earnedCount of $totalCount unlocked',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // Mini achievement icons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  earnedCount.clamp(0, 3),
                  (i) => Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      SkillAchievement.values[i].icon,
                      size: 20,
                      color: SkillAchievement.values[i].color,
                    ),
                  ),
                ),
              ),
              if (earnedCount > 3) ...[
                const SizedBox(width: 4),
                Text(
                  '+${earnedCount - 3}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

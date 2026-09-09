import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/skill.dart';
import '../../providers/skill_stats_provider.dart';

/// Screen showing user's skill profile and all skills
class SkillsProfileScreen extends ConsumerWidget {
  const SkillsProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userStatsAsync = ref.watch(userSkillStatsProvider);
    final allSkillsAsync = ref.watch(skillsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Skills'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'My Skills', icon: Icon(Icons.person)),
              Tab(text: 'All Skills', icon: Icon(Icons.psychology)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // My Skills tab
            userStatsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (stats) => _MySkillsTab(stats: stats),
            ),

            // All Skills tab
            allSkillsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (skills) => _AllSkillsTab(skills: skills),
            ),
          ],
        ),
      ),
    );
  }
}

class _MySkillsTab extends StatelessWidget {
  final List<UserSkillStats> stats;

  const _MySkillsTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.psychology_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No skills assessed yet'),
            const SizedBox(height: 8),
            Text(
              'Take assessments to build your skill profile',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => DefaultTabController.of(context).animateTo(1),
              icon: const Icon(Icons.explore),
              label: const Text('Browse Skills'),
            ),
          ],
        ),
      );
    }

    // Group by tier
    final byTier = <SkillTier, List<UserSkillStats>>{};
    for (final stat in stats) {
      byTier.putIfAbsent(stat.tier, () => []).add(stat);
    }

    // Sort tiers from highest to lowest
    final sortedTiers = byTier.keys.toList()
      ..sort((a, b) => b.minLevel.compareTo(a.minLevel));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary card
        _SkillsSummaryCard(stats: stats),
        const SizedBox(height: 24),

        // Skills by tier
        for (final tier in sortedTiers) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '${tier.emoji} ${tier.displayName}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ...byTier[tier]!.map((stat) => _SkillStatCard(stat: stat)),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _SkillsSummaryCard extends StatelessWidget {
  final List<UserSkillStats> stats;

  const _SkillsSummaryCard({required this.stats});

  @override
  Widget build(BuildContext context) {


    // Calculate summary stats
    final totalSkills = stats.length;
    final avgLevel = stats.isEmpty
        ? 0.0
        : stats.map((s) => s.level).reduce((a, b) => a + b) / stats.length;
    final verified = stats.where((s) => s.isVerified).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SummaryItem(
                  value: '$totalSkills',
                  label: 'Skills',
                  icon: Icons.psychology,
                ),
                _SummaryItem(
                  value: '${avgLevel.toStringAsFixed(0)}',
                  label: 'Avg Level',
                  icon: Icons.trending_up,
                ),
                _SummaryItem(
                  value: '$verified',
                  label: 'Verified',
                  icon: Icons.verified,
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: avgLevel / 100,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              'Overall Skill Level',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _SummaryItem({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}

class _SkillStatCard extends StatelessWidget {
  final UserSkillStats stat;

  const _SkillStatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.push('/skills/${stat.skill?.slug ?? stat.skillId}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Level indicator
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: stat.level / 100,
                      strokeWidth: 4,
                      backgroundColor: Colors.grey.withValues(alpha: 0.2),
                    ),
                    Text(
                      '${stat.level}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Skill info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            stat.skill?.name ?? 'Skill',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (!stat.isVerified)
                          Tooltip(
                            message: 'Unverified - Take an assessment',
                            child: Icon(
                              Icons.warning_amber,
                              size: 16,
                              color: Colors.orange,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stat.tier.fullDisplayName,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    if (stat.lastAssessedAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${stat.totalAssessments} assessments · Best: ${stat.bestScore}%',
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ],
                ),
              ),

              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllSkillsTab extends StatelessWidget {
  final List<Skill> skills;

  const _AllSkillsTab({required this.skills});

  @override
  Widget build(BuildContext context) {
    if (skills.isEmpty) {
      return const Center(child: Text('No skills available'));
    }

    // Group by category
    final byCategory = <String, List<Skill>>{};
    for (final skill in skills) {
      final category = skill.category ?? 'Other';
      byCategory.putIfAbsent(category, () => []).add(skill);
    }

    final sortedCategories = byCategory.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final category in sortedCategories) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              category,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: byCategory[category]!.map((skill) {
              return ActionChip(
                avatar: skill.iconUrl != null
                    ? CircleAvatar(
                        backgroundImage: NetworkImage(skill.iconUrl!),
                      )
                    : const CircleAvatar(child: Icon(Icons.psychology, size: 16)),
                label: Text(skill.name),
                onPressed: () => context.push('/skills/${skill.slug}'),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

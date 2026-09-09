import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/skill.dart';
import '../../models/assessment.dart';
import '../../providers/skill_stats_provider.dart';
import '../../services/skill_assessment_service.dart';

/// Detail screen for a single skill
class SkillDetailScreen extends ConsumerWidget {
  final String skillSlug;

  const SkillDetailScreen({super.key, required this.skillSlug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skillAsync = ref.watch(skillBySlugProvider(skillSlug));

    return skillAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (skill) {
        if (skill == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Skill not found')),
          );
        }
        return _SkillDetailContent(skill: skill);
      },
    );
  }
}

class _SkillDetailContent extends ConsumerWidget {
  final Skill skill;

  const _SkillDetailContent({required this.skill});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userStatAsync = ref.watch(userSkillStatProvider(skill.id));
    final assessmentsAsync = ref.watch(skillAssessmentsProvider(skill.id));
    final leaderboardAsync = ref.watch(skillLeaderboardProvider(skill.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(skill.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard),
            tooltip: 'Leaderboard',
            onPressed: () => _showLeaderboard(context, leaderboardAsync),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Skill info card
          _SkillInfoCard(skill: skill),
          const SizedBox(height: 16),

          // User stats (if any)
          userStatAsync.when(
            loading: () => const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (_, __) => const SizedBox(),
            data: (stat) => stat != null
                ? _UserSkillCard(stat: stat)
                : _NoStatsCard(skillId: skill.id),
          ),
          const SizedBox(height: 24),

          // Assessments section
          const Text(
            'Available Assessments',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          assessmentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (assessments) {
              if (assessments.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('No assessments available yet'),
                    ),
                  ),
                );
              }
              return Column(
                children: assessments.map((assessment) {
                  return _AssessmentCard(assessment: assessment);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showLeaderboard(
    BuildContext context,
    AsyncValue<List<LeaderboardEntry>> leaderboardAsync,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.leaderboard),
                    const SizedBox(width: 8),
                    Text(
                      '${skill.name} Leaderboard',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: leaderboardAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (entries) {
                    if (entries.isEmpty) {
                      return const Center(
                        child: Text('No leaderboard entries yet'),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getRankColor(entry.rank),
                            child: Text(
                              '${entry.rank}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(entry.displayName ?? 'Anonymous'),
                          subtitle: Text(entry.tier.fullDisplayName),
                          trailing: Text(
                            'Level ${entry.level}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey.shade400;
      case 3:
        return Colors.brown.shade400;
      default:
        return Colors.blueGrey;
    }
  }
}

class _SkillInfoCard extends StatelessWidget {
  final Skill skill;

  const _SkillInfoCard({required this.skill});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor:
                  Theme.of(context).colorScheme.primaryContainer,
              child: skill.iconUrl != null
                  ? ClipOval(
                      child: Image.network(skill.iconUrl!, fit: BoxFit.cover),
                    )
                  : const Icon(Icons.psychology, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    skill.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (skill.category != null) ...[
                    const SizedBox(height: 4),
                    Chip(
                      label: Text(skill.category!),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                  if (skill.description != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      skill.description!,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserSkillCard extends StatelessWidget {
  final UserSkillStats stat;

  const _UserSkillCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Level circle
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: stat.level / 100,
                        strokeWidth: 6,
                        backgroundColor: Colors.grey.withValues(alpha: 0.2),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${stat.level}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Level',
                            style: TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            stat.tier.fullDisplayName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (!stat.isVerified) ...[
                            const SizedBox(width: 8),
                            Tooltip(
                              message: 'Score was reset - Take a new assessment',
                              child: Icon(
                                Icons.warning_amber,
                                color: Colors.orange,
                                size: 18,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _StatItem(
                            label: 'Best',
                            value: '${stat.bestScore}%',
                          ),
                          const SizedBox(width: 16),
                          _StatItem(
                            label: 'Avg',
                            value: '${stat.averageScore.toStringAsFixed(0)}%',
                          ),
                          const SizedBox(width: 16),
                          _StatItem(
                            label: 'Tests',
                            value: '${stat.totalAssessments}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Progress within tier
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(stat.tier.displayName),
                Text(
                    '${((stat.tierProgress) * 100).toStringAsFixed(0)}% to next tier'),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: stat.tierProgress,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }
}

class _NoStatsCard extends StatelessWidget {
  final String skillId;

  const _NoStatsCard({required this.skillId});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.quiz, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'No assessment taken yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Take an assessment below to measure your skill level',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  final SkillAssessment assessment;

  const _AssessmentCard({required this.assessment});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getDifficultyColor(assessment.difficulty),
          child: Text(
            assessment.difficulty.emoji,
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(assessment.title),
        subtitle: Text(
          '${assessment.questionCount} questions · ${assessment.timeLimitMinutes} min · Pass: ${assessment.passingScore}%',
        ),
        trailing: FilledButton(
          onPressed: () => context.push('/assess/${assessment.id}'),
          child: const Text('Start'),
        ),
      ),
    );
  }

  Color _getDifficultyColor(AssessmentDifficulty difficulty) {
    switch (difficulty) {
      case AssessmentDifficulty.beginner:
        return Colors.green;
      case AssessmentDifficulty.intermediate:
        return Colors.orange;
      case AssessmentDifficulty.advanced:
        return Colors.red;
    }
  }
}

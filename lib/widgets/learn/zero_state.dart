import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/learning_target.dart';
import 'package:learning_pwa/theme/design_tokens.dart';
import 'package:learning_pwa/widgets/targets/create_target_dialog.dart';

/// Destination-aware First-Run & Selection Surface.
/// Accurately represents the multi-target learning taxonomy (Careers, Certifications,
/// Standardized Exams, Academic Programs, and Courses) rather than just "courses".
///
/// When the catalog is empty, it uses "Create" as the primary hero representation
/// with direct creation actions instead of dead ends or disabled controls.
class LearnZeroState extends StatelessWidget {
  final bool catalogEmpty;

  const LearnZeroState({super.key, this.catalogEmpty = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (catalogEmpty) {
      // EMPTY STATE: Prominently feature creation actions (Spec: use Create when empty)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: DesignTokens.space4),
          Card(
            elevation: 0,
            color: colorScheme.primaryContainer.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
              side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(DesignTokens.space5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(DesignTokens.space3),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_task,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: DesignTokens.space4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Set Your First Learning Goal',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: DesignTokens.space1),
                            Text(
                              'Create a career milestone, certification, exam goal, or subject syllabus.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DesignTokens.space5),
                  Wrap(
                    spacing: DesignTokens.space3,
                    runSpacing: DesignTokens.space2,
                    children: [
                      FilledButton.icon(
                        key: const Key('zero-create-goal-btn'),
                        onPressed: () => CreateTargetDialog.show(context),
                        icon: const Icon(Icons.flag_outlined),
                        label: const Text('Create Goal'),
                      ),
                      FilledButton.tonalIcon(
                        key: const Key('zero-ai-generate-btn'),
                        onPressed: () => context.push('/create-lesson'),
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Generate with AI'),
                      ),
                      OutlinedButton.icon(
                        key: const Key('zero-create-lesson-btn'),
                        onPressed: () => context.push('/course-management'),
                        icon: const Icon(Icons.library_books_outlined),
                        label: const Text('Create Course'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.space5),
          Text(
            'Explore Destinations',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: DesignTokens.space3),
          _buildDestinationList(context, emptyMode: true),
        ],
      );
    }

    // NORMAL BROWSING: Comprehensive Destination Representation
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: DesignTokens.space4),
        Text(
          'What do you want to learn?',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: DesignTokens.space2),
        Text(
          'Choose your destination — career pathways, professional certifications, standardized exams, and academic disciplines.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: DesignTokens.space5),
        _buildDestinationList(context, emptyMode: false),
        const SizedBox(height: DesignTokens.space5),
        const Divider(),
        const SizedBox(height: DesignTokens.space3),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Looking for something custom?',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: DesignTokens.space2),
            TextButton.icon(
              onPressed: () => CreateTargetDialog.show(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Goal'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDestinationList(BuildContext context, {required bool emptyMode}) {
    return Column(
      children: [
        _DestinationCard(
          key: const Key('dest-careers'),
          emoji: '💼',
          title: 'Career Pathways & Roles',
          subtitle: 'Software Engineer, Registered Nurse, Data Analyst, Electrician...',
          badge: 'SOC / O*NET',
          onTap: () {
            if (emptyMode) {
              CreateTargetDialog.show(context, initialType: TargetType.career);
            } else {
              context.go('/library?type=career');
            }
          },
        ),
        _DestinationCard(
          key: const Key('dest-certs'),
          emoji: '📜',
          title: 'Professional Certifications',
          subtitle: 'CompTIA Security+, AWS Cloud, NCLEX-RN, Project Management...',
          badge: 'Industry Certs',
          onTap: () {
            if (emptyMode) {
              CreateTargetDialog.show(context, initialType: TargetType.certification);
            } else {
              context.go('/library?type=certification');
            }
          },
        ),
        _DestinationCard(
          key: const Key('dest-exams'),
          emoji: '📝',
          title: 'Standardized Exams & K–12',
          subtitle: 'USMLE, MCAT, AP Examinations, State Curriculum Standards...',
          badge: 'Official Benchmarks',
          onTap: () {
            if (emptyMode) {
              CreateTargetDialog.show(context, initialType: TargetType.standardizedExam);
            } else {
              context.go('/library?type=standardized_exam');
            }
          },
        ),
        _DestinationCard(
          key: const Key('dest-academics'),
          emoji: '🎓',
          title: 'Academic Disciplines & Fields',
          subtitle: 'Computer Science, Mathematics, Biological Sciences, Engineering...',
          badge: 'CIP Fields',
          onTap: () {
            if (emptyMode) {
              CreateTargetDialog.show(context, initialType: TargetType.academicProgram);
            } else {
              context.go('/library?type=academic_program');
            }
          },
        ),
        _DestinationCard(
          key: const Key('dest-courses'),
          emoji: '📚',
          title: 'Interactive Courses & Lessons',
          subtitle: 'Structured modular study units, bite-sized lessons, and flashcards...',
          badge: 'Curriculum',
          onTap: () {
            if (emptyMode) {
              context.push('/course-management');
            } else {
              context.go('/library');
            }
          },
        ),
      ],
    );
  }
}

class _DestinationCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;

  const _DestinationCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: DesignTokens.space3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space4,
            vertical: DesignTokens.space3,
          ),
          child: Row(
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: DesignTokens.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: DesignTokens.space2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                          ),
                          child: Text(
                            badge,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DesignTokens.space2),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/learning_context.dart';
import '../../providers/learning_context_provider.dart';
import '../../providers/learning_target_provider.dart';
import '../../theme/design_tokens.dart';

class ConceptDetailScreen extends ConsumerStatefulWidget {
  final String conceptId;

  const ConceptDetailScreen({super.key, required this.conceptId});

  @override
  ConsumerState<ConceptDetailScreen> createState() => _ConceptDetailScreenState();
}

class _ConceptDetailScreenState extends ConsumerState<ConceptDetailScreen> {
  String? _selectedLessonId;
  List<Map<String, dynamic>> _candidateLessons = [];
  bool _isLoadingCandidates = true;

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  Future<void> _loadCandidates() async {
    final service = ref.read(learningTargetServiceProvider);
    final candidates = await service.getTeachingLessonsForConcept(widget.conceptId);
    if (mounted) {
      setState(() {
        _candidateLessons = candidates;
        _isLoadingCandidates = false;
        if (candidates.isNotEmpty) {
          final firstLesson = candidates.first['lessons'] as Map<String, dynamic>?;
          _selectedLessonId = firstLesson?['id'] as String?;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final conceptAsync = ref.watch(conceptDetailProvider(widget.conceptId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Concept'),
      ),
      body: conceptAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading concept: $err')),
        data: (concept) {
          if (concept == null) {
            return const Center(child: Text('Concept not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(DesignTokens.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    if (concept.emoji != null) ...[
                      Text(concept.emoji!, style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: DesignTokens.space3),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Canonical Concept',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onTertiaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: DesignTokens.space1),
                          Text(
                            concept.name,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DesignTokens.space4),

                // Short definition / description
                if (concept.shortDefinition != null) ...[
                  Text(
                    concept.shortDefinition!,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space3),
                ],

                // Aliases
                if (concept.aliases.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: concept.aliases.map((alias) {
                      return Chip(
                        label: Text(alias, style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: DesignTokens.space4),
                ],

                const Divider(),
                const SizedBox(height: DesignTokens.space4),

                // Teaching Track Selection (§7.3.2)
                Text(
                  'Choose Learning Track',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: DesignTokens.space1),
                Text(
                  'Select the instructional sequence that best fits your background.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: DesignTokens.space3),

                if (_isLoadingCandidates)
                  const LinearProgressIndicator()
                else if (_candidateLessons.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(DesignTokens.space3),
                      child: Text(
                        'Direct conceptual study session (terms & flashcards)',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  )
                else
                  Column(
                    children: _candidateLessons.map((cand) {
                      final lesson = cand['lessons'] as Map<String, dynamic>?;
                      if (lesson == null) return const SizedBox.shrink();
                      final lId = lesson['id'] as String;
                      final isSelected = _selectedLessonId == lId;

                      return Card(
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: RadioListTile<String>(
                          value: lId,
                          groupValue: _selectedLessonId,
                          onChanged: (val) => setState(() => _selectedLessonId = val),
                          title: Text(
                            lesson['title'] as String? ?? 'Lesson',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: lesson['category'] != null
                              ? Text(lesson['category'] as String)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: DesignTokens.space5),

                // Start studying button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('concept-start-learning-button'),
                    onPressed: () async {
                      final userId = ref.read(learnerIdProvider);

                      await ref.read(learningContextsProvider.notifier).createOrSwitch(
                            userId: userId,
                            label: concept.name,
                            rootType: ContextRootType.concept,
                            rootId: concept.id,
                            emoji: concept.emoji ?? '💡',
                            scopeConfig: {
                              if (_selectedLessonId != null)
                                'selectedLessonId': _selectedLessonId,
                            },
                          );

                      if (context.mounted) {
                        context.go('/learn');
                      }
                    },
                    icon: const Icon(Icons.school),
                    label: const Text('Study This Concept'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

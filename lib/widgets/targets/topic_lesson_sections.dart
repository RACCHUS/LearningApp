import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/curriculum_node.dart';
import '../../models/user_curriculum_resource.dart';
import '../../providers/available_lessons_provider.dart';
import '../../providers/learning_context_provider.dart';
import '../../providers/learning_target_provider.dart';
import '../../providers/scope_resolver_provider.dart';
import '../../providers/user_curriculum_resource_provider.dart';
import '../../theme/design_tokens.dart';
import '../../theme/semantic_colors.dart';

class TopicLessonSections extends ConsumerStatefulWidget {
  final CurriculumNode node;
  final bool canEditCurriculum;
  final VoidCallback? onFocusRequested;

  const TopicLessonSections({
    super.key,
    required this.node,
    this.canEditCurriculum = false,
    this.onFocusRequested,
  });

  @override
  ConsumerState<TopicLessonSections> createState() => _TopicLessonSectionsState();
}

class _TopicLessonSectionsState extends ConsumerState<TopicLessonSections> {
  Future<void> _handleRemoveOverlay(
    UserCurriculumResource resource,
  ) async {
    try {
      final resourceService = ref.read(userCurriculumResourceServiceProvider);
      await resourceService.removePersonalLesson(
        curriculumNodeId: widget.node.id,
        lessonId: resource.lessonId,
      );

      try {
        await ref.read(scopeResolverProvider).invalidateScope();
      } catch (_) {}
      ref.invalidate(activeResolvedScopeProvider);
      ref.invalidate(userCurriculumResourcesForNodeProvider(widget.node.id));
      ref.invalidate(availableLessonsCatalogProvider);
      ref.invalidate(learningContextsProvider);

      if (mounted) {
        final semantic = Theme.of(context).extension<SemanticColors>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Lesson removed from topic'),
            backgroundColor: semantic?.success ?? Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final semantic = Theme.of(context).extension<SemanticColors>();
        final errorText = 'Failed to remove from topic: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorText),
            backgroundColor: semantic?.danger ?? Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final officialLessonsAsync = ref.watch(nodeLessonsProvider(widget.node.id));
    final personalResourcesAsync =
        ref.watch(userCurriculumResourcesForNodeProvider(widget.node.id));

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.space4,
        vertical: DesignTokens.space3,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.node.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (widget.onFocusRequested != null)
                IconButton(
                  icon: const Icon(Icons.my_location),
                  tooltip: 'Focus active scope on this topic',
                  onPressed: widget.onFocusRequested,
                ),
            ],
          ),
          if (widget.node.description != null &&
              widget.node.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.node.description!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: DesignTokens.space3),

          // Section 1: Official Material / Curriculum material
          Text(
            widget.canEditCurriculum ? 'Curriculum material' : 'Official material',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: DesignTokens.space1),
          officialLessonsAsync.when(
            data: (lessons) {
              final emptyText = widget.canEditCurriculum
                  ? 'No lessons added to this topic yet'
                  : 'No official lessons for this topic';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (lessons.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        emptyText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else
                    ...lessons.map((l) {
                      final title = l.lessonTitle ?? 'Lesson ${l.lessonId}';
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.menu_book_outlined, size: 20),
                        title: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () {
                          context.push('/lesson/${l.lessonId}');
                        },
                      );
                    }),
                  if (widget.canEditCurriculum) ...[
                    const SizedBox(height: DesignTokens.space2),
                    FilledButton.tonalIcon(
                      key: const Key('add_curriculum_lesson_button'),
                      onPressed: () {
                        final uri = Uri(
                          path: '/create-lesson',
                          queryParameters: {
                            'nodeId': widget.node.id,
                            'nodeTitle': widget.node.title,
                            'targetVersionId': widget.node.targetVersionId,
                            'attachmentIntent': 'official_draft_binding',
                          },
                        );
                        context.push(uri.toString());
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Add lesson to curriculum'),
                    ),
                  ],
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => Text(
              'Error loading curriculum lessons: $err',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
          const Divider(height: DesignTokens.space4),

          // Section 2: Your study material
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your study material',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space1),
          if (widget.canEditCurriculum)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Personal study overlays are designed for published official targets. You can edit this target\'s curriculum directly using the button above.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            personalResourcesAsync.when(
              data: (resources) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (resources.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'No personal study lessons yet',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    else
                      ...resources.map((r) {
                        final title = r.lessonTitle ?? 'Personal Lesson';
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.person_outline, size: 20),
                          title: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 18),
                            onSelected: (val) {
                              if (val == 'remove') {
                                _handleRemoveOverlay(r);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'remove',
                                child: Text('Remove from topic'),
                              ),
                            ],
                          ),
                          onTap: () {
                            context.push('/lesson/${r.lessonId}');
                          },
                        );
                      }),
                    const SizedBox(height: DesignTokens.space2),
                    FilledButton.tonalIcon(
                      key: const Key('create_personal_study_lesson_button'),
                      onPressed: () {
                        final uri = Uri(
                          path: '/create-lesson',
                          queryParameters: {
                            'nodeId': widget.node.id,
                            'nodeTitle': widget.node.title,
                            'targetVersionId': widget.node.targetVersionId,
                            'attachmentIntent': 'personal_study',
                          },
                        );
                        context.push(uri.toString());
                      },
                      icon: const Icon(Icons.auto_stories_outlined, size: 18),
                      label: const Text('Create personal study lesson'),
                    ),
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Text(
                'Error loading study material: $err',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/content_generation/coverage_matrix.dart';
import '../../models/learning_context.dart';
import '../../models/learning_target.dart';
import '../../providers/learning_context_provider.dart';
import '../../providers/learning_target_provider.dart';
import '../../providers/target_coverage_provider.dart';
import '../../theme/design_tokens.dart';
import '../targets/create_target_dialog.dart';
import '../targets/target_coverage_card.dart';

enum CreateChoice { goal, studySet, lesson, import }

/// The single "What would you like to make?" chooser for Library (§5.4).
///
/// Every Create action in Library routes through here so learners meet one
/// consistent entry instead of several buttons with different names.
class CreateChooserSheet extends StatelessWidget {
  /// Text the learner searched for, carried into the goal title.
  final String? query;

  /// Missing pieces of the learner's active goal (master plan v2.6 §13.0
  /// need list), shown above the general choices. Empty when the active
  /// context is not a published goal or nothing is missing.
  final List<CoverageNeed> needs;

  /// Title of the goal the needs belong to.
  final String? needsGoalTitle;

  const CreateChooserSheet({
    super.key,
    this.query,
    this.needs = const [],
    this.needsGoalTitle,
  });

  static const maxNeeds = 3;

  /// The active goal's missing pieces, or none. Never blocks the chooser
  /// for long and never throws: a failed lookup just shows no need list.
  static Future<({List<CoverageNeed> needs, String? title, String? versionId})>
      activeGoalNeeds(BuildContext context) async {
    const none = (needs: <CoverageNeed>[], title: null, versionId: null);
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final active = container.read(activeLearningContextProvider);
      if (active == null || active.rootType != ContextRootType.target) return none;
      final target = await container.read(targetDetailProvider(active.rootId).future);
      final version = await container.read(targetVersionProvider(active.rootId).future);
      if (target == null || version == null || !version.isPublished) return none;
      final summary = await container
          .read(targetCoverageProvider(target.slug).future)
          .timeout(const Duration(seconds: 3));
      return (
        needs: summary.needs.take(maxNeeds).toList(),
        title: target.title,
        versionId: version.id,
      );
    } catch (_) {
      return none;
    }
  }

  static Future<void> show(
    BuildContext context, {
    String? query,
    TargetType? initialType,
  }) async {
    final trimmed = query?.trim() ?? '';
    final goal = await activeGoalNeeds(context);
    if (!context.mounted) return;
    final picked = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => CreateChooserSheet(
        query: trimmed,
        needs: goal.needs,
        needsGoalTitle: goal.title,
      ),
    );
    if (picked == null || !context.mounted) return;
    if (picked is CoverageNeed) {
      openMakeMyOwnVersion(context, need: picked, targetVersionId: goal.versionId!);
      return;
    }
    final choice = picked as CreateChoice;
    switch (choice) {
      case CreateChoice.goal:
        await CreateTargetDialog.show(
          context,
          initialType: initialType,
          initialTitle: trimmed.isEmpty ? null : trimmed,
        );
      case CreateChoice.studySet:
        GoRouter.of(context).push('/content-picker');
      case CreateChoice.lesson:
        GoRouter.of(context).push('/create-lesson');
      case CreateChoice.import:
        GoRouter.of(context).push('/create-lesson?tab=json');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmed = query?.trim() ?? '';

    Widget option(CreateChoice choice, IconData icon, String title, String subtitle) {
      return ListTile(
        key: Key('create-chooser-${choice.name}'),
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: () => Navigator.of(context).pop(choice),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          DesignTokens.space4,
          0,
          DesignTokens.space4,
          DesignTokens.space4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'What would you like to make?',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (trimmed.isNotEmpty) ...[
              const SizedBox(height: DesignTokens.space1),
              Text(
                'Starting from "$trimmed"',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            if (needs.isNotEmpty) ...[
              const SizedBox(height: DesignTokens.space2),
              Text(
                needsGoalTitle == null
                    ? 'Missing from your goal'
                    : 'Missing from $needsGoalTitle',
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              for (final n in needs)
                ListTile(
                  key: Key('create-chooser-need-${n.row.objectiveId}'),
                  leading: const Icon(Icons.extension_outlined),
                  title: Text(n.row.code == null
                      ? n.row.title
                      : '${n.row.code} ${n.row.title}'),
                  subtitle: Text(
                      'Not available yet: ${n.missingLabel}. Make your own private version.'),
                  onTap: () => Navigator.of(context).pop(n),
                ),
              const Divider(),
            ],
            const SizedBox(height: DesignTokens.space2),
            option(CreateChoice.goal, Icons.flag_outlined, 'Learning goal',
                'A career, certification, exam, or subject'),
            option(CreateChoice.studySet, Icons.style_outlined, 'Study set',
                'Pick lessons to practice together'),
            option(CreateChoice.lesson, Icons.note_add_outlined, 'Lesson',
                'Write your own questions and notes'),
            option(CreateChoice.import, Icons.upload_file_outlined, 'Import',
                'Bring in a lesson from a JSON file'),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/learning_target.dart';
import '../../theme/design_tokens.dart';
import '../targets/create_target_dialog.dart';

enum CreateChoice { goal, studySet, lesson, import }

/// The single "What would you like to make?" chooser for Library (§5.4).
///
/// Every Create action in Library routes through here so learners meet one
/// consistent entry instead of several buttons with different names.
class CreateChooserSheet extends StatelessWidget {
  /// Text the learner searched for, carried into the goal title.
  final String? query;

  const CreateChooserSheet({super.key, this.query});

  static Future<void> show(
    BuildContext context, {
    String? query,
    TargetType? initialType,
  }) async {
    final trimmed = query?.trim() ?? '';
    final choice = await showModalBottomSheet<CreateChoice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => CreateChooserSheet(query: trimmed),
    );
    if (choice == null || !context.mounted) return;
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

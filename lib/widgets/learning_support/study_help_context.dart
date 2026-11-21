import 'package:flutter/widgets.dart';
import 'package:learning_pwa/widgets/learning_support/learning_help_action.dart';

/// The lesson a study screen (flashcards, questions, concepts) was opened
/// from, so it can offer the same "Learning help" as the lesson itself
/// (master plan v2.6 §21: help on the major active study surfaces).
/// Returning from help pops back to that study screen.
class StudyHelpContext {
  const StudyHelpContext({
    required this.lessonId,
    required this.lessonTitle,
    this.tags = const [],
  });

  final String lessonId;
  final String lessonTitle;
  final List<String> tags;

  /// The help button for an app bar. It hides itself when help is switched
  /// off or no Bridge applies to the lesson's tags.
  Widget action() => LearningHelpAction(
    lessonId: lessonId,
    lessonTitle: lessonTitle,
    tags: tags,
  );
}

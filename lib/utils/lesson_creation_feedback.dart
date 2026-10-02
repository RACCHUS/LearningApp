const String kPersonalAttachmentSuccessCopy =
    'Lesson created and added to this topic';
const String kPersonalAttachmentFailureCopy =
    "Lesson created, but we couldn't attach it to this topic";

/// Describes lesson creation independently of an optional curriculum binding.
String lessonCreationFeedback({
  required String lessonTitle,
  required bool isBound,
  String? nodeId,
  String? nodeTitle,
  bool imported = false,
}) {
  final action = imported ? 'imported' : 'created';
  if (isBound) {
    return 'Lesson "$lessonTitle" $action and bound to ${nodeTitle ?? 'the curriculum topic'}!';
  }
  if (nodeId != null && nodeId.isNotEmpty) {
    return 'Lesson "$lessonTitle" $action, but couldn\'t attach it to ${nodeTitle ?? 'the curriculum topic'}. Find it in your lessons.';
  }
  if (nodeTitle != null && nodeTitle.isNotEmpty) {
    return 'Personal study lesson "$lessonTitle" $action for $nodeTitle.';
  }
  return 'Lesson "$lessonTitle" $action successfully!';
}

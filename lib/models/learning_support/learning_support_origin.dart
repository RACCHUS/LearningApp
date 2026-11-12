import 'package:learning_pwa/models/learning_support/return_anchor.dart';
import 'package:learning_pwa/models/learning_support/support_identifiers.dart';

/// Where a request for learning help came from (master plan v2.6 §12.1).
///
/// Identifiers only: [itemId] names an assessment item but never carries
/// its content or answer key. Every origin points at a return anchor that
/// was captured before help opened.
class LearningSupportOrigin {
  LearningSupportOrigin({
    required this.learningContextId,
    required this.returnAnchorId,
    this.targetVersionId,
    this.lessonId,
    this.blockId,
    this.itemId,
    this.objectiveId,
    this.conceptId,
  }) {
    final fields = <String, String?>{
      'learningContextId': learningContextId,
      'returnAnchorId': returnAnchorId,
      'targetVersionId': targetVersionId,
      'lessonId': lessonId,
      'blockId': blockId,
      'itemId': itemId,
      'objectiveId': objectiveId,
      'conceptId': conceptId,
    };
    fields.forEach((name, v) {
      if (v != null && !SupportIdentifiers.isId(v)) {
        throw ArgumentError.value(v, name, 'not a safe identifier');
      }
    });
  }

  /// Builds the origin from the anchor captured for it, so the two cannot
  /// disagree about context, lesson, block or item.
  factory LearningSupportOrigin.fromAnchor(
    ReturnAnchor anchor, {
    String? objectiveId,
    String? conceptId,
  }) => LearningSupportOrigin(
    learningContextId: anchor.learningContextId,
    returnAnchorId: anchor.anchorId,
    targetVersionId: anchor.targetVersionId,
    lessonId: anchor.lessonId,
    blockId: anchor.blockId,
    itemId: anchor.assessmentItemId,
    objectiveId: objectiveId,
    conceptId: conceptId,
  );

  final String learningContextId;
  final String? targetVersionId;
  final String? lessonId;
  final String? blockId;
  final String? itemId;
  final String? objectiveId;
  final String? conceptId;
  final String returnAnchorId;
}

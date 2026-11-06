import 'package:learning_core/learning_core.dart';
import '../../models/learning_event.dart';

/// Manages interactive video session state, checkpoint evaluations,
/// and measured learning gain calculations (OPP-2, ER-10).
class VideoLearningService {
  final Map<String, dynamic> _completedCheckpoints = {};
  final List<LearningEvent> _emittedEvents = [];

  List<LearningEvent> get emittedEvents => List.unmodifiable(_emittedEvents);

  /// Records learner interaction on a video checkpoint and generates an event.
  LearningEvent recordCheckpointAttempt({
    required VideoInteractiveModule module,
    required VideoCheckpoint checkpoint,
    required int selectedOptionIndex,
    required int latencyMs,
    String? userId,
    String? sessionId,
  }) {
    final isCorrect = selectedOptionIndex >= 0 &&
        selectedOptionIndex < checkpoint.item.options.length &&
        checkpoint.item.options[selectedOptionIndex].isCorrect;

    final eventType = checkpoint.type == VideoCheckpointType.prequestion
        ? 'prequestion_answered'
        : 'video_checkpoint_answered';

    final event = LearningEvent(
      userId: userId,
      sessionId: sessionId,
      eventType: eventType,
      itemType: 'video_checkpoint',
      itemId: checkpoint.id,
      score: isCorrect ? 1.0 : 0.0,
      latencyMs: latencyMs,
      response: selectedOptionIndex,
      metadata: {
        'video_id': module.id,
        'checkpoint_type': checkpoint.type.toDbString(),
        'timestamp_seconds': checkpoint.timestampSeconds,
        'concept_slug': checkpoint.targetConceptSlug ?? checkpoint.item.conceptSlug,
        'source_ref': checkpoint.item.sourceRef,
      },
    );

    _completedCheckpoints[checkpoint.id] = {
      'selected_index': selectedOptionIndex,
      'is_correct': isCorrect,
      'completed_at': DateTime.now().toUtc().toIso8601String(),
    };

    _emittedEvents.add(event);
    return event;
  }

  /// Checks if [checkpointId] has already been completed in this session.
  bool isCheckpointCompleted(String checkpointId) {
    return _completedCheckpoints.containsKey(checkpointId);
  }

  /// Calculates learning gain between prequestion accuracy and postquestion accuracy.
  LearningGainResult calculateSessionGain({
    required double preScore,
    required double postScore,
  }) {
    return LearningGainCalculator.evaluate(
      preScore: preScore,
      postScore: postScore,
    );
  }

  /// Evaluates ER-10 prequestion effect for a session.
  PrequestionPrimingComparison evaluatePriming({
    required double targetedPreScore,
    required double targetedPostScore,
    required double untargetedPreScore,
    required double untargetedPostScore,
  }) {
    return LearningGainCalculator.evaluatePrimingEffect(
      targetedPreScore: targetedPreScore,
      targetedPostScore: targetedPostScore,
      untargetedPreScore: untargetedPreScore,
      untargetedPostScore: untargetedPostScore,
    );
  }
}

import '../models/learning_event.dart';

/// Formatter and emitter translating [LearningEventCore] envelopes into
/// compliant ADL Experience API (xAPI 1.0.3) statements.
class XApiStatementEmitter {
  static const String verbAnswered = 'http://adlnet.gov/expapi/verbs/answered';
  static const String verbPassed = 'http://adlnet.gov/expapi/verbs/passed';
  static const String verbFailed = 'http://adlnet.gov/expapi/verbs/failed';
  static const String verbCompleted = 'http://adlnet.gov/expapi/verbs/completed';
  static const String verbExperienced =
      'http://adlnet.gov/expapi/verbs/experienced';

  static const String activityInteraction =
      'http://adlnet.gov/expapi/activities/cmi.interaction';
  static const String activityAssessment =
      'http://adlnet.gov/expapi/activities/assessment';
  static const String activityLesson =
      'http://adlnet.gov/expapi/activities/lesson';

  /// Maps an event type to standard xAPI verb metadata.
  static Map<String, dynamic> mapVerb(String eventType) {
    switch (eventType) {
      case 'review_completed':
      case 'item_answered':
        return {
          'id': verbAnswered,
          'display': {'en-US': 'answered'},
        };
      case 'assessment_passed':
        return {
          'id': verbPassed,
          'display': {'en-US': 'passed'},
        };
      case 'assessment_failed':
        return {
          'id': verbFailed,
          'display': {'en-US': 'failed'},
        };
      case 'lesson_completed':
      case 'module_completed':
        return {
          'id': verbCompleted,
          'display': {'en-US': 'completed'},
        };
      default:
        return {
          'id': verbExperienced,
          'display': {'en-US': 'experienced'},
        };
    }
  }

  /// Formats seconds or milliseconds into standard ISO 8601 duration (e.g. PT15S, PT1M30S).
  static String formatIsoDuration({int? seconds, int? milliseconds}) {
    final totalSec = seconds ??
        (milliseconds != null ? (milliseconds / 1000).round() : 0);
    if (totalSec <= 0) return 'PT0S';

    final hours = totalSec ~/ 3600;
    final minutes = (totalSec % 3600) ~/ 60;
    final remainingSec = totalSec % 60;

    final buffer = StringBuffer('PT');
    if (hours > 0) buffer.write('${hours}H');
    if (minutes > 0) buffer.write('${minutes}M');
    if (remainingSec > 0 || (hours == 0 && minutes == 0)) {
      buffer.write('${remainingSec}S');
    }
    return buffer.toString();
  }

  /// Translates a [LearningEventCore] into a valid ADL xAPI 1.0.3 statement.
  static Map<String, dynamic> emitStatement(
    LearningEventCore event, {
    String baseUri = 'https://learningapp.org',
    String platformName = 'LearningApp',
  }) {
    final payload = event.payload;
    final itemId = payload['item_id'] as String? ??
        payload['question_id'] as String? ??
        payload['card_id']?.toString();
    final lessonId = payload['lesson_id'] as String?;
    final assessmentId = payload['assessment_id'] as String?;

    // Determine activity URI
    final String activityUri;
    final String activityType;
    final String activityName;

    if (itemId != null) {
      activityUri = '$baseUri/activities/items/$itemId';
      activityType = activityInteraction;
      activityName = 'Assessment Item $itemId';
    } else if (assessmentId != null) {
      activityUri = '$baseUri/activities/assessments/$assessmentId';
      activityType = activityAssessment;
      activityName = 'Assessment $assessmentId';
    } else if (lessonId != null) {
      activityUri = '$baseUri/activities/lessons/$lessonId';
      activityType = activityLesson;
      activityName = 'Lesson $lessonId';
    } else {
      activityUri = '$baseUri/activities/general/${event.id}';
      activityType = activityInteraction;
      activityName = 'Learning Activity';
    }

    // Result compilation
    final isCorrect = payload['is_correct'] as bool?;
    final scoreValue = payload['score'] is num
        ? (payload['score'] as num).toDouble()
        : (isCorrect == true ? 1.0 : (isCorrect == false ? 0.0 : null));
    final durationMs = payload['response_time_ms'] as int? ??
        payload['elapsed_ms'] as int?;

    final result = <String, dynamic>{
      'completion': true,
      if (isCorrect != null) 'success': isCorrect,
      if (scoreValue != null)
        'score': {
          'raw': scoreValue,
          'min': 0.0,
          'max': 1.0,
          'scaled': scoreValue,
        },
      if (durationMs != null)
        'duration': formatIsoDuration(milliseconds: durationMs),
    };

    // Context extensions (FSRS + LearningApp Ledger metadata)
    final extensions = <String, dynamic>{
      '$baseUri/xapi/ext/session-id': event.sessionId,
      '$baseUri/xapi/ext/client-seq': event.clientSeq,
      '$baseUri/xapi/ext/idempotency-key': event.idempotencyKey,
      '$baseUri/xapi/ext/payload-sha256':
          event.computeCanonicalPayloadSha256(),
    };

    if (payload.containsKey('fsrs_stability')) {
      extensions['$baseUri/xapi/ext/fsrs-stability'] =
          payload['fsrs_stability'];
    }
    if (payload.containsKey('fsrs_difficulty')) {
      extensions['$baseUri/xapi/ext/fsrs-difficulty'] =
          payload['fsrs_difficulty'];
    }
    if (payload.containsKey('fsrs_retrievability')) {
      extensions['$baseUri/xapi/ext/fsrs-retrievability'] =
          payload['fsrs_retrievability'];
    }

    final contextActivities = <String, dynamic>{};
    if (lessonId != null && itemId != null) {
      contextActivities['parent'] = [
        {
          'id': '$baseUri/activities/lessons/$lessonId',
          'definition': {
            'type': activityLesson,
            'name': {'en-US': 'Parent Lesson'},
          },
        }
      ];
    }

    return {
      'id': event.id,
      'timestamp': event.clientOccurredAt.toUtc().toIso8601String(),
      'actor': {
        'objectType': 'Agent',
        'account': {
          'homePage': baseUri,
          'name': event.userId ?? 'anonymous_${event.sessionId}',
        },
      },
      'verb': mapVerb(event.eventType),
      'object': {
        'id': activityUri,
        'definition': {
          'type': activityType,
          'name': {'en-US': activityName},
        },
      },
      'result': result,
      'context': {
        'platform': platformName,
        if (contextActivities.isNotEmpty)
          'contextActivities': contextActivities,
        'extensions': extensions,
      },
    };
  }
}


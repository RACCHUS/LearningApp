import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/lesson_progress.dart';

void main() {
  final eventDate = DateTime.utc(2026, 11, 9, 18, 30);
  UserProgress local({
    required String lessonId,
    bool completed = true,
    Map<String, dynamic>? metadata,
  }) =>
      UserProgress(
        id: 'local-event-001',
        userId: 'test-learner',
        lessonId: lessonId,
        studyMode: StudyMode.lesson,
        date: eventDate,
        questionsAnswered: 8,
        correctCount: 5,
        lessonCompleted: completed,
        studyTimeSeconds: 600,
        isSynced: false,
        metadata: metadata,
      );

  test('bundled filename IDs are typed, not cast to legacy UUID', () {
    final event = local(lessonId: 'prog_01_variables').toServerProgressEvent()!;
    expect(event['content_kind'], 'bundled_asset_lesson');
    expect(event['content_id'], 'prog_01_variables');
    expect(event['event_type'], 'lesson_completed');
    expect(event['version_key'], 'unversioned');
  });

  test('legacy lesson UUID is typed without using the local Hive ID', () {
    const lesson = 'ab100000-0000-4000-8000-000000000003';
    final event = local(lessonId: lesson).toServerProgressEvent()!;
    expect(isLegacyProgressLessonId(lesson), isTrue);
    expect(isLegacyProgressLessonId('prog_01_variables'), isFalse);
    expect(event['content_kind'], 'legacy_lesson');
    expect(event['idempotency_key'], 'local-event-001');
  });

  test('remote event excludes local counters, fake durations, user claims and metadata', () {
    final event = local(lessonId: 'prog_01_variables').toServerProgressEvent()!;
    expect(event.keys, containsAll(<String>[
      'idempotency_key', 'event_type', 'content_kind', 'content_id',
      'version_key', 'occurred_at',
    ]));
    for (final disallowed in <String>[
      'id', 'user_id', 'questions_answered', 'correct_count',
      'study_time_seconds', 'study_mode', 'is_synced', 'metadata',
    ]) {
      expect(event.containsKey(disallowed), isFalse,
          reason: 'Do not send local-only data: $disallowed');
    }
  });

  test('explicit manual uncompletion yields an audited reversal', () {
    final event = local(
      lessonId: 'prog_02_control_flow',
      completed: false,
      metadata: const {'completion_override': true},
    ).toServerProgressEvent()!;
    expect(event['event_type'], 'lesson_uncompleted');
  });

  test('ordinary partial progress is not impersonated as server evidence', () {
    expect(local(lessonId: 'prog_02_control_flow', completed: false)
        .toServerProgressEvent(), isNull);
  });

  test('projection decoder preserves unknown versus measured active seconds', () {
    final missing = userProgressFromProjection({
      'content_kind': 'bundled_asset_lesson',
      'content_id': 'prog_01_variables',
      'version_key': 'unversioned',
      'reporting_date_utc': '2026-11-09',
      'completed': true,
      'active_seconds': null,
    }, userId: 'test-learner');
    expect(missing.metadata?['active_time_measured'], isFalse);
    expect(missing.isSynced, isTrue);

    final measured = userProgressFromProjection({
      'content_kind': 'bundled_asset_lesson',
      'content_id': 'prog_01_variables',
      'version_key': 'unversioned',
      'reporting_date_utc': '2026-11-09',
      'completed': true,
      'active_seconds': 75,
    }, userId: 'test-learner');
    expect(measured.studyTimeSeconds, 75);
    expect(measured.metadata?['active_time_measured'], isTrue);
    expect(measured.id, missing.id); // Same server projection key.
  });
}

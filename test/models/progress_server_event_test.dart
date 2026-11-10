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

  test('only explicit bounded intervals are serialized as duration events', () {
    final end = DateTime.utc(2026, 11, 9, 18, 30);
    final interval = UserProgress(
      id: 'interval-uuid-key',
      userId: 'test-learner',
      lessonId: 'prog_01_variables',
      studyMode: StudyMode.lesson,
      date: end,
      questionsAnswered: 7,
      correctCount: 7,
      lessonCompleted: false,
      studyTimeSeconds: 25,
      metadata: {
        'sync_active_interval': true,
        'interval_start': end.subtract(const Duration(seconds: 25))
            .toIso8601String(),
        'interval_end': end.toIso8601String(),
        'active_time_measured': true,
      },
    );
    final event = interval.toServerProgressEvent()!;
    expect(event['event_type'], 'active_study_interval');
    expect(event['interval_start'], '2026-11-09T18:29:35.000Z');
    expect(event['interval_end'], '2026-11-09T18:30:00.000Z');
    expect(event['idempotency_key'], 'interval-uuid-key');
    for (final field in [
      'study_time_seconds', 'questions_answered', 'user_id', 'metadata',
    ]) {
      expect(event.containsKey(field), isFalse);
    }
  });

  test('unmeasured or oversized timer snapshots cannot become RPC events', () {
    final end = DateTime.utc(2026, 11, 9, 18, 30);
    UserProgress elapsed(int seconds) => UserProgress(
      id: 'interval-test',
      userId: 'test-learner',
      lessonId: 'prog_01_variables',
      studyMode: StudyMode.lesson,
      date: end,
      questionsAnswered: 0,
      correctCount: 0,
      lessonCompleted: false,
      studyTimeSeconds: seconds,
      metadata: {
        'sync_active_interval': true,
        'interval_start':
            end.subtract(Duration(seconds: seconds)).toIso8601String(),
        'interval_end': end.toIso8601String(),
      },
    );
    expect(elapsed(0).toServerProgressEvent(), isNull);
    expect(elapsed(121).toServerProgressEvent(), isNull);
    expect(elapsed(1).toServerProgressEvent()?['event_type'],
        'active_study_interval');
    expect(local(
      lessonId: 'prog_01_variables',
      completed: false,
      metadata: const {'sync_active_interval': true},
    ).toServerProgressEvent(), isNull);
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

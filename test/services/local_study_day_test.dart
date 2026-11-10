import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/lesson_progress.dart';
import 'package:learning_pwa/services/analytics/local_study_day.dart';

void main() {
  final localDay = DateTime(2026, 11, 9, 17, 0);
  final morning = DateTime(2026, 11, 9, 10, 0);

  UserProgress interval(
    DateTime start,
    DateTime end, {
    String user = 'learner',
    bool remote = false,
    bool valid = true,
  }) {
    return UserProgress(
      id: 'event-${start.microsecondsSinceEpoch}-${end.microsecondsSinceEpoch}',
      userId: user,
      lessonId: 'prog_01_variables',
      studyMode: StudyMode.lesson,
      date: end,
      questionsAnswered: 0,
      correctCount: 0,
      lessonCompleted: false,
      studyTimeSeconds: end.difference(start).inSeconds,
      metadata: {
        'sync_active_interval': valid,
        'interval_start': start.toUtc().toIso8601String(),
        'interval_end': end.toUtc().toIso8601String(),
        if (remote) 'remote_projection': true,
      },
    );
  }

  int? calculate(List<UserProgress> rows, {DateTime? day}) =>
      measuredStudySecondsForLocalDay(
        progress: rows,
        learnerId: 'learner',
        localNow: day ?? localDay,
      );

  test('no measured intervals is unknown, not zero minutes', () {
    expect(calculate([]), isNull);
    expect(calculate([
      interval(morning, morning.add(const Duration(seconds: 25)),
          valid: false),
    ]), isNull);
  });

  test('sums measured intervals and deduplicates overlapping tabs', () {
    final a = interval(morning, morning.add(const Duration(seconds: 50)));
    final b = interval(morning.add(const Duration(seconds: 30)),
        morning.add(const Duration(seconds: 70)));
    final c = interval(morning.add(const Duration(minutes: 2)),
        morning.add(const Duration(minutes: 2, seconds: 15)));
    expect(calculate([a, b, c]), 85); // 70 union + 15 separate
    expect(calculate([a, a, b, c]), 85); // replay does not double count
  });

  test('excludes other users and server UTC aggregates', () {
    final a = interval(morning, morning.add(const Duration(seconds: 25)));
    final foreign = interval(morning, morning.add(const Duration(seconds: 30)),
        user: 'another-account');
    final server = interval(morning, morning.add(const Duration(seconds: 40)),
        remote: true);
    expect(calculate([a, foreign, server]), 25);
  });

  test('splits time at learner-local midnight without claiming next day', () {
    final midnight = DateTime(2026, 11, 10);
    final a = interval(midnight.subtract(const Duration(seconds: 10)),
        midnight.add(const Duration(seconds: 10)));
    expect(calculate([a], day: DateTime(2026, 11, 9, 23, 59, 59)), 9);
    expect(calculate([a], day: DateTime(2026, 11, 10, 0, 0, 15)), 10);
  });

  test('truncates future intervals and ignores oversized fake intervals', () {
    final now = morning.add(const Duration(seconds: 12));
    final real = interval(morning, morning.add(const Duration(seconds: 25)));
    final invalid = interval(morning, morning.add(
        const Duration(minutes: 3)));
    expect(calculate([real, invalid], day: now), 12);
  });
}

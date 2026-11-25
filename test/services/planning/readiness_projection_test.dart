import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/objective_readiness.dart';
import 'package:learning_pwa/services/planning/readiness_projection.dart';

// Projected finish (ingestion plan v1.2 §8.7).
void main() {
  TargetObjectiveReadiness view(List<(String, String)> objectives, {List<double> missingDomains = const []}) =>
      TargetObjectiveReadiness.fromJson({
        'enabled': true,
        'signed_in': true,
        'domains': [
          {
            'code': 'D1',
            'title': 'D1',
            'weight_share': 1.0 - missingDomains.fold(0.0, (a, b) => a + b),
            'status': 'building',
            'objectives': [
              for (final (code, status) in objectives) {'code': code, 'title': code, 'status': status, 'checked': true},
            ],
          },
          for (final (i, share) in missingDomains.indexed)
            {'code': 'X$i', 'title': 'Missing', 'weight_share': share, 'status': 'not_available', 'objectives': []},
        ],
      })!;

  final estimates = parseStudyEstimates({
    'enabled': true,
    'objectives': [
      {'code': 'a', 'minutes_low': 60, 'minutes_high': 120},
      {'code': 'b', 'minutes_low': 40, 'minutes_high': 80},
      {'code': 'c', 'minutes_low': 30, 'minutes_high': 50},
      {'code': 'none', 'minutes_low': null, 'minutes_high': null},
      {'code': 'bad', 'minutes_low': 50, 'minutes_high': 10},
    ],
  })!;
  final now = DateTime(2026, 11, 24, 15, 30);

  test('parsing: switch off is null; missing or inconsistent estimates are dropped', () {
    expect(parseStudyEstimates({'enabled': false}), isNull);
    expect(estimates.keys, unorderedEquals(['a', 'b', 'c']));
  });

  test('strong counts as done, building as half, not started as all', () {
    final p = projectReadiness(
      view: view([('a', 'not_started'), ('b', 'building'), ('c', 'strong')]),
      estimates: estimates,
      dailyGoalMinutes: 20,
      now: now,
    )!;
    expect(p.remainingLow, 60 + 20);
    expect(p.remainingHigh, 120 + 40);
    // 80 / 20 = 4 days, 160 / 20 = 8 days, counted from the start of today.
    expect(p.finishEarliest, DateTime(2026, 11, 28));
    expect(p.finishLatest, DateTime(2026, 12, 2));
  });

  test('objectives without lessons or estimates are left out; no estimate at all is null', () {
    final p = projectReadiness(
      view: view([('a', 'not_started'), ('none', 'not_available')], missingDomains: [0.25]),
      estimates: estimates,
      dailyGoalMinutes: 30,
      now: now,
    )!;
    expect(p.remainingHigh, 120);
    expect(p.unavailableShare, 0.25);
    expect(
        projectReadiness(view: view([('none', 'not_started')]), estimates: estimates, dailyGoalMinutes: 30, now: now),
        isNull);
  });

  test('all strong means nothing left and no dates', () {
    final p = projectReadiness(
        view: view([('a', 'strong'), ('b', 'strong')]), estimates: estimates, dailyGoalMinutes: 20, now: now)!;
    expect(p.nothingLeft, isTrue);
    expect(p.finishLatest, isNull);
  });

  test('an exam date gives the minutes a day needed, and whether the plan is on track', () {
    final tight = projectReadiness(
      view: view([('a', 'not_started')]),
      estimates: estimates,
      dailyGoalMinutes: 10,
      now: now,
      examDate: DateTime(2026, 11, 30),
    )!;
    expect(tight.minutesPerDayForExam, 20); // 120 minutes over 6 days
    expect(tight.onTrackForExam, isFalse); // 12 days at 10 a day
    final easy = projectReadiness(
      view: view([('a', 'not_started')]),
      estimates: estimates,
      dailyGoalMinutes: 60,
      now: now,
      examDate: DateTime(2027, 1, 30),
    )!;
    expect(easy.onTrackForExam, isTrue);
    final past = projectReadiness(
      view: view([('a', 'not_started')]),
      estimates: estimates,
      dailyGoalMinutes: 60,
      now: now,
      examDate: DateTime(2026, 11, 1),
    )!;
    expect(past.examDate, isNull, reason: 'a past exam date is ignored');
  });

  test('a zero daily goal gives time left but no dates', () {
    final p = projectReadiness(
        view: view([('a', 'not_started')]), estimates: estimates, dailyGoalMinutes: 0, now: now)!;
    expect(p.remainingHigh, 120);
    expect(p.finishEarliest, isNull);
  });

  test('recent pace adds a second range once there is enough recent study', () {
    final p = projectReadiness(
      view: view([('a', 'not_started')]),
      estimates: estimates,
      dailyGoalMinutes: 30,
      now: now,
      recentMinutes28Days: 280, // 10 minutes a day, 70 a week
    )!;
    expect(p.recentMinutesPerWeek, 70);
    expect(p.paceEarliest, DateTime(2026, 11, 30)); // 60 / 10 = 6 days
    expect(p.paceLatest, DateTime(2026, 12, 6)); // 120 / 10 = 12 days
    final thin = projectReadiness(
      view: view([('a', 'not_started')]),
      estimates: estimates,
      dailyGoalMinutes: 30,
      now: now,
      recentMinutes28Days: minRecentMinutes - 1,
    )!;
    expect(thin.paceLatest, isNull, reason: 'under 30 minutes is too little to project from');
    expect(thin.recentMinutesPerWeek, isNull);
  });

  test('study time reads naturally', () {
    expect(formatStudyTime(45), 'about 45 minutes');
    expect(formatStudyTime(180), 'about 3 hours');
    expect(formatStudyTime(200), 'about 3.5 hours');
  });
}

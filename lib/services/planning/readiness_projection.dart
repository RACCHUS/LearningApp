import 'dart:math' as math;

import '../../models/objective_readiness.dart';

/// Estimated study time for one objective, from `get_target_study_estimates`
/// (heuristic "content-v1": reading length, practice, checks and tasks).
class StudyEstimate {
  final String code;
  final int minutesLow;
  final int minutesHigh;

  const StudyEstimate({
    required this.code,
    required this.minutesLow,
    required this.minutesHigh,
  });
}

/// Parses the estimates RPC. Null when the switch is off. Objectives without
/// lessons have no estimate and are left out (not yet available, not zero).
Map<String, StudyEstimate>? parseStudyEstimates(Map<String, dynamic> json) {
  if (json['enabled'] != true) return null;
  final out = <String, StudyEstimate>{};
  for (final o in (json['objectives'] as List? ?? const [])) {
    if (o is! Map) continue;
    final low = o['minutes_low'];
    final high = o['minutes_high'];
    if (low is! num || high is! num || low <= 0 || high < low) continue;
    final code = '${o['code'] ?? ''}';
    out[code] = StudyEstimate(
      code: code,
      minutesLow: low.round(),
      minutesHigh: high.round(),
    );
  }
  return out;
}

/// Projected finish for a target (ingestion plan v1.2 §8.7): study time left
/// on what LearningApp covers, and when the learner would get through it at
/// their daily goal. Always an estimate; pausing just moves the dates.
class ReadinessProjection {
  final int remainingLow;
  final int remainingHigh;

  /// Null when there is nothing left or no daily goal.
  final DateTime? finishEarliest;
  final DateTime? finishLatest;
  final int dailyGoalMinutes;

  /// Minutes a day needed to finish by the exam at the slower estimate; null
  /// without a future exam date.
  final int? minutesPerDayForExam;
  final DateTime? examDate;

  /// Share of the blueprint with nothing in LearningApp yet (0.0 to 1.0).
  final double unavailableShare;

  /// The learner's recent pace (active study, last 4 weeks) in minutes a
  /// week, and the finish range at that pace. Null without enough recent
  /// study to say (signed-in learners only).
  final int? recentMinutesPerWeek;
  final DateTime? paceEarliest;
  final DateTime? paceLatest;

  const ReadinessProjection({
    required this.remainingLow,
    required this.remainingHigh,
    required this.finishEarliest,
    required this.finishLatest,
    required this.dailyGoalMinutes,
    required this.minutesPerDayForExam,
    required this.examDate,
    required this.unavailableShare,
    this.recentMinutesPerWeek,
    this.paceEarliest,
    this.paceLatest,
  });

  bool get nothingLeft => remainingHigh == 0;

  /// True when the slower estimate still finishes on or before the exam.
  bool get onTrackForExam =>
      examDate != null &&
      finishLatest != null &&
      !finishLatest!.isAfter(examDate!);
}

/// Combines objective statuses and estimates. A strong objective counts as
/// done, a building one as half done, a not-started one as all to do.
/// Objectives that aren't available (or have no estimate) are left out.
ReadinessProjection? projectReadiness({
  required TargetObjectiveReadiness view,
  required Map<String, StudyEstimate> estimates,
  required int dailyGoalMinutes,
  required DateTime now,
  DateTime? examDate,
  int? recentMinutes28Days,
}) {
  var low = 0;
  var high = 0;
  var counted = 0;
  var unavailable = 0.0;
  for (final d in view.domains) {
    if (d.status == ObjectiveReadinessStatus.notAvailable) {
      unavailable += d.weightShare;
    }
    for (final o in d.objectives) {
      final e = estimates[o.code];
      if (e == null || o.status == ObjectiveReadinessStatus.notAvailable) {
        continue;
      }
      counted++;
      final share = switch (o.status) {
        ObjectiveReadinessStatus.strong => 0.0,
        ObjectiveReadinessStatus.building => 0.5,
        _ => 1.0,
      };
      low += (e.minutesLow * share).ceil();
      high += (e.minutesHigh * share).ceil();
    }
  }
  if (counted == 0) return null;

  final today = DateTime(now.year, now.month, now.day);
  DateTime? earliest;
  DateTime? latest;
  if (high > 0 && dailyGoalMinutes > 0) {
    earliest = today.add(
      Duration(days: math.max(1, (low / dailyGoalMinutes).ceil())),
    );
    latest = today.add(
      Duration(days: math.max(1, (high / dailyGoalMinutes).ceil())),
    );
  }
  // Recent pace: needs at least 30 minutes of study in the last 28 days, so
  // one short session doesn't produce a wild date.
  int? perWeek;
  DateTime? paceEarliest;
  DateTime? paceLatest;
  if (recentMinutes28Days != null &&
      recentMinutes28Days >= minRecentMinutes &&
      high > 0) {
    final perDayRecent = recentMinutes28Days / 28.0;
    perWeek = (recentMinutes28Days / 4).round();
    paceEarliest = today.add(
      Duration(days: math.max(1, (low / perDayRecent).ceil())),
    );
    paceLatest = today.add(
      Duration(days: math.max(1, (high / perDayRecent).ceil())),
    );
  }
  int? perDay;
  DateTime? exam;
  if (examDate != null) {
    exam = DateTime(examDate.year, examDate.month, examDate.day);
    final days = exam.difference(today).inDays;
    if (days > 0 && high > 0) perDay = (high / days).ceil();
    if (days <= 0) exam = null;
  }
  return ReadinessProjection(
    remainingLow: low,
    remainingHigh: high,
    finishEarliest: earliest,
    finishLatest: latest,
    dailyGoalMinutes: dailyGoalMinutes,
    minutesPerDayForExam: perDay,
    examDate: exam,
    unavailableShare: unavailable.clamp(0.0, 1.0),
    recentMinutesPerWeek: perWeek,
    paceEarliest: paceEarliest,
    paceLatest: paceLatest,
  );
}

/// Minimum active study in the last 28 days before a recent pace is shown.
const minRecentMinutes = 30;

/// "about 40 minutes", "about 3 hours", "about 3.5 hours".
String formatStudyTime(int minutes) {
  if (minutes < 90) return 'about $minutes minutes';
  final halfHours = (minutes / 30).round();
  final hours = halfHours / 2;
  final text = hours == hours.roundToDouble()
      ? hours.toStringAsFixed(0)
      : hours.toStringAsFixed(1);
  return 'about $text hours';
}

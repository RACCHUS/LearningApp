import 'package:learning_pwa/models/lesson_progress.dart';

/// Count only locally measured active intervals that overlap the learner's
/// *local calendar day*. No UTC daily aggregate is assumed to match a local
/// day, and remote progress snapshots are excluded to avoid double counting.
///
/// Returns null if this device has no reliable measured intervals for the day.
/// This value is a partial *this-device* estimate, never a cross-device total.
int? measuredStudySecondsForLocalDay({
  required Iterable<UserProgress> progress,
  required String learnerId,
  required DateTime localNow,
}) {
  // Construct next local midnight by calendar date; adding 24 hours is wrong
  // when a day crosses a daylight-saving change.
  final dayStart =
      DateTime(localNow.year, localNow.month, localNow.day).toUtc();
  final dayEnd =
      DateTime(localNow.year, localNow.month, localNow.day + 1).toUtc();
  final current = localNow.toUtc();
  final spans = <({DateTime start, DateTime end})>[];

  for (final item in progress) {
    if (item.userId != learnerId ||
        item.metadata?['sync_active_interval'] != true ||
        item.metadata?['remote_projection'] == true) {
      continue;
    }
    // Reuse the same allowlist and duration bounds used for RPC ingestion.
    final event = item.toServerProgressEvent();
    if (event?['event_type'] != 'active_study_interval') continue;
    final start = DateTime.tryParse(event!['interval_start'] as String)?.toUtc();
    final end = DateTime.tryParse(event['interval_end'] as String)?.toUtc();
    if (start == null || end == null ||
        !end.isAfter(dayStart) || !dayEnd.isAfter(start)) {
      continue;
    }
    final clippedStart = start.isAfter(dayStart) ? start : dayStart;
    var clippedEnd = end.isBefore(dayEnd) ? end : dayEnd;
    if (current.isBefore(clippedEnd)) clippedEnd = current;
    if (!clippedEnd.isAfter(clippedStart)) continue;
    spans.add((start: clippedStart, end: clippedEnd));
  }

  if (spans.isEmpty) return null;
  spans.sort((a, b) => a.start.compareTo(b.start));

  var start = spans.first.start;
  var end = spans.first.end;
  var total = 0;
  for (final next in spans.skip(1)) {
    if (next.start.isAfter(end)) {
      total += end.difference(start).inSeconds;
      start = next.start;
      end = next.end;
    } else if (next.end.isAfter(end)) {
      end = next.end;
    }
  }
  total += end.difference(start).inSeconds;
  return total;
}

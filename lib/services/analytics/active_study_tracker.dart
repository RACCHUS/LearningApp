/// Conservative foreground lesson-time estimator.
 ///
 /// This is NOT a timer of time-on-page or proof of learning. A span can be
 /// counted only after explicit interaction and while the lesson is visible.
 /// A stalled browser timer / suspended tab never retroactively earns time.
 ///
 /// The server independently validates, caps, deduplicates and unions accepted
 /// intervals; this tracker does not authorize arbitrary client durations.
class ActiveStudyInterval {
  final DateTime start;
  final DateTime end;

  ActiveStudyInterval(DateTime start, DateTime end)
      : start = start.toUtc(),
        end = end.toUtc() {
    if (!this.end.isAfter(this.start) ||
        this.end.difference(this.start) > ActiveStudyTracker.maxEventDuration) {
      throw ArgumentError('An active-study interval must be 1–60 seconds');
    }
  }

  int get seconds => end.difference(start).inSeconds;
}

class ActiveStudyTracker {
  /// A reader can spend up to one minute after their last gesture reading,
  /// without needing to tap or scroll continuously.
  static const Duration idleLimit = Duration(seconds: 60);

  /// Background/suspended timers are never allowed to fill an arbitrary gap.
  static const Duration maxTickGap = Duration(seconds: 20);

  /// Under the RPC's 120-second maximum; also keeps offline events bounded.
  static const Duration maxEventDuration = Duration(seconds: 60);

  DateTime? _lastTick;
  DateTime? _lastInteraction;
  DateTime? _openStart;
  DateTime? _openEnd;
  bool _foreground = false;

  bool get isForeground => _foreground;

  /// Enter a visible lesson. No time is counted before the first interaction.
  void resume(DateTime at) {
    _foreground = true;
    _lastTick = at.toUtc();
    _lastInteraction = null;
    _openStart = null;
    _openEnd = null;
  }

  /// Signals a genuine pointer, scroll, keyboard or accessible UI interaction.
  /// Does not count the time before the first signal or an idle gap.
  List<ActiveStudyInterval> interaction(DateTime at) {
    final timestamp = at.toUtc();
    final events = _advance(timestamp);
    if (_foreground) {
      _lastInteraction = timestamp;
      _lastTick = timestamp;
    }
    return events;
  }

  /// Called on a lightweight periodic timer (suggested: every 10 seconds).
  List<ActiveStudyInterval> tick(DateTime at) => _advance(at.toUtc());

  /// Browser hidden, mobile paused, screen popped or account switched.
  /// Only already-observed foreground time is returned; no late estimate.
  List<ActiveStudyInterval> pause(DateTime at) {
    final events = _advance(at.toUtc());
    _flush(events);
    _foreground = false;
    _lastTick = null;
    _lastInteraction = null;
    return events;
  }

  List<ActiveStudyInterval> _advance(DateTime at) {
    final events = <ActiveStudyInterval>[];
    if (!_foreground || _lastTick == null) return events;
    final previous = _lastTick!;
    final gap = at.difference(previous);
    _lastTick = at;

    // The browser may throttle timers or the clock may jump. Do not invent
    // elapsed time to fill a missing observation (even if the tab looks active).
    if (gap <= Duration.zero || gap > maxTickGap) {
      _flush(events);
      // A discontinuity may represent sleep, visibility loss or clock drift.
      // Require fresh learner input before any additional time is credited.
      _lastInteraction = null;
      return events;
    }
    final interaction = _lastInteraction;
    if (interaction == null || interaction.isAfter(previous)) return events;

    final expires = interaction.add(idleLimit);
    if (!expires.isAfter(previous)) {
      _flush(events);
      return events;
    }
    final end = at.isBefore(expires) ? at : expires;
    if (end.isAfter(previous)) _append(previous, end, events);
    if (!end.isAfter(at) && !expires.isAfter(at)) _flush(events);
    return events;
  }

  void _append(DateTime start, DateTime end, List<ActiveStudyInterval> events) {
    var cursor = start;
    while (end.isAfter(cursor)) {
      if (_openStart == null || _openEnd != cursor) {
        _flush(events);
        _openStart = cursor;
        _openEnd = cursor;
      }

      final boundary = _openStart!.add(maxEventDuration);
      final next = end.isBefore(boundary) ? end : boundary;
      _openEnd = next;
      cursor = next;
      if (!cursor.isBefore(boundary)) _flush(events);
    }
  }

  void _flush(List<ActiveStudyInterval> events) {
    final start = _openStart;
    final end = _openEnd;
    if (start != null && end != null &&
        end.difference(start) >= const Duration(seconds: 1)) {
      events.add(ActiveStudyInterval(start, end));
    }
    _openStart = null;
    _openEnd = null;
  }
}

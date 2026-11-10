import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/analytics/active_study_tracker.dart';

void main() {
  final origin = DateTime.utc(2026, 11, 9, 18, 0, 0);
  DateTime at(int seconds) => origin.add(Duration(seconds: seconds));
  int total(List<ActiveStudyInterval> events) =>
      events.fold(0, (sum, interval) => sum + interval.seconds);

  group('ANA-003 active study time', () {
    test('does not count open tab before learner interaction', () {
      final tracker = ActiveStudyTracker()..resume(at(0));
      final events = <ActiveStudyInterval>[
        ...tracker.tick(at(10)),
        ...tracker.tick(at(20)),
        ...tracker.pause(at(25)),
      ];
      expect(total(events), 0);
    });

    test('counts only observed foreground seconds with real signals', () {
      final tracker = ActiveStudyTracker()..resume(at(0));
      tracker.interaction(at(1));
      final events = <ActiveStudyInterval>[
        ...tracker.tick(at(11)),
        ...tracker.tick(at(21)),
        ...tracker.interaction(at(26)),
        ...tracker.tick(at(36)),
        ...tracker.pause(at(41)),
      ];
      // First 25 seconds after interaction + 15 more.
      expect(total(events), 40);
      expect(events, hasLength(1));
      expect(events.single.start, at(1));
      expect(events.single.end, at(41));
    });

    test('same-timestamp pointer signal and timer tick do not cancel reading', () {
      final tracker = ActiveStudyTracker()..resume(at(0));
      tracker.interaction(at(0));
      tracker.tick(at(10));
      tracker.interaction(at(10)); // Same timestamp as next scheduled sample.
      tracker.tick(at(10));
      tracker.tick(at(20));
      final events = tracker.pause(at(25));
      expect(total(events), 25);
    });

    test('idle timeout stops the clock even if lesson is still visible', () {
      final tracker = ActiveStudyTracker()..resume(at(0));
      tracker.interaction(at(0));
      final events = <ActiveStudyInterval>[];
      for (final second in [10, 20, 30, 40, 50, 60, 70, 80]) {
        events.addAll(tracker.tick(at(second)));
      }
      events.addAll(tracker.pause(at(90)));
      expect(total(events), 60);
      expect(events, hasLength(1));
    });

    test('a suspended timer never backfills the hidden gap', () {
      final tracker = ActiveStudyTracker()..resume(at(0));
      tracker.interaction(at(0));
      final events = <ActiveStudyInterval>[
        ...tracker.tick(at(10)),
        ...tracker.tick(at(150)), // throttled or suspended browser
        ...tracker.pause(at(155)),
      ];
      expect(total(events), 10);
      expect(events.single.end, at(10));
    });

    test('background pause flushes, resume needs another interaction', () {
      final tracker = ActiveStudyTracker()..resume(at(0));
      tracker.interaction(at(0));
      final events = <ActiveStudyInterval>[
        ...tracker.tick(at(10)),
        ...tracker.pause(at(15)),
      ];
      tracker.resume(at(90));
      events.addAll(tracker.tick(at(100)));
      tracker.interaction(at(105));
      events.addAll(tracker.tick(at(115)));
      events.addAll(tracker.pause(at(120)));
      expect(total(events), 30);
      expect(events, hasLength(2));
      expect(events.last.start, at(105));
    });

    test('long reads are sliced into <=60 second RPC-safe intervals', () {
      final tracker = ActiveStudyTracker()..resume(at(0));
      tracker.interaction(at(0));
      final events = <ActiveStudyInterval>[];
      for (var i = 10; i <= 160; i += 10) {
        if (i % 40 == 0) events.addAll(tracker.interaction(at(i)));
        events.addAll(tracker.tick(at(i)));
      }
      events.addAll(tracker.pause(at(165)));
      expect(total(events), 165);
      expect(events.length, greaterThanOrEqualTo(3));
      expect(events.every((event) => event.seconds > 0 && event.seconds <= 60),
          isTrue);
    });

    test('clock moving backwards produces no fabricated seconds', () {
      final tracker = ActiveStudyTracker()..resume(at(0));
      tracker.interaction(at(0));
      final events = <ActiveStudyInterval>[
        ...tracker.tick(at(10)),
        ...tracker.tick(at(5)),
        ...tracker.pause(at(6)),
      ];
      expect(total(events), 10);
      expect(events, hasLength(1));
      expect(events.single.end, at(10));
    });

    test('intervals preserve UTC midnight boundary for server union', () {
      final tracker = ActiveStudyTracker()
        ..resume(DateTime.utc(2026, 11, 9, 23, 59, 45));
      tracker.interaction(DateTime.utc(2026, 11, 9, 23, 59, 45));
      tracker.tick(DateTime.utc(2026, 11, 9, 23, 59, 55));
      final events =
          tracker.pause(DateTime.utc(2026, 11, 10, 0, 0, 5));
      expect(total(events), 20);
      expect(events.single.start.day, 9);
      expect(events.single.end.day, 10);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/daily_goal_provider.dart';

void main() {
  group('ANA-003 trustworthy daily goal display', () {
    test('unknown study duration does not count as zero or goal complete', () {
      final goal = DailyGoalProgress(
        studyMinutesToday: 0,
        goalMinutes: 30,
        isStudyTimeAvailable: false,
      );
      expect(goal.isStudyTimeAvailable, isFalse);
      expect(goal.formattedTime, '—');
      expect(goal.goalMet, isFalse);
      expect(goal.progress, 0);
    });

    test('measured positive durations keep normal formatting', () {
      final goal = DailyGoalProgress(studyMinutesToday: 91, goalMinutes: 90);
      expect(goal.isStudyTimeAvailable, isTrue);
      expect(goal.formattedTime, '1h 31m');
      expect(goal.goalMet, isTrue);
      expect(goal.progress, 1);
    });

    test('measured sub-minute activity is not displayed as a false zero', () {
      final goal = DailyGoalProgress(
        studyMinutesToday: 0,
        studySecondsToday: 30,
        goalMinutes: 1,
      );
      expect(goal.formattedTime, '<1m');
      expect(goal.progress, closeTo(0.5, 0.001));
      expect(goal.goalMet, isFalse);
    });

    test('empty placeholder is explicitly unavailable', () {
      final goal = DailyGoalProgress.empty();
      expect(goal.isStudyTimeAvailable, isFalse);
      expect(goal.formattedTime, '—');
      expect(goal.goalMet, isFalse);
    });
  });
}

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

    test('empty placeholder is explicitly unavailable', () {
      final goal = DailyGoalProgress.empty();
      expect(goal.isStudyTimeAvailable, isFalse);
      expect(goal.formattedTime, '—');
      expect(goal.goalMet, isFalse);
    });
  });
}

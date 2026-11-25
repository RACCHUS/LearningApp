import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/models/objective_readiness.dart';
import 'package:learning_pwa/providers/daily_goal_provider.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/target_readiness_provider.dart';

// The projection uses the learner's exam date. LearningContext equality is by
// id, so a changed exam date doesn't notify dependents on its own: the daily
// plan card invalidates the projection after saving a date (found in the
// browser on 2026-11-24).
class _Estimates implements StudyEstimatesApi {
  @override
  Future<Map<String, dynamic>?> fetch(String targetVersionId) async => {
        'enabled': true,
        'objectives': [
          {'code': 'a', 'minutes_low': 60, 'minutes_high': 300},
        ],
      };
}

void main() {
  test('after the card invalidates it, the projection uses the new exam date', () async {
    final ctx = StateProvider<LearningContext?>((ref) => LearningContext(
          id: 'c1',
          userId: 'local-user',
          label: 'Target',
          rootType: ContextRootType.target,
          rootId: 't1',
          lastActiveAt: DateTime(2026, 11, 24),
          targetVersionId: 'v1',
        ));
    final container = ProviderContainer(overrides: [
      readinessProjectionEnabledProvider.overrideWithValue(true),
      objectiveReadinessProvider('v1').overrideWith((ref) async => TargetObjectiveReadiness.fromJson({
            'enabled': true,
            'domains': [
              {
                'code': 'D',
                'title': 'D',
                'weight_share': 1,
                'status': 'not_started',
                'objectives': [
                  {'code': 'a', 'title': 'a', 'status': 'not_started', 'checked': true},
                ],
              },
            ],
          })),
      studyEstimatesApiProvider.overrideWithValue(_Estimates()),
      dailyGoalMinutesProvider.overrideWith((ref) async => 10),
      activeLearningContextProvider.overrideWith((ref) => ref.watch(ctx)),
    ]);
    addTearDown(container.dispose);
    final sub = container.listen(readinessProjectionProvider('v1'), (_, __) {});
    addTearDown(sub.close);

    final before = await container.read(readinessProjectionProvider('v1').future);
    expect(before!.examDate, isNull);

    final exam = DateTime.now().add(const Duration(days: 10));
    container.read(ctx.notifier).update((c) => c!.copyWith(scopeConfig: {'examDate': exam.toIso8601String()}));
    container.invalidate(readinessProjectionProvider);
    final after = await container.read(readinessProjectionProvider('v1').future);
    expect(after!.examDate, isNotNull);
    expect(after.minutesPerDayForExam, 30); // 300 minutes over 10 days
  });
}

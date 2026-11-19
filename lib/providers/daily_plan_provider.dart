import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/daily_plan.dart';
import 'package:learning_pwa/models/settings_model.dart';
import 'package:learning_pwa/providers/daily_goal_provider.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/next_action_provider.dart';
import 'package:learning_pwa/services/daily_plan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kReviewEmphasisKey = 'reviewEmphasis';

final dailyPlanServiceProvider = Provider<DailyPlanService>((ref) {
  return const DailyPlanService();
});

class ReviewEmphasisNotifier extends StateNotifier<ReviewEmphasis> {
  ReviewEmphasisNotifier() : super(ReviewEmphasis.balanced) {
    load();
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final direct = prefs.getString(kReviewEmphasisKey);
      if (direct != null) {
        state = ReviewEmphasis.values.firstWhere(
          (e) => e.name == direct,
          orElse: () => ReviewEmphasis.balanced,
        );
        return;
      }
      final rawSettings = prefs.getString('settings');
      if (rawSettings != null) {
        final settings = SettingsModel.fromRawJson(rawSettings);
        state = settings.reviewEmphasis;
      }
    } catch (_) {
      // Default to balanced
    }
  }

  Future<void> setEmphasis(ReviewEmphasis emphasis) async {
    state = emphasis;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kReviewEmphasisKey, emphasis.name);
      final raw = prefs.getString('settings');
      if (raw != null) {
        final settings = SettingsModel.fromRawJson(raw);
        settings.reviewEmphasis = emphasis;
        await prefs.setString('settings', settings.toRawJson());
      }
    } catch (_) {}
  }
}

final reviewEmphasisProvider =
    StateNotifierProvider<ReviewEmphasisNotifier, ReviewEmphasis>((ref) {
  return ReviewEmphasisNotifier();
});

/// Computes the active daily plan for the learner.
final dailyPlanProvider = FutureProvider<DailyPlan>((ref) async {
  final service = ref.watch(dailyPlanServiceProvider);
  final activeContext = ref.watch(activeLearningContextProvider);
  final emphasis = ref.watch(reviewEmphasisProvider);
  final targetDailyMinutes = await ref.watch(dailyGoalMinutesProvider.future);

  if (activeContext == null) {
    return service.computeDailyPlan(
      dueCount: 0,
      totalContextItems: 0,
      completedContextItems: 0,
      emphasis: emphasis,
      targetDailyMinutes: targetDailyMinutes,
    );
  }

  final snapshotResolver = ref.watch(contextSnapshotResolverProvider);
  final snapshot = await snapshotResolver.resolve(activeContext);

  // Check for examDate or targetDate in scopeConfig
  DateTime? examDate;
  final rawExamDate = activeContext.scopeConfig['examDate'] ??
      activeContext.scopeConfig['targetDate'];
  if (rawExamDate is String && rawExamDate.isNotEmpty) {
    examDate = DateTime.tryParse(rawExamDate);
  }

  return service.computeDailyPlan(
    dueCount: snapshot.dueCount,
    totalContextItems: snapshot.totalActivityCount,
    completedContextItems: snapshot.completedOfficialRequiredCount,
    emphasis: emphasis,
    targetDailyMinutes: targetDailyMinutes,
    examDate: examDate,
  );
});


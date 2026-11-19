import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/governance/site_feature_keys.dart';
import 'package:learning_pwa/providers/site_feature_provider.dart';
import 'package:learning_pwa/services/governance/site_feature_service.dart';
import 'package:learning_pwa/services/study_reminder_service.dart';

/// `learning.study_reminders`. Default OFF and fails closed. A UI hint only:
/// every save/register RPC and the dispatcher re-check it on the server.
final studyRemindersEnabledProvider = Provider<bool>((ref) {
  return isSiteFeatureEnabled(
    ref.watch(siteFeatureSnapshotProvider).valueOrNull,
    SiteFeatureKeys.learningStudyReminders,
    runtimeReady: SiteFeatureRuntime.snapshotEnabled,
  );
});

/// Public VAPID key: `--dart-define=WEB_PUSH_VAPID_PUBLIC_KEY=...`, else the
/// same key in `.env`. It is a public key; the private half stays in the Edge
/// Function secrets. Empty means this deployment cannot deliver reminders.
final webPushVapidPublicKeyProvider = Provider<String>((ref) {
  const defined = String.fromEnvironment('WEB_PUSH_VAPID_PUBLIC_KEY');
  if (defined.isNotEmpty) return defined;
  try {
    return dotenv.isInitialized
        ? (dotenv.env['WEB_PUSH_VAPID_PUBLIC_KEY'] ?? '').trim()
        : '';
  } catch (_) {
    return '';
  }
});

final studyReminderServiceProvider = Provider<StudyReminderService>(
  (ref) => StudyReminderService(),
);

final webPushClientProvider = Provider<WebPushClient>(
  (ref) => const WebPushClient(),
);

final studyRemindersProvider =
    FutureProvider.autoDispose<List<StudyReminder>>((ref) {
  return ref.watch(studyReminderServiceProvider).list();
});

/// This browser's push subscription, if it has one.
final browserPushSubscriptionProvider =
    FutureProvider.autoDispose<WebPushSubscription?>((ref) {
  return ref.watch(webPushClientProvider).current();
});

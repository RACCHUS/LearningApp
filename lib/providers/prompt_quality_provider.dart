import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/governance/site_feature_keys.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/providers/site_feature_provider.dart';
import 'package:learning_pwa/services/analytics/prompt_quality_reporter.dart';
import 'package:learning_pwa/services/governance/site_feature_service.dart';

/// `analytics.prompt_quality`: the client switch. The server re-checks it
/// together with eligibility, base analytics consent and the extra opt-in.
final promptQualityEnabledProvider = Provider<bool>((ref) {
  return isSiteFeatureEnabled(
    ref.watch(siteFeatureSnapshotProvider).valueOrNull,
    SiteFeatureKeys.analyticsPromptQuality,
    runtimeReady: SiteFeatureRuntime.snapshotEnabled,
  );
});

final promptQualityApiProvider = Provider<PromptQualityApi>(
  (ref) => SupabasePromptQualityApi(),
);

/// Whether to show the opt-in and whether to send. Off for guests and
/// whenever the server cannot be asked. Signed-in accounts are asked even
/// while the switch is off, so an earlier opt-in can still be withdrawn.
final promptQualityStatusProvider = FutureProvider<PromptQualityStatus>((
  ref,
) async {
  ref.watch(promptQualityEnabledProvider);
  final auth = ref.watch(authProvider);
  if (auth is! AuthSuccess || auth.user.isAnonymous) {
    return PromptQualityStatus.off;
  }
  try {
    return await ref.watch(promptQualityApiProvider).status();
  } catch (e) {
    debugPrint('Prompt-quality status unavailable: $e');
    return PromptQualityStatus.off;
  }
});

/// Sends one checked-reply event if, and only if, the learner opted in.
/// Never throws and never affects generation.
final promptQualityReporterProvider =
    Provider<Future<void> Function(PromptQualityEvent)>((ref) {
      return (event) async {
        try {
          final status = await ref.read(promptQualityStatusProvider.future);
          if (!status.enabled || !status.consented) return;
          await ref.read(promptQualityApiProvider).record([event]);
        } catch (_) {
          // Telemetry must never affect learning.
        }
      };
    });

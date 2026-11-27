import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/providers/product_telemetry_provider.dart';
import 'package:learning_pwa/services/analytics/product_analytics_privacy_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Server privacy status when analytics is switched on and someone is
/// signed in; `null` otherwise or on any error (the card then stays away).
final analyticsOptInStatusProvider =
    FutureProvider.autoDispose<ProductAnalyticsPrivacyStatus?>((ref) async {
      if (!ref.watch(productAnalyticsEnabledProvider)) return null;
      try {
        return await ref.watch(productAnalyticsPrivacyServiceProvider).status();
      } catch (_) {
        return null;
      }
    });

/// A plain-language, dismissible invitation to the optional analytics.
/// Shown only when the server says this account can opt in and has not.
/// It never opts anyone in: "Review" opens the privacy screen, where the
/// learner confirms explicitly.
class AnalyticsOptInCard extends ConsumerStatefulWidget {
  const AnalyticsOptInCard({super.key});

  static const dismissedKey = 'analytics_opt_in_card_dismissed_v1';

  @override
  ConsumerState<AnalyticsOptInCard> createState() => _AnalyticsOptInCardState();
}

class _AnalyticsOptInCardState extends ConsumerState<AnalyticsOptInCard> {
  bool? _dismissed;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance()
        .then((p) => p.getBool(AnalyticsOptInCard.dismissedKey) ?? false)
        .catchError((_) => false)
        .then((d) {
          if (mounted) setState(() => _dismissed = d);
        });
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(AnalyticsOptInCard.dismissedKey, true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed != false) return const SizedBox.shrink();
    final status = ref.watch(analyticsOptInStatusProvider).valueOrNull;
    if (status == null || !status.canOptIn || status.consented) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Card(
      key: const Key('analytics_opt_in_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Help improve LearningApp (optional)',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            const Text(
              'If you opt in, we record which main screens you open and '
              'which lessons you start, linked to your account. We never '
              'record your answers, what you type, AI replies or lesson '
              'content, or the names or links of what you study outside '
              'LearningApp. You can withdraw at any time, which deletes '
              'what was recorded.',
            ),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonal(
                  key: const Key('analytics_opt_in_review'),
                  onPressed: () => context.push('/settings/privacy/analytics'),
                  child: const Text('Review and decide'),
                ),
                TextButton(
                  key: const Key('analytics_opt_in_dismiss'),
                  onPressed: _dismiss,
                  child: const Text('No thanks'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

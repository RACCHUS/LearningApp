import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/governance/site_feature_keys.dart';
import 'package:learning_pwa/providers/site_feature_provider.dart';
import 'package:learning_pwa/services/analytics/product_analytics_privacy_service.dart';
import 'package:learning_pwa/services/analytics/product_event.dart';
import 'package:learning_pwa/services/analytics/product_event_outbox.dart';
import 'package:learning_pwa/services/analytics/product_event_rpc_sink.dart';
import 'package:learning_pwa/services/analytics/product_telemetry.dart';
import 'package:learning_pwa/services/governance/site_feature_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// `analytics.product_events`: the client switch. The database release
/// gate, per-account eligibility and each person's opt-in are checked
/// separately on the server.
final productAnalyticsEnabledProvider = Provider<bool>((ref) {
  return isSiteFeatureEnabled(
    ref.watch(siteFeatureSnapshotProvider).valueOrNull,
    SiteFeatureKeys.analyticsProductEvents,
    runtimeReady: SiteFeatureRuntime.snapshotEnabled,
  );
});

final productAnalyticsPrivacyServiceProvider =
    Provider<ProductAnalyticsPrivacyService>(
      (ref) => ProductAnalyticsPrivacyService(),
    );

/// The app-wide telemetry facade. Outside a signed-in permanent session,
/// or before Supabase is ready, it records nothing.
final productTelemetryProvider = Provider<ProductTelemetry>((ref) {
  SupabaseClient? client() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  final telemetry = ProductTelemetry(
    enabled: () => ref.read(productAnalyticsEnabledProvider),
    currentUserId: () => client()?.auth.currentUser?.id,
    isGuest: () => client()?.auth.currentUser?.isAnonymous != false,
    fetchPrivacy: () =>
        ref.read(productAnalyticsPrivacyServiceProvider).status(),
    outbox: (privacy) => ProductEventOutbox(
      sender: AckedProductEventSink((events) async {
        final c = client();
        if (c == null) throw StateError('Supabase unavailable');
        return c.rpc('record_product_events', params: {'p_events': events});
      }),
      getPrivacy: privacy,
      currentUserId: () => client()?.auth.currentUser?.id,
    ),
  );
  ref.onDispose(telemetry.dispose);
  return telemetry;
});

/// Records `surface_viewed` when the main destination changes, and the app
/// session start once. Purely observational: renders [child] unchanged, and
/// does nothing where there is no ProviderScope (it must never be able to
/// break navigation).
class SurfaceTelemetry extends StatefulWidget {
  const SurfaceTelemetry({
    super.key,
    required this.surface,
    required this.child,
  });

  /// `learn`, `library` or `progress`.
  final String surface;
  final Widget child;

  @override
  State<SurfaceTelemetry> createState() => _SurfaceTelemetryState();
}

class _SurfaceTelemetryState extends State<SurfaceTelemetry> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _record(first: true));
  }

  @override
  void didUpdateWidget(SurfaceTelemetry old) {
    super.didUpdateWidget(old);
    if (old.surface != widget.surface) _record();
  }

  void _record({bool first = false}) {
    if (!mounted) return;
    try {
      final t = ProviderScope.containerOf(
        context,
        listen: false,
      ).read(productTelemetryProvider);
      if (first) t.sessionStarted(widget.surface);
      t.track(ProductEventKind.surfaceViewed, {'surface': widget.surface});
    } catch (_) {
      // No ProviderScope (isolated widget tests) or not ready: skip.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

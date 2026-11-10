import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/site_feature_provider.dart';
import 'package:learning_pwa/services/governance/site_feature_service.dart';

/// Production-router-only lifecycle refresh. No polling, timers or network
/// calls while the registry bootstrap is disabled. Keeps AppShell portable
/// for legacy UI tests, embeds and institution forks.
class SiteFeatureRefreshObserver extends ConsumerStatefulWidget {
  final Widget child;
  const SiteFeatureRefreshObserver({super.key, required this.child});

  @override
  ConsumerState<SiteFeatureRefreshObserver> createState() =>
      _SiteFeatureRefreshObserverState();
}

class _SiteFeatureRefreshObserverState
    extends ConsumerState<SiteFeatureRefreshObserver>
    with WidgetsBindingObserver {
  DateTime? _lastRefreshAt;

  @override
  void initState() {
    super.initState();
    if (SiteFeatureRuntime.snapshotEnabled) {
      WidgetsBinding.instance.addObserver(this);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!SiteFeatureRuntime.snapshotEnabled ||
        state != AppLifecycleState.resumed ||
        !mounted) {
      return;
    }
    // Refresh only on an app return and at most every two minutes.
    // All security-sensitive backend operations must separately check the
    // server gate; this cached snapshot only influences presentation.
    final now = DateTime.now();
    if (_lastRefreshAt != null &&
        now.difference(_lastRefreshAt!) < const Duration(minutes: 2)) {
      return;
    }
    _lastRefreshAt = now;
    ref.invalidate(siteFeatureSnapshotProvider);
  }

  @override
  void dispose() {
    if (SiteFeatureRuntime.snapshotEnabled) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

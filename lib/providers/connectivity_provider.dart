import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/supabase_health_provider.dart';
import 'package:learning_pwa/services/connectivity_service.dart';
import 'package:learning_pwa/services/supabase_health_service.dart';
import 'package:learning_pwa/theme/semantic_colors.dart';

final connectivityProvider = StateNotifierProvider<ConnectivityNotifier, bool>((ref) {
  final connectivityService = ref.watch(connectivityServiceProvider);
  return ConnectivityNotifier(connectivityService);
});

class ConnectivityNotifier extends StateNotifier<bool> {
  final ConnectivityService _connectivityService;
  StreamSubscription<bool>? _subscription;
  
  ConnectivityNotifier(this._connectivityService) : super(true) {
    _init();
  }
  
  Future<void> _init() async {
    // Initial state
    state = await _connectivityService.isConnected;
    
    // Listen for changes
    _subscription = _connectivityService.onConnectivityChanged.listen((isConnected) {
      if (state != isConnected) {
        state = isConnected;
      }
    });
  }
  
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

class ConnectivityAware extends ConsumerWidget {
  final Widget child;
  
  const ConnectivityAware({
    Key? key,
    required this.child,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(connectivityProvider);
    final supabaseStatus = ref.watch(supabaseHealthProvider);
    final semantic = Theme.of(context).extension<SemanticColors>()!;

    // Device offline takes precedence over backend-unreachable messaging.
    final Widget banner;
    if (!isConnected) {
      banner = _StatusBanner(
        key: ValueKey('offline'),
        color: semantic.warning,
        foregroundColor: semantic.onWarning,
        message:
            'You are offline. Your progress is saved on this device and will '
            'sync when you reconnect.',
        icon: Icons.cloud_off,
      );
    } else if (supabaseStatus == SupabaseStatus.unreachable) {
      banner = _StatusBanner(
        key: const ValueKey('unreachable'),
        color: semantic.danger,
        foregroundColor: semantic.onDanger,
        message:
            "Can't reach the server right now — it may be temporarily "
            'unavailable. Your work is saved locally and will sync '
            'automatically once it is back.',
        icon: Icons.cloud_off,
        onRetry: () => ref.read(supabaseHealthProvider.notifier).refresh(),
      );
    } else {
      banner = const SizedBox.shrink(key: ValueKey('none'));
    }

    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: banner,
          ),
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    super.key,
    required this.color,
    required this.foregroundColor,
    required this.message,
    required this.icon,
    this.onRetry,
  });

  final Color color;
  final Color foregroundColor;
  final String message;
  final IconData icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      child: SafeArea(
        bottom: false,
        child: Semantics(
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(icon, color: foregroundColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(color: foregroundColor),
                  ),
                ),
                if (onRetry != null)
                  TextButton(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      foregroundColor: foregroundColor,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Retry'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

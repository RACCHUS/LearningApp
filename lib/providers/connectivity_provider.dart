import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/services/connectivity_service.dart';

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
    
    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: isConnected
                ? const SizedBox.shrink()
                : Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.orange,
                    child: const Center(
                      child: Text(
                        'You are currently offline. Some features may be limited.',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

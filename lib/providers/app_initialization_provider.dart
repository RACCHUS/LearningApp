import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:learning_pwa/providers/hands_free_settings_provider.dart';
import 'package:learning_pwa/providers/global_voice_provider.dart';

/// Provider for managing app initialization tasks like auto-enabling voice
final appInitializationProvider = StateNotifierProvider<AppInitializationNotifier, AppInitializationState>((ref) {
  return AppInitializationNotifier(ref);
});

class AppInitializationState {
  final bool isInitialized;
  final bool autoEnableCompleted;
  final String? error;

  const AppInitializationState({
    this.isInitialized = false,
    this.autoEnableCompleted = false,
    this.error,
  });

  AppInitializationState copyWith({
    bool? isInitialized,
    bool? autoEnableCompleted,
    String? error,
  }) {
    return AppInitializationState(
      isInitialized: isInitialized ?? this.isInitialized,
      autoEnableCompleted: autoEnableCompleted ?? this.autoEnableCompleted,
      error: error ?? this.error,
    );
  }
}

class AppInitializationNotifier extends StateNotifier<AppInitializationState> {
  final Ref _ref;

  AppInitializationNotifier(this._ref) : super(const AppInitializationState());

  /// Initialize app-level features after providers are ready
  Future<void> initialize() async {
    if (state.isInitialized) return;

    try {
      if (kDebugMode) {
        print('🚀 Starting app initialization...');
      }

      // Wait for hands-free settings to be loaded
      await _initializeHandsFreeSettings();

      // Check if we should auto-enable global voice
      await _handleAutoEnableGlobalVoice();

      state = state.copyWith(
        isInitialized: true,
        autoEnableCompleted: true,
      );

      if (kDebugMode) {
        print('✅ App initialization completed successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ App initialization failed: $e');
      }
      state = state.copyWith(
        error: e.toString(),
        isInitialized: true, // Mark as initialized even on error to prevent retry loops
      );
    }
  }

  /// Initialize hands-free settings
  Future<void> _initializeHandsFreeSettings() async {
    try {
      if (kDebugMode) {
        print('🔧 Initializing hands-free settings...');
      }

      // Force initialization of hands-free settings provider
      // The provider will auto-initialize when first accessed
      final settings = _ref.read(handsFreeSettingsProvider);
      
      if (kDebugMode) {
        print('✅ Hands-free settings initialized');
        print('   - Default hands-free mode: ${settings.defaultHandsFreeMode}');
        print('   - Global voice commands: ${settings.globalVoiceCommands}');
        print('   - Auto lesson hands-free: ${settings.autoLessonHandsFree}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to initialize hands-free settings: $e');
      }
      rethrow;
    }
  }

  /// Handle auto-enabling global voice based on settings
  Future<void> _handleAutoEnableGlobalVoice() async {
    try {
      // Get hands-free settings
      final settings = _ref.read(handsFreeSettingsProvider);
      final settingsService = _ref.read(handsFreeSettingsServiceProvider);

      // Check if we should auto-enable
      final shouldAutoEnable = settingsService.shouldAutoEnable();
      
      if (kDebugMode) {
        print('🎙️ Checking auto-enable global voice...');
        print('   - Default hands-free mode: ${settings.defaultHandsFreeMode}');
        print('   - Persist across sessions: ${settings.persistAcrossSessions}');
        print('   - Current hands-free enabled: ${settingsService.isHandsFreeEnabled}');
        print('   - Should auto-enable: $shouldAutoEnable');
      }

      if (shouldAutoEnable) {
        if (kDebugMode) {
          print('🎙️ Auto-enabling global voice based on user settings...');
        }

        // Get global voice notifier and enable
        final globalVoiceNotifier = _ref.read(globalVoiceProvider.notifier);
        final success = await globalVoiceNotifier.enable();

        if (success) {
          if (kDebugMode) {
            print('✅ Global voice auto-enabled successfully');
          }
        } else {
          if (kDebugMode) {
            print('⚠️ Global voice auto-enable failed (likely permissions)');
          }
        }
      } else {
        if (kDebugMode) {
          print('ℹ️ Auto-enable not needed - user preference is disabled');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to handle auto-enable global voice: $e');
      }
      // Don't rethrow - this is not critical for app functionality
    }
  }

  /// Reset initialization state (for testing/debugging)
  void reset() {
    state = const AppInitializationState();
  }
}

/// Convenience provider to check if auto-enable is completed
final autoEnableCompletedProvider = Provider<bool>((ref) {
  return ref.watch(appInitializationProvider).autoEnableCompleted;
});

/// Convenience provider to check if app is initialized
final appInitializedProvider = Provider<bool>((ref) {
  return ref.watch(appInitializationProvider).isInitialized;
});
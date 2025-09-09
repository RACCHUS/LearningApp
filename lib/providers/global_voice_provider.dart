import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/global_voice_command.dart';
import 'package:learning_pwa/services/global_voice_service.dart';
import 'package:learning_pwa/providers/enhanced_audio_provider.dart';
import 'package:learning_pwa/providers/router_provider.dart';

/// Provider for the global voice service
final globalVoiceServiceProvider = Provider<GlobalVoiceService>((ref) {
  return GlobalVoiceService();
});

/// State notifier for global voice functionality
class GlobalVoiceNotifier extends StateNotifier<GlobalVoiceState> {
  final GlobalVoiceService _service;
  final Ref _ref;

  GlobalVoiceNotifier(this._service, this._ref) : super(const GlobalVoiceState()) {
    _initializeService();
    _setupListeners();
  }

  Future<void> _initializeService() async {
    // Get the enhanced voice service from the audio provider
    final audioNotifier = _ref.read(enhancedAudioProvider.notifier);
    
    // Get the router for navigation
    final router = _ref.read(routerProvider);
    
    await _service.initialize(
      voiceService: audioNotifier.voiceService,
      router: router,
    );
    
    // Update state with service availability
    state = state.copyWith(
      isAvailable: _service.isAvailable,
      hasPermissions: _service.hasPermissions,
    );
  }

  void _setupListeners() {
    // Listen to service state changes
    _service.isListeningStream.listen((isListening) {
      state = state.copyWith(isListening: isListening);
    });

    _service.commandStream.listen((command) {
      state = state.copyWith(
        lastCommand: command,
        lastCommandTime: DateTime.now(),
      );
    });

    _service.statusStream.listen((status) {
      state = state.copyWith(statusMessage: status);
    });
  }

  /// Enable global voice listening
  Future<bool> enable() async {
    // Ensure we have permissions first
    final audioNotifier = _ref.read(enhancedAudioProvider.notifier);
    final hasPermissions = await audioNotifier.requestMicrophonePermissions();
    
    if (!hasPermissions) {
      state = state.copyWith(
        isEnabled: false,
        statusMessage: 'Microphone permission required',
      );
      return false;
    }

    final success = await _service.enable();
    state = state.copyWith(
      isEnabled: success,
      hasPermissions: _service.hasPermissions,
      isAvailable: _service.isAvailable,
    );
    
    return success;
  }

  /// Disable global voice listening
  Future<void> disable() async {
    await _service.disable();
    state = state.copyWith(isEnabled: false);
  }

  /// Toggle global voice service
  Future<bool> toggle() async {
    if (state.isEnabled) {
      await disable();
      return false;
    } else {
      return await enable();
    }
  }

  /// Update current route for context-aware commands
  void updateRoute(String route) {
    _service.updateRoute(route);
    state = state.copyWith(currentRoute: route);
  }

  /// Get contextual help for current route
  String getContextualHelp() {
    return _service.getContextualHelp();
  }

  /// Handle a global voice command
  Future<void> handleCommand(GlobalVoiceCommand command) async {
    // This method will be called by the app's router/navigation system
    // when a global command is received
    state = state.copyWith(
      lastHandledCommand: command,
      lastHandledTime: DateTime.now(),
    );
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}

/// State class for global voice functionality
class GlobalVoiceState {
  final bool isEnabled;
  final bool isListening;
  final bool isAvailable;
  final bool hasPermissions;
  final String currentRoute;
  final String statusMessage;
  final GlobalVoiceCommand? lastCommand;
  final DateTime? lastCommandTime;
  final GlobalVoiceCommand? lastHandledCommand;
  final DateTime? lastHandledTime;

  const GlobalVoiceState({
    this.isEnabled = false,
    this.isListening = false,
    this.isAvailable = false,
    this.hasPermissions = false,
    this.currentRoute = '/',
    this.statusMessage = 'Not initialized',
    this.lastCommand,
    this.lastCommandTime,
    this.lastHandledCommand,
    this.lastHandledTime,
  });

  GlobalVoiceState copyWith({
    bool? isEnabled,
    bool? isListening,
    bool? isAvailable,
    bool? hasPermissions,
    String? currentRoute,
    String? statusMessage,
    GlobalVoiceCommand? lastCommand,
    DateTime? lastCommandTime,
    GlobalVoiceCommand? lastHandledCommand,
    DateTime? lastHandledTime,
  }) {
    return GlobalVoiceState(
      isEnabled: isEnabled ?? this.isEnabled,
      isListening: isListening ?? this.isListening,
      isAvailable: isAvailable ?? this.isAvailable,
      hasPermissions: hasPermissions ?? this.hasPermissions,
      currentRoute: currentRoute ?? this.currentRoute,
      statusMessage: statusMessage ?? this.statusMessage,
      lastCommand: lastCommand ?? this.lastCommand,
      lastCommandTime: lastCommandTime ?? this.lastCommandTime,
      lastHandledCommand: lastHandledCommand ?? this.lastHandledCommand,
      lastHandledTime: lastHandledTime ?? this.lastHandledTime,
    );
  }

  @override
  String toString() {
    return 'GlobalVoiceState(isEnabled: $isEnabled, isListening: $isListening, '
           'isAvailable: $isAvailable, currentRoute: $currentRoute)';
  }
}

/// Provider for global voice state
final globalVoiceProvider = StateNotifierProvider<GlobalVoiceNotifier, GlobalVoiceState>((ref) {
  final service = ref.watch(globalVoiceServiceProvider);
  return GlobalVoiceNotifier(service, ref);
});

/// Convenience providers
final isGlobalVoiceEnabledProvider = Provider<bool>((ref) {
  return ref.watch(globalVoiceProvider).isEnabled;
});

final globalVoiceStatusProvider = Provider<String>((ref) {
  return ref.watch(globalVoiceProvider).statusMessage;
});

final lastGlobalCommandProvider = Provider<GlobalVoiceCommand?>((ref) {
  return ref.watch(globalVoiceProvider).lastCommand;
});

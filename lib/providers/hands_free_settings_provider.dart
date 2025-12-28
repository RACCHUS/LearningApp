import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/hands_free_settings.dart';
import 'package:learning_pwa/services/hands_free_settings_service.dart';

/// Provider for the hands-free settings service
final handsFreeSettingsServiceProvider = Provider<HandsFreeSettingsService>((ref) {
  return HandsFreeSettingsService();
});

/// State notifier for hands-free settings
class HandsFreeSettingsNotifier extends StateNotifier<HandsFreeSettings> {
  final HandsFreeSettingsService _service;
  
  // Subscription for cleanup
  StreamSubscription<HandsFreeSettings>? _settingsSubscription;

  HandsFreeSettingsNotifier(this._service) : super(const HandsFreeSettings()) {
    _initializeSettings();
    _setupListeners();
  }

  Future<void> _initializeSettings() async {
    await _service.initialize();
    state = _service.settings;
  }

  void _setupListeners() {
    _settingsSubscription = _service.settingsStream.listen((settings) {
      state = settings;
    });
  }

  /// Update all settings at once
  Future<void> updateSettings(HandsFreeSettings newSettings) async {
    await _service.saveSettings(newSettings);
  }

  /// Toggle default hands-free mode
  Future<void> toggleDefaultHandsFreeMode() async {
    await _service.updateSetting('defaultHandsFreeMode', !state.defaultHandsFreeMode);
  }

  /// Toggle global voice commands
  Future<void> toggleGlobalVoiceCommands() async {
    await _service.updateSetting('globalVoiceCommands', !state.globalVoiceCommands);
  }

  /// Toggle auto lesson hands-free
  Future<void> toggleAutoLessonHandsFree() async {
    await _service.updateSetting('autoLessonHandsFree', !state.autoLessonHandsFree);
  }

  /// Set voice timeout
  Future<void> setVoiceTimeout(Duration timeout) async {
    await _service.updateSetting('voiceTimeout', timeout);
  }

  /// Set confidence threshold
  Future<void> setConfidenceThreshold(double threshold) async {
    await _service.updateSetting('confidenceThreshold', threshold);
  }

  /// Toggle auto request permissions
  Future<void> toggleAutoRequestPermissions() async {
    await _service.updateSetting('autoRequestPermissions', !state.autoRequestPermissions);
  }

  /// Toggle show voice indicator
  Future<void> toggleShowVoiceIndicator() async {
    await _service.updateSetting('showVoiceIndicator', !state.showVoiceIndicator);
  }

  /// Toggle announce commands
  Future<void> toggleAnnounceCommands() async {
    await _service.updateSetting('announceCommands', !state.announceCommands);
  }

  /// Toggle enable wake word
  Future<void> toggleEnableWakeWord() async {
    await _service.updateSetting('enableWakeWord', !state.enableWakeWord);
  }

  /// Set wake word
  Future<void> setWakeWord(String wakeWord) async {
    await _service.updateSetting('wakeWord', wakeWord);
  }

  /// Toggle persist across sessions
  Future<void> togglePersistAcrossSessions() async {
    await _service.updateSetting('persistAcrossSessions', !state.persistAcrossSessions);
  }

  /// Reset to default settings
  Future<void> resetToDefaults() async {
    await _service.resetToDefaults();
  }

  /// Apply recommended settings
  Future<void> applyRecommendedSettings() async {
    final recommended = _service.getRecommendedSettings();
    await updateSettings(recommended);
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    _service.dispose();
    super.dispose();
  }
}

/// State notifier for hands-free enabled state
class HandsFreeStateNotifier extends StateNotifier<bool> {
  final HandsFreeSettingsService _service;
  
  // Subscription for cleanup
  StreamSubscription<bool>? _stateSubscription;

  HandsFreeStateNotifier(this._service) : super(false) {
    _initializeState();
    _setupListeners();
  }

  Future<void> _initializeState() async {
    await _service.initialize();
    state = _service.isHandsFreeEnabled;
  }

  void _setupListeners() {
    _stateSubscription = _service.stateStream.listen((enabled) {
      state = enabled;
    });
  }

  /// Toggle hands-free enabled state
  Future<void> toggle() async {
    await _service.toggleEnabled();
  }

  /// Enable hands-free
  Future<void> enable() async {
    await _service.enable();
  }

  /// Disable hands-free
  Future<void> disable() async {
    await _service.disable();
  }

  /// Check if hands-free should be auto-enabled
  bool shouldAutoEnable() {
    return _service.shouldAutoEnable();
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _service.dispose();
    super.dispose();
  }
}

/// Provider for hands-free settings state
final handsFreeSettingsProvider = StateNotifierProvider<HandsFreeSettingsNotifier, HandsFreeSettings>((ref) {
  final service = ref.watch(handsFreeSettingsServiceProvider);
  return HandsFreeSettingsNotifier(service);
});

/// Provider for hands-free enabled state
final handsFreeStateProvider = StateNotifierProvider<HandsFreeStateNotifier, bool>((ref) {
  final service = ref.watch(handsFreeSettingsServiceProvider);
  return HandsFreeStateNotifier(service);
});

/// Convenience providers
final shouldShowVoiceIndicatorProvider = Provider<bool>((ref) {
  return ref.watch(handsFreeSettingsProvider).showVoiceIndicator;
});

final shouldAutoRequestPermissionsProvider = Provider<bool>((ref) {
  return ref.watch(handsFreeSettingsProvider).autoRequestPermissions;
});

final shouldAutoEnableLessonHandsFreeProvider = Provider<bool>((ref) {
  return ref.watch(handsFreeSettingsProvider).autoLessonHandsFree;
});

final voiceTimeoutProvider = Provider<Duration>((ref) {
  return ref.watch(handsFreeSettingsProvider).voiceTimeout;
});

final confidenceThresholdProvider = Provider<double>((ref) {
  return ref.watch(handsFreeSettingsProvider).confidenceThreshold;
});

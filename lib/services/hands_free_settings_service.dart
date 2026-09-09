import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:learning_pwa/models/hands_free_settings.dart';

/// Service for managing hands-free settings persistence
class HandsFreeSettingsService {
  static const String _settingsKey = 'hands_free_settings';
  static const String _stateKey = 'hands_free_enabled_state';
  
  static final HandsFreeSettingsService _instance = HandsFreeSettingsService._internal();
  factory HandsFreeSettingsService() => _instance;
  HandsFreeSettingsService._internal();

  HandsFreeSettings _settings = const HandsFreeSettings();
  bool _isHandsFreeEnabled = false;
  
  final StreamController<HandsFreeSettings> _settingsController = 
      StreamController<HandsFreeSettings>.broadcast();
  final StreamController<bool> _stateController = 
      StreamController<bool>.broadcast();
  
  // Streams for UI to listen to
  Stream<HandsFreeSettings> get settingsStream => _settingsController.stream;
  Stream<bool> get stateStream => _stateController.stream;
  
  // Getters
  HandsFreeSettings get settings => _settings;
  bool get isHandsFreeEnabled => _isHandsFreeEnabled;

  /// Initialize the service and load saved settings
  Future<void> initialize() async {
    await _loadSettings();
    await _loadState();
    
    if (kDebugMode) {
      print('🔧 HandsFreeSettingsService initialized');
      print('   - Default hands-free mode: ${_settings.defaultHandsFreeMode}');
      print('   - Current state: $_isHandsFreeEnabled');
    }
  }

  /// Load settings from shared preferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);
      
      if (settingsJson != null) {
        final settingsMap = jsonDecode(settingsJson) as Map<String, dynamic>;
        _settings = HandsFreeSettings.fromJson(settingsMap);
        
        if (kDebugMode) {
          print('🔧 Loaded hands-free settings from storage');
        }
      } else {
        if (kDebugMode) {
          print('🔧 No saved hands-free settings found, using defaults');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('🔧 Error loading hands-free settings: $e');
      }
      _settings = const HandsFreeSettings();
    }
    
    _settingsController.add(_settings);
  }

  /// Load enabled state from shared preferences
  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (_settings.persistAcrossSessions) {
        _isHandsFreeEnabled = prefs.getBool(_stateKey) ?? _settings.defaultHandsFreeMode;
      } else {
        _isHandsFreeEnabled = _settings.defaultHandsFreeMode;
      }
      
      if (kDebugMode) {
        print('🔧 Loaded hands-free state: $_isHandsFreeEnabled');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🔧 Error loading hands-free state: $e');
      }
      _isHandsFreeEnabled = _settings.defaultHandsFreeMode;
    }
    
    _stateController.add(_isHandsFreeEnabled);
  }

  /// Save settings to shared preferences
  Future<void> saveSettings(HandsFreeSettings newSettings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = jsonEncode(newSettings.toJson());
      await prefs.setString(_settingsKey, settingsJson);
      
      _settings = newSettings;
      _settingsController.add(_settings);
      
      if (kDebugMode) {
        print('🔧 Saved hands-free settings to storage');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🔧 Error saving hands-free settings: $e');
      }
    }
  }

  /// Save enabled state to shared preferences
  Future<void> saveState(bool enabled) async {
    if (!_settings.persistAcrossSessions) {
      // Don't persist state if setting is disabled
      _isHandsFreeEnabled = enabled;
      _stateController.add(_isHandsFreeEnabled);
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_stateKey, enabled);
      
      _isHandsFreeEnabled = enabled;
      _stateController.add(_isHandsFreeEnabled);
      
      if (kDebugMode) {
        print('🔧 Saved hands-free state: $enabled');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🔧 Error saving hands-free state: $e');
      }
    }
  }

  /// Update a specific setting
  Future<void> updateSetting<T>(String settingName, T value) async {
    HandsFreeSettings newSettings;
    
    switch (settingName) {
      case 'defaultHandsFreeMode':
        newSettings = _settings.copyWith(defaultHandsFreeMode: value as bool);
        break;
      case 'globalVoiceCommands':
        newSettings = _settings.copyWith(globalVoiceCommands: value as bool);
        break;
      case 'autoLessonHandsFree':
        newSettings = _settings.copyWith(autoLessonHandsFree: value as bool);
        break;
      case 'voiceTimeout':
        newSettings = _settings.copyWith(voiceTimeout: value as Duration);
        break;
      case 'confidenceThreshold':
        newSettings = _settings.copyWith(confidenceThreshold: value as double);
        break;
      case 'autoRequestPermissions':
        newSettings = _settings.copyWith(autoRequestPermissions: value as bool);
        break;
      case 'showVoiceIndicator':
        newSettings = _settings.copyWith(showVoiceIndicator: value as bool);
        break;
      case 'announceCommands':
        newSettings = _settings.copyWith(announceCommands: value as bool);
        break;
      case 'enableWakeWord':
        newSettings = _settings.copyWith(enableWakeWord: value as bool);
        break;
      case 'wakeWord':
        newSettings = _settings.copyWith(wakeWord: value as String);
        break;
      case 'persistAcrossSessions':
        newSettings = _settings.copyWith(persistAcrossSessions: value as bool);
        break;
      default:
        if (kDebugMode) {
          print('🔧 Unknown setting: $settingName');
        }
        return;
    }
    
    await saveSettings(newSettings);
  }

  /// Toggle hands-free enabled state
  Future<void> toggleEnabled() async {
    await saveState(!_isHandsFreeEnabled);
  }

  /// Enable hands-free mode
  Future<void> enable() async {
    await saveState(true);
  }

  /// Disable hands-free mode
  Future<void> disable() async {
    await saveState(false);
  }

  /// Reset settings to defaults
  Future<void> resetToDefaults() async {
    await saveSettings(const HandsFreeSettings());
    await saveState(false);
    
    if (kDebugMode) {
      print('🔧 Reset hands-free settings to defaults');
    }
  }

  /// Check if hands-free should be auto-enabled on app start
  bool shouldAutoEnable() {
    return _settings.defaultHandsFreeMode || 
           (_settings.persistAcrossSessions && _isHandsFreeEnabled);
  }

  /// Get recommended settings based on device capabilities
  HandsFreeSettings getRecommendedSettings() {
    // For now, return default settings
    // In the future, this could be based on device type, browser capabilities, etc.
    return const HandsFreeSettings(
      defaultHandsFreeMode: true,
      globalVoiceCommands: true,
      autoLessonHandsFree: true,
      voiceTimeout: Duration(seconds: 5),
      confidenceThreshold: 0.7,
      autoRequestPermissions: true,
      showVoiceIndicator: true,
      announceCommands: false,
      enableWakeWord: false,
    );
  }

  /// Dispose of the service
  void dispose() {
    _settingsController.close();
    _stateController.close();
    
    if (kDebugMode) {
      print('🔧 HandsFreeSettingsService disposed');
    }
  }
}

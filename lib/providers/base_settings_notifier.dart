import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Storage backend for settings persistence
enum SettingsStorage {
  sharedPreferences,
  hive,
}

/// Base class for settings notifiers with common persistence logic
/// 
/// This provides standardized initialization, saving, and error handling
/// for all settings providers in the app.
abstract class BaseSettingsNotifier<T> extends StateNotifier<T> {
  BaseSettingsNotifier(super.initialState, {
    required this.storageKey,
    this.storage = SettingsStorage.sharedPreferences,
  }) {
    _initialize();
  }

  /// Key used to store settings in persistent storage
  final String storageKey;
  
  /// Storage backend to use (SharedPreferences or Hive)
  final SettingsStorage storage;

  SharedPreferences? _prefs;
  Box<T>? _hiveBox;

  /// Initialize the settings provider and load saved settings
  Future<void> _initialize() async {
    try {
      await loadSettings();
      debugPrint('✅ Loaded settings for $storageKey');
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to load settings for $storageKey: $e');
      debugPrint('Stack trace: $stackTrace');
      // Continue with default state if loading fails
    }
  }

  /// Load settings from persistent storage
  /// 
  /// Subclasses should override [deserialize] to convert stored data
  Future<void> loadSettings() async {
    try {
      if (storage == SettingsStorage.sharedPreferences) {
        _prefs = await SharedPreferences.getInstance();
        final data = _prefs?.getString(storageKey);
        if (data != null) {
          final settings = deserialize(data);
          if (settings != null && mounted) {
            state = settings;
          }
        }
      } else {
        _hiveBox = await Hive.openBox<T>(storageKey);
        final settings = _hiveBox?.get('settings');
        if (settings != null && mounted) {
          state = settings;
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading settings from $storage: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Save current settings to persistent storage
  Future<void> saveSettings() async {
    // Notifier may be disposed before an async persistence call resolves.
    if (!mounted) return;
    try {
      if (storage == SettingsStorage.sharedPreferences) {
        if (_prefs == null) {
          _prefs = await SharedPreferences.getInstance();
        }
        final data = serialize(state);
        await _prefs?.setString(storageKey, data);
      } else {
        if (_hiveBox == null) {
          _hiveBox = await Hive.openBox<T>(storageKey);
        }
        await _hiveBox?.put('settings', state);
      }
      debugPrint('✅ Saved settings for $storageKey');
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to save settings for $storageKey: $e');
      debugPrint('Stack trace: $stackTrace');
      // Don't rethrow - saving failure shouldn't break the app
    }
  }

  /// Update settings and persist automatically
  /// 
  /// This is the primary method subclasses should use to update state
  Future<void> updateSettings(T newSettings) async {
    if (!mounted) return;
    state = newSettings;
    await saveSettings();
  }

  /// Serialize settings to string for SharedPreferences storage
  /// 
  /// Override this when using SharedPreferences storage
  String serialize(T settings) {
    throw UnimplementedError(
      'serialize() must be implemented when using SharedPreferences storage'
    );
  }

  /// Deserialize settings from string for SharedPreferences storage
  /// 
  /// Override this when using SharedPreferences storage
  /// Return null if deserialization fails
  T? deserialize(String data) {
    throw UnimplementedError(
      'deserialize() must be implemented when using SharedPreferences storage'
    );
  }

  /// Reset settings to default values
  /// 
  /// Subclasses should override to provide default settings
  Future<void> resetToDefaults() async {
    if (!mounted) return;
    state = getDefaultSettings();
    await saveSettings();
    debugPrint('✅ Reset $storageKey to defaults');
  }

  /// Get default settings
  /// 
  /// Subclasses must override this to provide default values
  T getDefaultSettings();

  @override
  void dispose() {
    _hiveBox?.close();
    super.dispose();
  }
}

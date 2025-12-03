import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/base_settings_notifier.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) => ThemeModeNotifier());

class ThemeModeNotifier extends BaseSettingsNotifier<ThemeMode> {
  ThemeModeNotifier() : super(
    ThemeMode.dark,
    storageKey: 'themeMode',
    storage: SettingsStorage.sharedPreferences,
  );

  @override
  String serialize(ThemeMode settings) {
    return settings == ThemeMode.light ? 'light' : 'dark';
  }

  @override
  ThemeMode? deserialize(String data) {
    if (data == 'light') return ThemeMode.light;
    if (data == 'dark') return ThemeMode.dark;
    return null;
  }

  @override
  ThemeMode getDefaultSettings() => ThemeMode.dark;

  Future<void> setTheme(ThemeMode mode) async {
    await updateSettings(mode);
  }
}

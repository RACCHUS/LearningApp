import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  setUp(() {
    // Set up fake shared preferences with empty initial values
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeProvider Tests', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
      await Future.delayed(const Duration(milliseconds: 100)); // Wait for initialization
    });

    tearDown(() {
      container.dispose();
    });

    test('initial theme mode should be dark', () async {
      final themeMode = container.read(themeModeProvider);
      expect(themeMode, ThemeMode.dark);
    });

    test('should switch to dark mode', () async {
      final notifier = container.read(themeModeProvider.notifier);
      
      await notifier.setTheme(ThemeMode.dark);
      await Future.delayed(const Duration(milliseconds: 50));
      
      final themeMode = container.read(themeModeProvider);
      expect(themeMode, ThemeMode.dark);
    });

    test('should switch to light mode', () async {
      final notifier = container.read(themeModeProvider.notifier);
      
      await notifier.setTheme(ThemeMode.light);
      await Future.delayed(const Duration(milliseconds: 50));
      
      final themeMode = container.read(themeModeProvider);
      expect(themeMode, ThemeMode.light);
    });

    test('should switch back to dark mode', () async {
      final notifier = container.read(themeModeProvider.notifier);
      
      await notifier.setTheme(ThemeMode.light);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(container.read(themeModeProvider), ThemeMode.light);
      
      await notifier.setTheme(ThemeMode.dark);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    test('should maintain state across multiple changes', () async {
      final notifier = container.read(themeModeProvider.notifier);
      
      await notifier.setTheme(ThemeMode.light);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(container.read(themeModeProvider), ThemeMode.light);
      
      await notifier.setTheme(ThemeMode.dark);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(container.read(themeModeProvider), ThemeMode.dark);
      
      await notifier.setTheme(ThemeMode.light);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    test('should handle toggling between light and dark modes', () async {
      final notifier = container.read(themeModeProvider.notifier);
      
      await notifier.setTheme(ThemeMode.light);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(container.read(themeModeProvider), ThemeMode.light);
      
      await notifier.setTheme(ThemeMode.dark);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    test('should not change if same mode is set', () async {
      final notifier = container.read(themeModeProvider.notifier);
      
      await notifier.setTheme(ThemeMode.dark);
      await Future.delayed(const Duration(milliseconds: 50));
      final firstState = container.read(themeModeProvider);
      
      await notifier.setTheme(ThemeMode.dark);
      await Future.delayed(const Duration(milliseconds: 50));
      final secondState = container.read(themeModeProvider);
      
      expect(firstState, secondState);
    });

    test('saved light theme survives a new provider container', () async {
      SharedPreferences.setMockInitialValues({});
      
      final container1 = ProviderContainer();
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Save a non-default choice so a broken load cannot pass by coincidence.
      await container1.read(themeModeProvider.notifier).setTheme(ThemeMode.light);
      await Future.delayed(const Duration(milliseconds: 150));
      expect(container1.read(themeModeProvider), ThemeMode.light);
      
      // Dispose container1
      container1.dispose();
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Create container2 - it should load the saved light value.
      final container2 = ProviderContainer();
      container2.read(themeModeProvider); // Start its async local load.
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Container2 loads from this device's SharedPreferences.
      expect(container2.read(themeModeProvider), ThemeMode.light);
      
      container2.dispose();
    });
  });

  group('ThemeModeNotifier Tests', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
      await Future.delayed(const Duration(milliseconds: 100));
    });

    tearDown(() {
      container.dispose();
    });

    test('should provide notifier instance', () {
      final notifier = container.read(themeModeProvider.notifier);
      expect(notifier, isA<ThemeModeNotifier>());
    });

    test('notifier should update state correctly', () async {
      final notifier = container.read(themeModeProvider.notifier);
      
      expect(container.read(themeModeProvider), ThemeMode.dark);
      
      await notifier.setTheme(ThemeMode.light);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(container.read(themeModeProvider), ThemeMode.light);
      
      await notifier.setTheme(ThemeMode.dark);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });
  });
}

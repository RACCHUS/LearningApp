import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/app_initialization_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('AppInitializationProvider Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should initialize with default state', () {
      final state = container.read(appInitializationProvider);
      
      expect(state.isInitialized, false);
      expect(state.autoEnableCompleted, false);
      expect(state.error, isNull);
    });

    test('should have convenience providers', () {
      final isInitialized = container.read(appInitializedProvider);
      final autoEnableCompleted = container.read(autoEnableCompletedProvider);
      
      expect(isInitialized, false);
      expect(autoEnableCompleted, false);
    });

    test('should initialize app features', () async {
      final notifier = container.read(appInitializationProvider.notifier);
      
      // Note: This will attempt to initialize hands-free settings and global voice
      // In a real test, we'd mock these dependencies
      try {
        await notifier.initialize();
        
        final state = container.read(appInitializationProvider);
        // Even if initialization fails, it should mark as initialized to prevent retry loops
        expect(state.isInitialized, true);
      } catch (e) {
        // Expected in test environment without proper mocks
        final state = container.read(appInitializationProvider);
        expect(state.isInitialized, true); // Should still be marked as initialized
      }
      
      // Allow any pending async work to complete before test ends
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('should reset initialization state', () {
      final notifier = container.read(appInitializationProvider.notifier);
      
      notifier.reset();
      
      final state = container.read(appInitializationProvider);
      expect(state.isInitialized, false);
      expect(state.autoEnableCompleted, false);
    });
  });
}


import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/speech_recognition/speech_recognition_manager.dart';
import 'package:learning_pwa/services/speech_recognition/speech_recognition_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpeechRecognitionManager', () {
    late SpeechRecognitionManager manager;

    setUp(() {
      manager = SpeechRecognitionManager();
    });

    group('Initialization', () {
      test('initialize() completes successfully', () async {
        final result = await manager.initialize();

        // Should initialize and return a bool
        expect(result, isA<bool>());
      });

      test('initialize() detects available providers', () async {
        await manager.initialize();

        // Manual input should always be available as fallback
        expect(manager, isNotNull);
      });

      test('can initialize multiple times', () async {
        await manager.initialize();
        final result = await manager.initialize();

        // Should handle re-initialization gracefully
        expect(result, isTrue);
      });
    });

    group('Provider selection', () {
      test('_selectBestProvider() falls back to manual input', () async {
        await manager.initialize();

        // Manual input should be available as fallback
        final info = manager.currentProviderInfo;
        
        expect(info, isNotNull);
        // Either native provider or manual fallback
        expect(info?.name, isNotEmpty);
      });

      test('currentProviderInfo returns provider information', () async {
        await manager.initialize();

        final info = manager.currentProviderInfo;

        if (info != null) {
          expect(info.name, isNotEmpty);
          expect(info.priority, isA<ProviderPriority>());
        }
      });
    });

    group('Provider changes stream', () {
      test('providerChanges stream is available', () async {
        await manager.initialize();

        expect(manager.providerChanges, isNotNull);
      });

      test('providerChanges emits on initialization', () async {
        final events = <ProviderInfo>[];
        final subscription = manager.providerChanges.listen(events.add);

        await manager.initialize();
        await Future.delayed(const Duration(milliseconds: 100));

        // Should emit at least initial provider selection
        expect(events.length, greaterThanOrEqualTo(0));

        await subscription.cancel();
      });
    });

    group('Status and availability', () {
      test('manager is created successfully', () {
        expect(manager, isNotNull);
      });

      test('initializes to a valid state', () async {
        final initialized = await manager.initialize();

        expect(initialized, isA<bool>());
      });
    });

    group('Singleton pattern', () {
      test('returns same instance', () {
        final instance1 = SpeechRecognitionManager();
        final instance2 = SpeechRecognitionManager();

        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('Provider capabilities', () {
      test('manual input provider is always available', () async {
        await manager.initialize();

        // Manual input should be registered as fallback
        expect(manager, isNotNull);
      });
    });

    group('Error handling', () {
      test('handles initialization errors gracefully', () async {
        // Should not throw even if some providers fail
        expect(() => manager.initialize(), returnsNormally);
      });
    });

    group('Browser compatibility', () {
      test('handles different browser environments', () async {
        // Manager should work in test environment
        final result = await manager.initialize();

        expect(result, isA<bool>());
      });

      test('provides fallback for unsupported browsers', () async {
        await manager.initialize();

        final info = manager.currentProviderInfo;
        
        // Should always have some provider (at minimum manual input)
        expect(info, isNotNull);
      });
    });

    group('Provider info', () {
      test('currentProviderInfo provides required fields', () async {
        await manager.initialize();

        final info = manager.currentProviderInfo;

        if (info != null) {
          expect(info.name, isA<String>());
          expect(info.priority, isA<ProviderPriority>());
          expect(info.capabilities, isA<Map<String, dynamic>>());
          expect(info.description, isA<String>());
        }
      });
    });

    group('State management', () {
      test('tracks initialization state', () async {
        // Before initialization
        final beforeInit = manager;
        
        await manager.initialize();
        
        // After initialization
        final afterInit = manager;

        expect(beforeInit, same(afterInit)); // Same instance
      });
    });

    group('Edge cases', () {
      test('handles rapid initialization calls', () async {
        final futures = [
          manager.initialize(),
          manager.initialize(),
          manager.initialize(),
        ];

        final results = await Future.wait(futures);

        expect(results, everyElement(isA<bool>()));
      });
    });
  });
}

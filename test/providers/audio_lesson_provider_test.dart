import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:learning_pwa/providers/audio_lesson_provider.dart';
import 'package:learning_pwa/models/audio_lesson_settings.dart';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioLessonSettingsNotifier', () {
    late ProviderContainer container;
    late AudioLessonSettingsNotifier notifier;
    late Directory testDir;

    setUp(() async {
      // Create temporary directory for Hive
      testDir = await Directory.systemTemp.createTemp('audio_test_');
      
      // Reset adapters first to avoid conflicts
      Hive.resetAdapters();
      Hive.init(testDir.path);
      
      // Register AudioLessonSettings adapter
      if (!Hive.isAdapterRegistered(21)) {
        Hive.registerAdapter(AudioLessonSettingsAdapter());
      }
      
      // Register Duration adapter
      if (!Hive.isAdapterRegistered(201)) {
        Hive.registerAdapter(DurationAdapter());
      }
      
      // Open and clear the settings box to ensure clean state
      try {
        final box = await Hive.openBox<AudioLessonSettings>('audioLessonSettings');
        await box.clear();
        await box.close();
      } catch (e) {
        // Box doesn't exist yet, that's fine
      }
      
      container = ProviderContainer();
      notifier = container.read(audioLessonSettingsProvider.notifier);
    });

    tearDown(() async {
      container.dispose();
      await Hive.close();
      Hive.resetAdapters();
      
      // Wait a bit for file handles to be released
      await Future.delayed(Duration(milliseconds: 100));
      
      if (await testDir.exists()) {
        try {
          await testDir.delete(recursive: true);
        } catch (e) {
          // Ignore deletion errors - temp dir will be cleaned up later
        }
      }
    });

    group('Toggle settings', () {
      test('toggleHandsFreeMode() toggles setting', () {
        final initialState = notifier.state.handsFreeModeEnabled;

        notifier.toggleHandsFreeMode();

        expect(notifier.state.handsFreeModeEnabled, !initialState);
      });

      test('toggleAutoReadAllContent() toggles setting', () {
        final initialState = notifier.state.autoReadAllContent;

        notifier.toggleAutoReadAllContent();

        expect(notifier.state.autoReadAllContent, !initialState);
      });

      test('toggleVoiceNavigation() toggles setting', () {
        final initialState = notifier.state.voiceNavigationEnabled;

        notifier.toggleVoiceNavigation();

        expect(notifier.state.voiceNavigationEnabled, !initialState);
      });

      test('toggleConfirmations() toggles setting', () {
        final initialState = notifier.state.confirmationsEnabled;

        notifier.toggleConfirmations();

        expect(notifier.state.confirmationsEnabled, !initialState);
      });

      test('toggleAutoProgressAfterReading() toggles setting', () {
        final initialState = notifier.state.autoProgressAfterReading;

        notifier.toggleAutoProgressAfterReading();

        expect(notifier.state.autoProgressAfterReading, !initialState);
      });

      test('toggleImmediateAnswerProgression() toggles setting', () {
        final initialState = notifier.state.immediateAnswerProgression;

        notifier.toggleImmediateAnswerProgression();

        expect(notifier.state.immediateAnswerProgression, !initialState);
      });

      test('toggleInterruptOnNextCommand() toggles setting', () {
        final initialState = notifier.state.interruptOnNextCommand;

        notifier.toggleInterruptOnNextCommand();

        expect(notifier.state.interruptOnNextCommand, !initialState);
      });
    });

    group('Update settings', () {
      test('setAutoProgressDelay() updates delay', () {
        const newDelay = Duration(seconds: 5);

        notifier.setAutoProgressDelay(newDelay);

        expect(notifier.state.autoProgressDelay, newDelay);
      });

      test('setVoiceInputTimeout() updates timeout', () {
        const newTimeout = Duration(seconds: 10);

        notifier.setVoiceInputTimeout(newTimeout);

        expect(notifier.state.voiceInputTimeout, newTimeout);
      });

      test('setPauseBetweenItems() updates pause duration', () {
        const newPause = 2.5;

        notifier.setPauseBetweenItems(newPause);

        expect(notifier.state.pauseBetweenItems, newPause);
      });

      test('setVoiceRetryAttempts() updates retry count', () {
        const newRetries = 5;

        notifier.setVoiceRetryAttempts(newRetries);

        expect(notifier.state.voiceRetryAttempts, newRetries);
      });
    });

    group('Default settings', () {
      test('getDefaultSettings() returns AudioLessonSettings', () {
        final defaults = notifier.getDefaultSettings();

        expect(defaults, isA<AudioLessonSettings>());
      });

      test('starts with default values', () {
        final state = notifier.state;

        expect(state, isA<AudioLessonSettings>());
        expect(state.handsFreeModeEnabled, isFalse);
        expect(state.voiceNavigationEnabled, isTrue); // Default is true
        expect(state.confirmationsEnabled, isTrue);
      });
    });

    group('Settings persistence', () {
      test('updateSettings() updates state', () async {
        final newSettings = const AudioLessonSettings(
          handsFreeModeEnabled: true,
          voiceNavigationEnabled: true,
          autoProgressDelay: Duration(seconds: 10),
        );

        await notifier.updateSettings(newSettings);

        expect(notifier.state.handsFreeModeEnabled, isTrue);
        expect(notifier.state.voiceNavigationEnabled, isTrue);
        expect(notifier.state.autoProgressDelay, const Duration(seconds: 10));
      });
    });

    group('Complex scenarios', () {
      test('can toggle multiple settings in sequence', () {
        notifier.toggleHandsFreeMode();
        notifier.toggleVoiceNavigation();
        notifier.toggleConfirmations();

        final state = notifier.state;
        // handsFreeModeEnabled: starts false, toggles to true
        expect(state.handsFreeModeEnabled, isTrue);
        // voiceNavigationEnabled: starts true, toggles to false
        expect(state.voiceNavigationEnabled, isFalse);
        // confirmationsEnabled: starts true, toggles to false
        expect(state.confirmationsEnabled, isFalse);
      });

      test('can update multiple numeric settings', () {
        notifier.setAutoProgressDelay(const Duration(seconds: 7));
        notifier.setVoiceInputTimeout(const Duration(seconds: 15));
        notifier.setPauseBetweenItems(3.0);
        notifier.setVoiceRetryAttempts(4);

        final state = notifier.state;
        expect(state.autoProgressDelay, const Duration(seconds: 7));
        expect(state.voiceInputTimeout, const Duration(seconds: 15));
        expect(state.pauseBetweenItems, 3.0);
        expect(state.voiceRetryAttempts, 4);
      });
    });

    group('Edge cases', () {
      test('handles zero pause between items', () {
        notifier.setPauseBetweenItems(0.0);

        expect(notifier.state.pauseBetweenItems, 0.0);
      });

      test('handles very short timeout', () {
        notifier.setVoiceInputTimeout(const Duration(milliseconds: 100));

        expect(notifier.state.voiceInputTimeout,
            const Duration(milliseconds: 100));
      });

      test('handles zero retry attempts', () {
        notifier.setVoiceRetryAttempts(0);

        expect(notifier.state.voiceRetryAttempts, 0);
      });

      test('handles large pause duration', () {
        notifier.setPauseBetweenItems(10.0);

        expect(notifier.state.pauseBetweenItems, 10.0);
      });
    });

    group('State immutability', () {
      test('toggle creates new state instance', () {
        final stateBefore = notifier.state;

        notifier.toggleHandsFreeMode();

        final stateAfter = notifier.state;
        expect(identical(stateBefore, stateAfter), isFalse);
      });

      test('update creates new state instance', () {
        final stateBefore = notifier.state;

        notifier.setAutoProgressDelay(const Duration(seconds: 10));

        final stateAfter = notifier.state;
        expect(identical(stateBefore, stateAfter), isFalse);
      });
    });
  });

  group('AudioLessonOrchestrator Provider', () {
    test('audioLessonOrchestratorProvider provides instance', () {
      final container = ProviderContainer();

      final orchestrator = container.read(audioLessonOrchestratorProvider);

      expect(orchestrator, isNotNull);

      container.dispose();
    });
  });
}

// Duration adapter for Hive serialization
class DurationAdapter extends TypeAdapter<Duration> {
  @override
  final typeId = 201;

  @override
  Duration read(BinaryReader reader) {
    final microseconds = reader.readInt();
    return Duration(microseconds: microseconds);
  }

  @override
  void write(BinaryWriter writer, Duration obj) {
    writer.writeInt(obj.inMicroseconds);
  }
}

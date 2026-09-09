import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/global_voice_provider.dart';
import 'package:learning_pwa/models/global_voice_command.dart';

void main() {
  group('GlobalVoiceProvider Tests', () {
    group('GlobalVoiceState', () {
      test('should create state with default values', () {
        const state = GlobalVoiceState();

        expect(state.isEnabled, false);
        expect(state.isListening, false);
        expect(state.isAvailable, false);
        expect(state.hasPermissions, false);
        expect(state.currentRoute, '/');
        expect(state.statusMessage, 'Not initialized');
        expect(state.lastCommand, null);
        expect(state.lastCommandTime, null);
        expect(state.lastHandledCommand, null);
        expect(state.lastHandledTime, null);
      });

      test('should create state with custom values', () {
        const command = GlobalVoiceCommand(
          type: GlobalVoiceCommandType.navigation,
          phrase: 'go home',
          value: GlobalNavigationCommand.goHome,
        );
        final now = DateTime.now();

        final state = GlobalVoiceState(
          isEnabled: true,
          isListening: true,
          isAvailable: true,
          hasPermissions: true,
          currentRoute: '/lessons',
          statusMessage: 'Ready',
          lastCommand: command,
          lastCommandTime: now,
        );

        expect(state.isEnabled, true);
        expect(state.isListening, true);
        expect(state.isAvailable, true);
        expect(state.hasPermissions, true);
        expect(state.currentRoute, '/lessons');
        expect(state.statusMessage, 'Ready');
        expect(state.lastCommand, command);
        expect(state.lastCommandTime, now);
      });
    });

    group('GlobalVoiceState copyWith', () {
      late GlobalVoiceState originalState;

      setUp(() {
        originalState = const GlobalVoiceState(
          isEnabled: false,
          isListening: false,
          currentRoute: '/',
          statusMessage: 'Initial',
        );
      });

      test('should update isEnabled', () {
        final newState = originalState.copyWith(isEnabled: true);

        expect(newState.isEnabled, true);
        expect(newState.isListening, false);
        expect(newState.currentRoute, '/');
      });

      test('should update isListening', () {
        final newState = originalState.copyWith(isListening: true);

        expect(newState.isEnabled, false);
        expect(newState.isListening, true);
      });

      test('should update currentRoute', () {
        final newState = originalState.copyWith(currentRoute: '/study');

        expect(newState.currentRoute, '/study');
        expect(newState.isEnabled, false);
      });

      test('should update statusMessage', () {
        final newState = originalState.copyWith(statusMessage: 'Listening...');

        expect(newState.statusMessage, 'Listening...');
      });

      test('should update lastCommand and time', () {
        const command = GlobalVoiceCommand(
          type: GlobalVoiceCommandType.navigation,
          phrase: 'go back',
          value: GlobalNavigationCommand.back,
        );
        final time = DateTime.now();

        final newState = originalState.copyWith(
          lastCommand: command,
          lastCommandTime: time,
        );

        expect(newState.lastCommand, command);
        expect(newState.lastCommandTime, time);
      });

      test('should update multiple fields at once', () {
        const command = GlobalVoiceCommand(
          type: GlobalVoiceCommandType.app,
          phrase: 'toggle hands free',
          value: AppCommand.toggleHandsFree,
        );

        final newState = originalState.copyWith(
          isEnabled: true,
          isListening: true,
          currentRoute: '/lessons',
          statusMessage: 'Active',
          lastCommand: command,
        );

        expect(newState.isEnabled, true);
        expect(newState.isListening, true);
        expect(newState.currentRoute, '/lessons');
        expect(newState.statusMessage, 'Active');
        expect(newState.lastCommand, command);
      });

      test('should maintain original values when no parameters provided', () {
        final newState = originalState.copyWith();

        expect(newState.isEnabled, originalState.isEnabled);
        expect(newState.isListening, originalState.isListening);
        expect(newState.currentRoute, originalState.currentRoute);
        expect(newState.statusMessage, originalState.statusMessage);
      });
    });

    group('GlobalVoiceState toString', () {
      test('should provide readable string representation', () {
        const state = GlobalVoiceState(
          isEnabled: true,
          isListening: false,
          isAvailable: true,
          currentRoute: '/study',
        );

        final str = state.toString();

        expect(str, contains('isEnabled: true'));
        expect(str, contains('isListening: false'));
        expect(str, contains('isAvailable: true'));
        expect(str, contains('currentRoute: /study'));
      });
    });

    group('GlobalVoiceCommand model', () {
      test('should create navigation command', () {
        const command = GlobalVoiceCommand(
          type: GlobalVoiceCommandType.navigation,
          phrase: 'go home',
          value: GlobalNavigationCommand.goHome,
        );

        expect(command.type, GlobalVoiceCommandType.navigation);
        expect(command.phrase, 'go home');
        expect(command.value, GlobalNavigationCommand.goHome);
      });

      test('should create app command', () {
        const command = GlobalVoiceCommand(
          type: GlobalVoiceCommandType.app,
          phrase: 'what can I say',
          value: AppCommand.whatCanISay,
        );

        expect(command.type, GlobalVoiceCommandType.app);
        expect(command.phrase, 'what can I say');
        expect(command.value, AppCommand.whatCanISay);
      });

      test('should create lesson management command', () {
        const command = GlobalVoiceCommand(
          type: GlobalVoiceCommandType.lessonManagement,
          phrase: 'find lesson',
          value: LessonManagementCommand.findLesson,
          parameters: {'query': 'mathematics'},
        );

        expect(command.type, GlobalVoiceCommandType.lessonManagement);
        expect(command.phrase, 'find lesson');
        expect(command.value, LessonManagementCommand.findLesson);
        expect(command.parameters['query'], 'mathematics');
      });

      test('should create lesson command with parameters', () {
        const command = GlobalVoiceCommand(
          type: GlobalVoiceCommandType.lessonManagement,
          phrase: 'start lesson',
          value: LessonManagementCommand.startLesson,
          parameters: {'lessonId': 'lesson-1'},
        );

        expect(command.type, GlobalVoiceCommandType.lessonManagement);
        expect(command.phrase, 'start lesson');
        expect(command.value, LessonManagementCommand.startLesson);
        expect(command.parameters['lessonId'], 'lesson-1');
      });
    });

    group('GlobalVoiceCommandType enum', () {
      test('should have all expected command types', () {
        expect(GlobalVoiceCommandType.values.length, 3);
        expect(GlobalVoiceCommandType.values, contains(GlobalVoiceCommandType.navigation));
        expect(GlobalVoiceCommandType.values, contains(GlobalVoiceCommandType.lessonManagement));
        expect(GlobalVoiceCommandType.values, contains(GlobalVoiceCommandType.app));
      });
    });

    group('Voice command flow scenarios', () {
      test('should track command lifecycle from received to handled', () {
        const initialState = GlobalVoiceState();

        // Command received
        const receivedCommand = GlobalVoiceCommand(
          type: GlobalVoiceCommandType.navigation,
          phrase: 'go home',
          value: GlobalNavigationCommand.goHome,
        );
        final receivedTime = DateTime.now();
        
        final receivedState = initialState.copyWith(
          lastCommand: receivedCommand,
          lastCommandTime: receivedTime,
        );

        expect(receivedState.lastCommand, receivedCommand);
        expect(receivedState.lastCommandTime, receivedTime);

        // Command handled
        final handledTime = DateTime.now();
        final handledState = receivedState.copyWith(
          lastHandledCommand: receivedCommand,
          lastHandledTime: handledTime,
        );

        expect(handledState.lastHandledCommand, receivedCommand);
        expect(handledState.lastHandledTime, handledTime);
        expect(handledState.lastCommand, receivedCommand); // Still preserved
      });

      test('should track listening state transitions', () {
        const state = GlobalVoiceState();

        // Start listening
        final listening = state.copyWith(
          isListening: true,
          statusMessage: 'Listening...',
        );

        expect(listening.isListening, true);
        expect(listening.statusMessage, 'Listening...');

        // Stop listening
        final stopped = listening.copyWith(
          isListening: false,
          statusMessage: 'Ready',
        );

        expect(stopped.isListening, false);
        expect(stopped.statusMessage, 'Ready');
      });

      test('should track route changes for context awareness', () {
        const state = GlobalVoiceState(currentRoute: '/');

        final onLessons = state.copyWith(currentRoute: '/lessons');
        expect(onLessons.currentRoute, '/lessons');

        final onStudy = onLessons.copyWith(currentRoute: '/study');
        expect(onStudy.currentRoute, '/study');

        final onSettings = onStudy.copyWith(currentRoute: '/settings');
        expect(onSettings.currentRoute, '/settings');
      });

      test('should handle permission state changes', () {
        const state = GlobalVoiceState(hasPermissions: false);

        final withPermissions = state.copyWith(
          hasPermissions: true,
          isAvailable: true,
        );

        expect(withPermissions.hasPermissions, true);
        expect(withPermissions.isAvailable, true);

        // Can now enable
        final enabled = withPermissions.copyWith(
          isEnabled: true,
          statusMessage: 'Voice control active',
        );

        expect(enabled.isEnabled, true);
        expect(enabled.hasPermissions, true);
      });

      test('should handle permission denied scenario', () {
        const state = GlobalVoiceState();

        final denied = state.copyWith(
          isEnabled: false,
          hasPermissions: false,
          statusMessage: 'Microphone permission required',
        );

        expect(denied.isEnabled, false);
        expect(denied.hasPermissions, false);
        expect(denied.statusMessage, 'Microphone permission required');
      });
    });
  });
}

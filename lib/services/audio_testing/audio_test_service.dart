import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/voice_command.dart';
import 'package:learning_pwa/providers/audio_provider.dart';

/// Service responsible for handling microphone and voice command testing
/// Extracted from AudioSettingsScreen to improve separation of concerns
class AudioTestService {
  final WidgetRef _ref;

  AudioTestService(this._ref);

  /// Test microphone access and permissions
  /// Returns true if microphone is accessible, false otherwise
  Future<bool> testMicrophone() async {
    final audioNotifier = _ref.read(audioStateProvider.notifier);
    
    try {
      // First cancel any existing listening to ensure clean state
      await audioNotifier.cancelListening();
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (kDebugMode) {
        print('🎙️ Starting microphone test...');
      }
      
      // Try to start listening - just check if we can start, not if we get speech
      final success = await audioNotifier.startListening(
        timeout: const Duration(seconds: 2), // Short test
      );
      
      // Wait a moment to see if it actually starts listening
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // Check the current state to see if we're actually listening
      final audioState = _ref.read(audioStateProvider);
      final isActuallyListening = audioState.isListening;
      
      if (kDebugMode) {
        print('🎙️ Microphone test - startListening result: $success, isListening: $isActuallyListening');
      }
      
      // Stop listening
      await audioNotifier.cancelListening();
      
      // Consider it successful if either startListening returned true OR we were actually listening
      final testSuccess = success || isActuallyListening;
      
      if (testSuccess) {
        // Since we successfully started listening, mark permissions as granted
        audioNotifier.setMicrophonePermissionGranted(true);
        
        if (kDebugMode) {
          print('🎙️ Microphone test succeeded - permissions granted');
        }
      } else {
        if (kDebugMode) {
          print('🎙️ Microphone test failed');
        }
      }
      
      return testSuccess;
    } catch (e) {
      if (kDebugMode) {
        print('🎙️ Microphone test exception: $e');
      }
      return false;
    }
  }

  /// Test voice command recognition
  /// Returns the recognized command or null if none was detected
  Future<VoiceCommand?> testVoiceCommands() async {
    final audioNotifier = _ref.read(audioStateProvider.notifier);
    
    try {
      // First do a quick permission test
      await audioNotifier.cancelListening(); // Ensure clean state
      final canListen = await audioNotifier.startListening(
        timeout: const Duration(milliseconds: 500)
      );
      await audioNotifier.cancelListening(); // Stop the test listen
      
      // Update permission state
      await audioNotifier.checkMicrophonePermissions();
      
      if (!canListen) {
        return null;
      }
      
      // Wait a moment for any UI updates
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Listen for actual command
      final command = await audioNotifier.listenForCommand(
        timeout: const Duration(seconds: 5),
      );
      
      return command;
    } catch (e) {
      if (kDebugMode) {
        print('🎙️ Voice command test exception: $e');
      }
      return null;
    }
  }

  /// Test audio playback with current settings
  void testAudio() {
    final audioNotifier = _ref.read(audioStateProvider.notifier);
    audioNotifier.speak(
      'This is a test of the text-to-speech functionality. '
      'Your audio settings are working correctly.',
    );
  }
}

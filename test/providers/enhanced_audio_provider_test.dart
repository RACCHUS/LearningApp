import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/audio_state.dart';

void main() {
  group('EnhancedAudioProvider Tests', () {
    group('AudioState', () {
      test('should create state with default values', () {
        const state = AudioState();

        expect(state.playbackState, AudioPlaybackState.idle);
        expect(state.voiceInputState, VoiceInputState.idle);
        expect(state.currentText, null);
        expect(state.progress, 0.0);
        expect(state.errorMessage, null);
        expect(state.isAvailable, true);
        expect(state.hasPermissions, false);
        expect(state.availableVoices, isEmpty);
        expect(state.recognizedText, null);
        expect(state.confidence, 0.0);
      });

      test('should create state with custom values', () {
        const state = AudioState(
          playbackState: AudioPlaybackState.playing,
          voiceInputState: VoiceInputState.listening,
          currentText: 'Test text',
          progress: 0.5,
          isAvailable: true,
          hasPermissions: true,
          availableVoices: ['voice1', 'voice2'],
          recognizedText: 'Hello',
          confidence: 0.95,
        );

        expect(state.playbackState, AudioPlaybackState.playing);
        expect(state.voiceInputState, VoiceInputState.listening);
        expect(state.currentText, 'Test text');
        expect(state.progress, 0.5);
        expect(state.hasPermissions, true);
        expect(state.availableVoices.length, 2);
        expect(state.recognizedText, 'Hello');
        expect(state.confidence, 0.95);
      });
    });

    group('AudioState copyWith', () {
      const original = AudioState();

      test('should copy with updated playback state', () {
        final updated = original.copyWith(
          playbackState: AudioPlaybackState.playing,
        );

        expect(updated.playbackState, AudioPlaybackState.playing);
        expect(updated.voiceInputState, original.voiceInputState);
      });

      test('should copy with updated voice input state', () {
        final updated = original.copyWith(
          voiceInputState: VoiceInputState.listening,
        );

        expect(updated.voiceInputState, VoiceInputState.listening);
        expect(updated.playbackState, original.playbackState);
      });

      test('should copy with progress and text', () {
        final updated = original.copyWith(
          currentText: 'Speaking now',
          progress: 0.75,
        );

        expect(updated.currentText, 'Speaking now');
        expect(updated.progress, 0.75);
      });

      test('should copy with permissions and availability', () {
        final updated = original.copyWith(
          hasPermissions: true,
          isAvailable: true,
        );

        expect(updated.hasPermissions, true);
        expect(updated.isAvailable, true);
      });

      test('should copy with recognized text and confidence', () {
        final updated = original.copyWith(
          recognizedText: 'next question',
          confidence: 0.88,
        );

        expect(updated.recognizedText, 'next question');
        expect(updated.confidence, 0.88);
      });

      test('should copy with error state', () {
        final updated = original.copyWith(
          playbackState: AudioPlaybackState.error,
          errorMessage: 'Failed to speak',
        );

        expect(updated.playbackState, AudioPlaybackState.error);
        expect(updated.errorMessage, 'Failed to speak');
      });
    });

    group('AudioPlaybackState enum', () {
      test('should have all expected playback states', () {
        expect(AudioPlaybackState.values.length, 6);
        expect(AudioPlaybackState.values, contains(AudioPlaybackState.idle));
        expect(AudioPlaybackState.values, contains(AudioPlaybackState.loading));
        expect(AudioPlaybackState.values, contains(AudioPlaybackState.playing));
        expect(AudioPlaybackState.values, contains(AudioPlaybackState.paused));
        expect(AudioPlaybackState.values, contains(AudioPlaybackState.stopped));
        expect(AudioPlaybackState.values, contains(AudioPlaybackState.error));
      });
    });

    group('VoiceInputState enum', () {
      test('should have all expected voice input states', () {
        expect(VoiceInputState.values.length, 5);
        expect(VoiceInputState.values, contains(VoiceInputState.idle));
        expect(VoiceInputState.values, contains(VoiceInputState.listening));
        expect(VoiceInputState.values, contains(VoiceInputState.processing));
        expect(VoiceInputState.values, contains(VoiceInputState.completed));
        expect(VoiceInputState.values, contains(VoiceInputState.error));
      });
    });

    group('AudioState helper getters', () {
      test('isPlaying should return true when playing', () {
        const state = AudioState(playbackState: AudioPlaybackState.playing);
        expect(state.isPlaying, true);
      });

      test('isPlaying should return false when not playing', () {
        const state = AudioState(playbackState: AudioPlaybackState.paused);
        expect(state.isPlaying, false);
      });

      test('isPaused should return true when paused', () {
        const state = AudioState(playbackState: AudioPlaybackState.paused);
        expect(state.isPaused, true);
      });

      test('isLoading should return true when loading', () {
        const state = AudioState(playbackState: AudioPlaybackState.loading);
        expect(state.isLoading, true);
      });

      test('hasError should return true for playback error', () {
        const state = AudioState(playbackState: AudioPlaybackState.error);
        expect(state.hasError, true);
      });

      test('hasError should return true for voice input error', () {
        const state = AudioState(voiceInputState: VoiceInputState.error);
        expect(state.hasError, true);
      });

      test('hasError should return false when no errors', () {
        const state = AudioState();
        expect(state.hasError, false);
      });

      test('isListening should return true when listening', () {
        const state = AudioState(voiceInputState: VoiceInputState.listening);
        expect(state.isListening, true);
      });

      test('isProcessingVoice should return true when processing', () {
        const state = AudioState(voiceInputState: VoiceInputState.processing);
        expect(state.isProcessingVoice, true);
      });
    });

    group('Audio playback scenarios', () {
      test('should track speaking progress', () {
        const initial = AudioState();
        
        final speaking = initial.copyWith(
          playbackState: AudioPlaybackState.playing,
          currentText: 'This is a test',
          progress: 0.0,
        );
        expect(speaking.isPlaying, true);
        expect(speaking.progress, 0.0);

        final halfway = speaking.copyWith(progress: 0.5);
        expect(halfway.progress, 0.5);

        final complete = halfway.copyWith(
          progress: 1.0,
          playbackState: AudioPlaybackState.idle,
        );
        expect(complete.progress, 1.0);
        expect(complete.isPlaying, false);
      });

      test('should handle pause and resume', () {
        const playing = AudioState(
          playbackState: AudioPlaybackState.playing,
          currentText: 'Test',
          progress: 0.3,
        );

        final paused = playing.copyWith(
          playbackState: AudioPlaybackState.paused,
        );
        expect(paused.isPaused, true);
        expect(paused.progress, 0.3);

        final resumed = paused.copyWith(
          playbackState: AudioPlaybackState.playing,
        );
        expect(resumed.isPlaying, true);
      });

      test('should handle stop', () {
        const playing = AudioState(
          playbackState: AudioPlaybackState.playing,
          currentText: 'Test',
        );

        final stopped = playing.copyWith(
          playbackState: AudioPlaybackState.stopped,
          progress: 0.0,
        );
        expect(stopped.playbackState, AudioPlaybackState.stopped);
        expect(stopped.progress, 0.0);
      });
    });

    group('Voice input scenarios', () {
      test('should track voice recognition flow', () {
        const idle = AudioState();
        expect(idle.isListening, false);

        const listening = AudioState(
          voiceInputState: VoiceInputState.listening,
        );
        expect(listening.isListening, true);

        const processing = AudioState(
          voiceInputState: VoiceInputState.processing,
          recognizedText: 'next',
        );
        expect(processing.isProcessingVoice, true);
        expect(processing.recognizedText, 'next');

        const completed = AudioState(
          voiceInputState: VoiceInputState.completed,
          recognizedText: 'next',
          confidence: 0.92,
        );
        expect(completed.voiceInputState, VoiceInputState.completed);
        expect(completed.confidence, 0.92);
      });

      test('should handle permission states', () {
        const noPermission = AudioState(hasPermissions: false);
        expect(noPermission.hasPermissions, false);

        final granted = noPermission.copyWith(hasPermissions: true);
        expect(granted.hasPermissions, true);
      });

      test('should track confidence levels', () {
        const lowConfidence = AudioState(
          recognizedText: 'maybe',
          confidence: 0.4,
        );
        expect(lowConfidence.confidence, lessThan(0.5));

        const highConfidence = AudioState(
          recognizedText: 'yes',
          confidence: 0.95,
        );
        expect(highConfidence.confidence, greaterThan(0.9));
      });
    });

    group('Error handling', () {
      test('should handle playback error', () {
        const error = AudioState(
          playbackState: AudioPlaybackState.error,
          errorMessage: 'TTS failed',
        );

        expect(error.hasError, true);
        expect(error.errorMessage, 'TTS failed');
      });

      test('should handle voice input error', () {
        const error = AudioState(
          voiceInputState: VoiceInputState.error,
          errorMessage: 'Microphone not available',
        );

        expect(error.hasError, true);
        expect(error.errorMessage, 'Microphone not available');
      });

      test('should clear error on recovery', () {
        const error = AudioState(
          playbackState: AudioPlaybackState.error,
          errorMessage: 'Error occurred',
        );

        // Error state recovers to idle (errorMessage stays in state until next update)
        final recovered = error.copyWith(
          playbackState: AudioPlaybackState.idle,
        );

        expect(recovered.hasError, false);
        // Note: errorMessage persists in copyWith unless explicitly cleared
        expect(recovered.playbackState, AudioPlaybackState.idle);
      });
    });

    group('Available voices', () {
      test('should track available voices', () {
        const state = AudioState(
          availableVoices: ['en-US-Standard-A', 'en-US-Standard-B', 'en-GB-Standard-A'],
        );

        expect(state.availableVoices.length, 3);
        expect(state.availableVoices, contains('en-US-Standard-A'));
      });

      test('should update available voices', () {
        const initial = AudioState(availableVoices: []);

        final updated = initial.copyWith(
          availableVoices: ['voice1', 'voice2'],
        );

        expect(updated.availableVoices.length, 2);
      });
    });

    group('Availability states', () {
      test('should track service availability', () {
        const unavailable = AudioState(isAvailable: false);
        expect(unavailable.isAvailable, false);

        const available = AudioState(isAvailable: true);
        expect(available.isAvailable, true);
      });

      test('should combine availability and permissions', () {
        const fullyReady = AudioState(
          isAvailable: true,
          hasPermissions: true,
        );
        final canUseVoice = fullyReady.isAvailable && fullyReady.hasPermissions;
        expect(canUseVoice, true);

        const notReady = AudioState(
          isAvailable: true,
          hasPermissions: false,
        );
        final cannotUse = notReady.isAvailable && notReady.hasPermissions;
        expect(cannotUse, false);
      });
    });
  });
}

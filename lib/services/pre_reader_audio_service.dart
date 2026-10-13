import 'package:flutter/foundation.dart';
import 'package:learning_pwa/models/pre_reader_profile.dart';
import 'package:learning_pwa/services/audio_service.dart';

/// Audio coordinator specifically designed for Pre-Reader / Non-Literate learners.
///
/// Features:
/// - Immediate preemption (new tap cancels previous utterance instantly)
/// - Track-aware pitch and cadence (dignified adult vs playful youth)
/// - Pure phoneme and anchor word pronunciation
/// - Spoken UI announcements
class PreReaderAudioService {
  final AudioService _audioService;

  PreReaderAudioService({AudioService? audioService})
      : _audioService = audioService ?? AudioService();

  /// Speaks [text] aloud with parameters appropriate for the learner's [track].
  Future<void> speak(
    String text, {
    PreReaderTrack track = PreReaderTrack.adult,
    double? customRate,
  }) async {
    try {
      // Ensure audio service is initialized
      await _audioService.initialize();

      // Configure pitch and speed based on track
      final pitch = track == PreReaderTrack.youth ? 1.15 : 1.0;
      final speed = customRate ?? (track == PreReaderTrack.youth ? 0.9 : 0.85);

      await _audioService.updateSettings(
        _audioService.currentSettings.copyWith(
          pitch: pitch,
          speechRate: speed,
        ),
      );

      // Speak immediately, preempting any previous utterance
      await _audioService.speak(text, interrupt: true);
    } catch (e) {
      if (kDebugMode) {
        print('PreReaderAudioService error speaking "$text": $e');
      }
    }
  }

  /// Harmonizes global [AudioSettings] for pre-reader learners, ensuring
  /// questions and autoPlay are active by default.
  Future<void> enablePreReaderDefaults({
    PreReaderTrack track = PreReaderTrack.adult,
  }) async {
    try {
      await _audioService.initialize();
      final pitch = track == PreReaderTrack.youth ? 1.15 : 1.0;
      final speed = track == PreReaderTrack.youth ? 0.9 : 0.85;
      await _audioService.updateSettings(
        _audioService.currentSettings.copyWith(
          autoPlay: true,
          autoReadQuestions: true,
          pitch: pitch,
          speechRate: speed,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('PreReaderAudioService settings sync error: $e');
      }
    }
  }

  /// Speaks a phoneme sound and its associated anchor word.
  ///
  /// Example:
  /// Adult: "The sound is /m/. Like money."
  /// Youth: "The sound is /m/! Like monkey!"
  Future<void> speakPhoneme(
    String letter,
    String phonemeSound,
    String anchorWord, {
    PreReaderTrack track = PreReaderTrack.adult,
  }) async {
    final text = track == PreReaderTrack.youth
        ? 'The letter is $letter. It makes the sound $phonemeSound! Like $anchorWord!'
        : 'Letter $letter. Sound $phonemeSound. As in $anchorWord.';
    await speak(text, track: track);
  }

  /// Speaks the official letter name for spelling personal data on forms.
  Future<void> speakLetterName(
    String letter, {
    PreReaderTrack track = PreReaderTrack.adult,
  }) async {
    await speak('Letter $letter.', track: track);
  }

  /// Cancels any ongoing speech.
  Future<void> stop() async {
    try {
      await _audioService.stop();
    } catch (e) {
      if (kDebugMode) {
        print('PreReaderAudioService stop error: $e');
      }
    }
  }
}

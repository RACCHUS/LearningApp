import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/audio_lesson_settings.dart';
import 'package:learning_pwa/services/audio_lesson_orchestrator.dart';
import 'package:learning_pwa/models/content_types.dart';

// Audio Lesson Orchestrator Provider
final audioLessonOrchestratorProvider = Provider<AudioLessonOrchestrator>((ref) {
  return AudioLessonOrchestrator();
});

// Audio Lesson Settings Provider
class AudioLessonSettingsNotifier extends StateNotifier<AudioLessonSettings> {
  AudioLessonSettingsNotifier() : super(const AudioLessonSettings());

  void updateSettings(AudioLessonSettings newSettings) {
    state = newSettings;
    
    // Update the orchestrator with new settings
    final orchestrator = AudioLessonOrchestrator();
    orchestrator.updateSettings(newSettings);
  }

  void toggleHandsFreeMode() {
    updateSettings(state.copyWith(
      handsFreeModeEnabled: !state.handsFreeModeEnabled,
    ));
  }

  void setAutoProgressDelay(Duration delay) {
    updateSettings(state.copyWith(autoProgressDelay: delay));
  }

  void setVoiceInputTimeout(Duration timeout) {
    updateSettings(state.copyWith(voiceInputTimeout: timeout));
  }

  void toggleAutoReadAllContent() {
    updateSettings(state.copyWith(
      autoReadAllContent: !state.autoReadAllContent,
    ));
  }

  void toggleVoiceNavigation() {
    updateSettings(state.copyWith(
      voiceNavigationEnabled: !state.voiceNavigationEnabled,
    ));
  }

  void toggleConfirmations() {
    updateSettings(state.copyWith(
      confirmationsEnabled: !state.confirmationsEnabled,
    ));
  }

  void setPauseBetweenItems(double seconds) {
    updateSettings(state.copyWith(pauseBetweenItems: seconds));
  }

  void toggleAutoProgressAfterReading() {
    updateSettings(state.copyWith(
      autoProgressAfterReading: !state.autoProgressAfterReading,
    ));
  }

  void toggleImmediateAnswerProgression() {
    updateSettings(state.copyWith(
      immediateAnswerProgression: !state.immediateAnswerProgression,
    ));
  }

  void setVoiceRetryAttempts(int attempts) {
    updateSettings(state.copyWith(voiceRetryAttempts: attempts));
  }

  void toggleInterruptOnNextCommand() {
    updateSettings(state.copyWith(
      interruptOnNextCommand: !state.interruptOnNextCommand,
    ));
  }
}

final audioLessonSettingsProvider = StateNotifierProvider<AudioLessonSettingsNotifier, AudioLessonSettings>((ref) {
  return AudioLessonSettingsNotifier();
});

// Audio Lesson State Provider
class AudioLessonStateNotifier extends StateNotifier<AudioLessonState> {
  final AudioLessonOrchestrator _orchestrator;
  
  AudioLessonStateNotifier(this._orchestrator) : super(AudioLessonState.idle) {
    // Listen to orchestrator state changes
    _orchestrator.stateStream.listen((newState) {
      state = newState;
    });
  }

  Future<void> startLesson(List<LessonContent> contentList, {int startIndex = 0}) async {
    await _orchestrator.startLesson(contentList, startIndex: startIndex);
  }

  Future<void> stopLesson() async {
    await _orchestrator.stopLesson();
  }

  Future<void> pauseLesson() async {
    await _orchestrator.pauseLesson();
  }

  Future<void> resumeLesson() async {
    await _orchestrator.resumeLesson();
  }

  Future<void> nextContent() async {
    await _orchestrator.nextContent();
  }

  Future<void> previousContent() async {
    await _orchestrator.previousContent();
  }

  Future<void> repeatContent() async {
    await _orchestrator.repeatContent();
  }
}

final audioLessonStateProvider = StateNotifierProvider<AudioLessonStateNotifier, AudioLessonState>((ref) {
  final orchestrator = ref.watch(audioLessonOrchestratorProvider);
  return AudioLessonStateNotifier(orchestrator);
});

// Audio Lesson Progress Provider
class AudioLessonProgressNotifier extends StateNotifier<int> {
  final AudioLessonOrchestrator _orchestrator;
  
  AudioLessonProgressNotifier(this._orchestrator) : super(0) {
    // Listen to orchestrator progress changes
    _orchestrator.progressStream.listen((progress) {
      state = progress;
    });
  }
}

final audioLessonProgressProvider = StateNotifierProvider<AudioLessonProgressNotifier, int>((ref) {
  final orchestrator = ref.watch(audioLessonOrchestratorProvider);
  return AudioLessonProgressNotifier(orchestrator);
});

// Audio Lesson Actions Provider
class AudioLessonActionsNotifier extends StateNotifier<LessonFlowAction?> {
  final AudioLessonOrchestrator _orchestrator;
  
  AudioLessonActionsNotifier(this._orchestrator) : super(null) {
    // Listen to orchestrator action events
    _orchestrator.actionStream.listen((action) {
      state = action;
    });
  }

  void clearAction() {
    state = null;
  }
}

final audioLessonActionsProvider = StateNotifierProvider<AudioLessonActionsNotifier, LessonFlowAction?>((ref) {
  final orchestrator = ref.watch(audioLessonOrchestratorProvider);
  return AudioLessonActionsNotifier(orchestrator);
});

// Convenience providers for UI
final isAudioLessonActiveProvider = Provider<bool>((ref) {
  final orchestrator = ref.watch(audioLessonOrchestratorProvider);
  return orchestrator.isActive;
});

final audioLessonInfoProvider = Provider<Map<String, dynamic>>((ref) {
  final orchestrator = ref.watch(audioLessonOrchestratorProvider);
  final progress = ref.watch(audioLessonProgressProvider);
  
  return {
    'currentIndex': orchestrator.currentIndex,
    'totalContent': orchestrator.totalContent,
    'progress': progress,
    'isFirst': orchestrator.isFirstContent,
    'isLast': orchestrator.isLastContent,
    'isActive': orchestrator.isActive,
  };
});

final handsFreeModeProvider = Provider<bool>((ref) {
  final settings = ref.watch(audioLessonSettingsProvider);
  return settings.handsFreeModeEnabled;
});

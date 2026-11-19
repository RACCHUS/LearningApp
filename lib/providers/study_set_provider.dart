import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/core/logging/app_logger.dart';
import 'package:learning_pwa/services/saved_study_set_service.dart';

/// Provider for the SavedStudySetService
final savedStudySetServiceProvider = Provider<SavedStudySetService>((ref) {
  return SavedStudySetService();
});

/// State for managing study sets
class StudySetState {
  final List<SavedStudySet> studySets;
  final bool isLoading;
  final String? error;
  final SavedStudySet? selectedSet;
  final StudySetContent? selectedSetContent;
  final Map<String, StudySetProgress> progressBySetId;

  const StudySetState({
    this.studySets = const [],
    this.isLoading = false,
    this.error,
    this.selectedSet,
    this.selectedSetContent,
    this.progressBySetId = const {},
  });

  factory StudySetState.initial() => const StudySetState();

  StudySetState copyWith({
    List<SavedStudySet>? studySets,
    bool? isLoading,
    String? error,
    SavedStudySet? selectedSet,
    StudySetContent? selectedSetContent,
    Map<String, StudySetProgress>? progressBySetId,
    bool clearError = false,
    bool clearSelectedSet = false,
  }) {
    return StudySetState(
      studySets: studySets ?? this.studySets,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      selectedSet: clearSelectedSet ? null : (selectedSet ?? this.selectedSet),
      selectedSetContent: clearSelectedSet
          ? null
          : (selectedSetContent ?? this.selectedSetContent),
      progressBySetId: progressBySetId ?? this.progressBySetId,
    );
  }
}

/// Provider for managing saved study sets
final studySetProvider =
    StateNotifierProvider<StudySetNotifier, StudySetState>((ref) {
  final service = ref.watch(savedStudySetServiceProvider);
  return StudySetNotifier(service);
});

/// Notifier for study set operations
class StudySetNotifier extends StateNotifier<StudySetState> {
  final SavedStudySetService _service;
  final _logger = AppLogger('StudySetNotifier');

  StudySetNotifier(this._service) : super(StudySetState.initial());

  /// Load all study sets for the current user
  Future<void> loadStudySets() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final studySets = await _service.getUserStudySets();

      // Load progress for each study set
      final progressMap = <String, StudySetProgress>{};
      for (final set in studySets) {
        try {
          final progress = await _service.getProgress(set.id);
          progressMap[set.id] = progress;
        } catch (e) {
          _logger.warn('Failed to load progress for set ${set.id}: $e');
        }
      }

      state = state.copyWith(
        studySets: studySets,
        progressBySetId: progressMap,
        isLoading: false,
      );
    } catch (e, stack) {
      _logger.error('Failed to load study sets', error: e, stackTrace: stack);
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load study sets: $e',
      );
    }
  }

  /// Create a new study set from lesson IDs
  Future<SavedStudySet?> createStudySet({
    required String title,
    String? description,
    List<String> lessonIds = const [],
    List<String> tags = const [],
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final studySet = await _service.createStudySet(
        title: title,
        description: description,
        lessonIds: lessonIds,
        tags: tags,
      );

      // Refresh the list
      await loadStudySets();

      return studySet;
    } catch (e, stack) {
      _logger.error('Failed to create study set', error: e, stackTrace: stack);
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to create study set: $e',
      );
      return null;
    }
  }

  /// Create a new study set with specific content IDs (terms, questions, concepts)
  Future<SavedStudySet?> createStudySetWithContent({
    required String title,
    String? description,
    List<String> lessonIds = const [],
    List<String> termIds = const [],
    List<String> questionIds = const [],
    List<String> conceptIds = const [],
    List<String> tags = const [],
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final studySet = await _service.createStudySet(
        title: title,
        description: description,
        lessonIds: lessonIds,
        termIds: termIds,
        questionIds: questionIds,
        conceptIds: conceptIds,
        tags: tags,
      );

      // Refresh the list
      await loadStudySets();

      return studySet;
    } catch (e, stack) {
      _logger.error('Failed to create study set with content', error: e, stackTrace: stack);
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to create study set: $e',
      );
      return null;
    }
  }

  /// Select a study set and load its content
  Future<void> selectStudySet(SavedStudySet studySet) async {
    state = state.copyWith(
      selectedSet: studySet,
      isLoading: true,
      clearError: true,
    );

    try {
      final content = await _service.fetchStudySetContent(studySet);
      final progress = await _service.getProgress(studySet.id);

      final newProgressMap =
          Map<String, StudySetProgress>.from(state.progressBySetId);
      newProgressMap[studySet.id] = progress;

      state = state.copyWith(
        selectedSetContent: content,
        progressBySetId: newProgressMap,
        isLoading: false,
      );
    } catch (e, stack) {
      _logger.error('Failed to load study set content',
          error: e, stackTrace: stack);
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load study set content: $e',
      );
    }
  }

  /// Clear the selected study set
  void clearSelection() {
    state = state.copyWith(clearSelectedSet: true);
  }

  /// Delete a study set
  Future<bool> deleteStudySet(String studySetId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _service.deleteStudySet(studySetId);

      // If we deleted the selected set, clear selection
      if (state.selectedSet?.id == studySetId) {
        state = state.copyWith(clearSelectedSet: true);
      }

      // Refresh the list
      await loadStudySets();

      return true;
    } catch (e, stack) {
      _logger.error('Failed to delete study set', error: e, stackTrace: stack);
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to delete study set: $e',
      );
      return false;
    }
  }

  /// Record an answer for a study set item
  Future<void> recordAnswer({
    required String studySetId,
    required bool isCorrect,
  }) async {
    try {
      await _service.recordAnswer(
        studySetId: studySetId,
        isCorrect: isCorrect,
      );

      // Refresh progress
      final progress = await _service.getProgress(studySetId);
      final newProgressMap =
          Map<String, StudySetProgress>.from(state.progressBySetId);
      newProgressMap[studySetId] = progress;
      state = state.copyWith(progressBySetId: newProgressMap);
    } catch (e, stack) {
      _logger.error('Failed to record answer', error: e, stackTrace: stack);
    }
  }

  /// Get progress for a specific study set
  StudySetProgress? getProgressForSet(String studySetId) {
    return state.progressBySetId[studySetId];
  }
}

/// Convenience provider to get the list of study sets
final studySetsListProvider = Provider<List<SavedStudySet>>((ref) {
  return ref.watch(studySetProvider.select((s) => s.studySets));
});

/// Convenience provider for loading state
final studySetLoadingProvider = Provider<bool>((ref) {
  return ref.watch(studySetProvider.select((s) => s.isLoading));
});

/// Convenience provider for the currently selected study set
final selectedStudySetProvider = Provider<SavedStudySet?>((ref) {
  return ref.watch(studySetProvider.select((s) => s.selectedSet));
});

/// Convenience provider for the selected study set's content
final selectedStudySetContentProvider = Provider<StudySetContent?>((ref) {
  return ref.watch(studySetProvider.select((s) => s.selectedSetContent));
});

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/services/supabase_service.dart';

// Combined provider for lessons with efficient state management
final lessonsProvider = StateNotifierProvider<LessonsNotifier, LessonsState>((ref) {
  return LessonsNotifier();
});

class LessonsState {
  final List<Lesson> lessons;
  final List<String> selectedTags;
  final bool isLoading;
  final String? error;

  const LessonsState({
    this.lessons = const [],
    this.selectedTags = const [],
    this.isLoading = false,
    this.error,
  });

  LessonsState copyWith({
    List<Lesson>? lessons,
    List<String>? selectedTags,
    bool? isLoading,
    String? error,
  }) {
    return LessonsState(
      lessons: lessons ?? this.lessons,
      selectedTags: selectedTags ?? this.selectedTags,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class LessonsNotifier extends StateNotifier<LessonsState> {
  final SupabaseService _supabase;

  LessonsNotifier({SupabaseService? supabaseService})
      : _supabase = supabaseService ?? SupabaseService(),
        super(const LessonsState());

  Future<void> loadLessons() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _supabase.from('lessons').select('''
        *,
        lesson_terms(terms(*)),
        lesson_questions(questions(*)),
        lesson_concepts(concepts(*))
      ''');
      
      final lessons = response.map((json) => Lesson.fromJson(json)).toList();
      state = state.copyWith(lessons: lessons, isLoading: false, error: null);
      
      debugPrint('✅ Successfully loaded ${lessons.length} lessons');
    } catch (e, stackTrace) {
      final errorMsg = 'Failed to load lessons from database';
      debugPrint('$errorMsg - $e');
      debugPrint('Stack trace: $stackTrace');
      state = state.copyWith(error: errorMsg, isLoading: false);
    }
  }

  void filterByTags(List<String> tags) {
    state = state.copyWith(selectedTags: tags);
  }

  List<Lesson> get filteredLessons {
    if (state.selectedTags.isEmpty) return state.lessons;
    return state.lessons.where((lesson) {
      return lesson.tags.any((tag) => state.selectedTags.contains(tag));
    }).toList();
  }
}

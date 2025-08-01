import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/lesson_content.dart';

class LessonCreationState {
  final String title;
  final String description;
  final List<String> tags;
  final List<LessonContent> content;
  final bool isLoading;
  final String? error;

  const LessonCreationState({
    this.title = '',
    this.description = '',
    this.tags = const [],
    this.content = const [],
    this.isLoading = false,
    this.error,
  });

  LessonCreationState copyWith({
    String? title,
    String? description,
    List<String>? tags,
    List<LessonContent>? content,
    bool? isLoading,
    String? error,
  }) {
    return LessonCreationState(
      title: title ?? this.title,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      content: content ?? this.content,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class LessonCreationNotifier extends StateNotifier<LessonCreationState> {
  LessonCreationNotifier() : super(const LessonCreationState());

  void updateTitle(String title) {
    state = state.copyWith(title: title);
  }

  void updateDescription(String description) {
    state = state.copyWith(description: description);
  }

  void addTag(String tag) {
    if (!state.tags.contains(tag)) {
      state = state.copyWith(tags: [...state.tags, tag]);
    }
  }

  void removeTag(String tag) {
    state = state.copyWith(tags: state.tags.where((t) => t != tag).toList());
  }

  void addContent(LessonContent content) {
    state = state.copyWith(content: [...state.content, content]);
  }

  void removeContent(String contentId) {
    state = state.copyWith(
      content: state.content.where((c) => c.id != contentId).toList(),
    );
  }

  void updateContent(String contentId, LessonContent newContent) {
    final index = state.content.indexWhere((c) => c.id == contentId);
    if (index != -1) {
      final updatedContent = [...state.content];
      updatedContent[index] = newContent;
      state = state.copyWith(content: updatedContent);
    }
  }

  void reset() {
    state = const LessonCreationState();
  }

  void setLoading(bool isLoading) {
    state = state.copyWith(isLoading: isLoading);
  }

  void setError(String? error) {
    state = state.copyWith(error: error);
  }
}

final lessonCreationProvider = StateNotifierProvider<LessonCreationNotifier, LessonCreationState>(
  (ref) => LessonCreationNotifier(),
);

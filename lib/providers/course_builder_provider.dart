import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/course_models.dart';
import '../models/lesson.dart';
import '../services/course_service.dart';
import '../services/lesson_service.dart';

/// Represents a lesson with its association data for display in the builder
class CourseLessonItem {
  final Lesson lesson;
  final CourseLessonAssociation? association;
  final bool isRequired;
  final int order;

  const CourseLessonItem({
    required this.lesson,
    this.association,
    this.isRequired = true,
    required this.order,
  });

  CourseLessonItem copyWith({
    Lesson? lesson,
    CourseLessonAssociation? association,
    bool? isRequired,
    int? order,
  }) {
    return CourseLessonItem(
      lesson: lesson ?? this.lesson,
      association: association ?? this.association,
      isRequired: isRequired ?? this.isRequired,
      order: order ?? this.order,
    );
  }
}

/// State for the course builder
class CourseBuilderState {
  final String? courseId;
  final String title;
  final String description;
  final String category;
  final String difficulty;
  final List<String> tags;
  final String? imageUrl;
  final bool isPublic;
  final int estimatedHours;
  final List<CourseLessonItem> lessons;
  final bool isDirty;
  final bool isSaving;
  final bool isLoading;
  final String? errorMessage;

  const CourseBuilderState({
    this.courseId,
    this.title = '',
    this.description = '',
    this.category = 'General',
    this.difficulty = 'beginner',
    this.tags = const [],
    this.imageUrl,
    this.isPublic = false,
    this.estimatedHours = 0,
    this.lessons = const [],
    this.isDirty = false,
    this.isSaving = false,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isNewCourse => courseId == null;

  bool get isValid =>
      title.trim().length >= 3 && description.trim().isNotEmpty;

  int get totalLessons => lessons.length;

  CourseBuilderState copyWith({
    String? courseId,
    String? title,
    String? description,
    String? category,
    String? difficulty,
    List<String>? tags,
    String? imageUrl,
    bool? isPublic,
    int? estimatedHours,
    List<CourseLessonItem>? lessons,
    bool? isDirty,
    bool? isSaving,
    bool? isLoading,
    String? errorMessage,
  }) {
    return CourseBuilderState(
      courseId: courseId ?? this.courseId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      tags: tags ?? this.tags,
      imageUrl: imageUrl ?? this.imageUrl,
      isPublic: isPublic ?? this.isPublic,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      lessons: lessons ?? this.lessons,
      isDirty: isDirty ?? this.isDirty,
      isSaving: isSaving ?? this.isSaving,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// Notifier for managing course builder state
class CourseBuilderNotifier extends StateNotifier<CourseBuilderState> {
  final CourseService _courseService;
  final LessonService _lessonService;

  CourseBuilderNotifier({
    required CourseService courseService,
    required LessonService lessonService,
    String? courseId,
  })  : _courseService = courseService,
        _lessonService = lessonService,
        super(const CourseBuilderState()) {
    if (courseId != null) {
      _loadCourse(courseId);
    }
  }

  Future<void> _loadCourse(String courseId) async {
    state = state.copyWith(isLoading: true);
    try {
      final course = await _courseService.getCourse(courseId);
      final associations = await _courseService.getCourseLessons(courseId);

      // Load lesson details for each association
      final lessonItems = <CourseLessonItem>[];
      for (final assoc in associations) {
        try {
          final lesson = await _lessonService.getLesson(assoc.lessonId);
          lessonItems.add(CourseLessonItem(
            lesson: lesson,
            association: assoc,
            isRequired: assoc.isRequired,
            order: assoc.orderInCourse,
          ));
        } catch (e) {
          debugPrint('Warning: Could not load lesson ${assoc.lessonId}: $e');
        }
      }

      // Sort by order
      lessonItems.sort((a, b) => a.order.compareTo(b.order));

      state = CourseBuilderState(
        courseId: course.id,
        title: course.title,
        description: course.description,
        category: course.category,
        difficulty: course.difficulty,
        tags: course.tags,
        imageUrl: course.imageUrl,
        isPublic: course.isPublic,
        estimatedHours: course.estimatedHours,
        lessons: lessonItems,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load course: $e',
      );
    }
  }

  // ============================================================================
  // BASIC FIELDS
  // ============================================================================

  void setTitle(String title) {
    state = state.copyWith(title: title, isDirty: true);
  }

  void setDescription(String description) {
    state = state.copyWith(description: description, isDirty: true);
  }

  void setCategory(String category) {
    state = state.copyWith(category: category, isDirty: true);
  }

  void setDifficulty(String difficulty) {
    state = state.copyWith(difficulty: difficulty, isDirty: true);
  }

  void setIsPublic(bool isPublic) {
    state = state.copyWith(isPublic: isPublic, isDirty: true);
  }

  void setEstimatedHours(int hours) {
    state = state.copyWith(estimatedHours: hours, isDirty: true);
  }

  void setTags(List<String> tags) {
    state = state.copyWith(tags: tags, isDirty: true);
  }

  void addTag(String tag) {
    if (tag.trim().isEmpty) return;
    final newTags = [...state.tags, tag.trim()];
    state = state.copyWith(tags: newTags, isDirty: true);
  }

  void removeTag(String tag) {
    final newTags = state.tags.where((t) => t != tag).toList();
    state = state.copyWith(tags: newTags, isDirty: true);
  }

  // ============================================================================
  // LESSON MANAGEMENT
  // ============================================================================

  void addLesson(Lesson lesson) {
    // Check if lesson already exists
    if (state.lessons.any((item) => item.lesson.id == lesson.id)) {
      state = state.copyWith(
        errorMessage: 'This lesson is already in the course',
      );
      return;
    }

    final newOrder = state.lessons.isEmpty
        ? 0
        : state.lessons.map((l) => l.order).reduce((a, b) => a > b ? a : b) + 1;

    final newItem = CourseLessonItem(
      lesson: lesson,
      isRequired: true,
      order: newOrder,
    );

    final newLessons = [...state.lessons, newItem];
    state = state.copyWith(lessons: newLessons, isDirty: true);
  }

  void removeLesson(String lessonId) {
    final newLessons =
        state.lessons.where((item) => item.lesson.id != lessonId).toList();
    
    // Re-order remaining lessons
    for (int i = 0; i < newLessons.length; i++) {
      newLessons[i] = newLessons[i].copyWith(order: i);
    }

    state = state.copyWith(lessons: newLessons, isDirty: true);
  }

  void toggleLessonRequired(String lessonId) {
    final newLessons = state.lessons.map((item) {
      if (item.lesson.id == lessonId) {
        return item.copyWith(isRequired: !item.isRequired);
      }
      return item;
    }).toList();
    state = state.copyWith(lessons: newLessons, isDirty: true);
  }

  void reorderLessons(int oldIndex, int newIndex) {
    final newLessons = List<CourseLessonItem>.from(state.lessons);
    if (newIndex > oldIndex) newIndex--;
    final item = newLessons.removeAt(oldIndex);
    newLessons.insert(newIndex, item);

    // Update order values
    for (int i = 0; i < newLessons.length; i++) {
      newLessons[i] = newLessons[i].copyWith(order: i);
    }

    state = state.copyWith(lessons: newLessons, isDirty: true);
  }

  // ============================================================================
  // SAVE
  // ============================================================================

  Future<Course?> save() async {
    if (!state.isValid) {
      state = state.copyWith(
        errorMessage: 'Please enter a title and description',
      );
      return null;
    }

    state = state.copyWith(isSaving: true, errorMessage: null);

    try {
      Course course;

      if (state.isNewCourse) {
        // Create new course
        course = await _courseService.createCourse(
          title: state.title,
          description: state.description,
          category: state.category,
          difficulty: state.difficulty,
          tags: state.tags,
          imageUrl: state.imageUrl,
          isPublic: state.isPublic,
          estimatedHours: state.estimatedHours,
        );

        // Add lessons to course
        for (final item in state.lessons) {
          await _courseService.addLessonToCourse(
            courseId: course.id,
            lessonId: item.lesson.id,
            orderIndex: item.order,
            isRequired: item.isRequired,
          );
        }
      } else {
        // Update existing course - first get existing course to update
        final existingCourse = await _courseService.getCourse(state.courseId!);
        final updatedCourse = existingCourse.copyWith(
          title: state.title,
          description: state.description,
          category: state.category,
          difficulty: state.difficulty,
          tags: state.tags,
          imageUrl: state.imageUrl,
          isPublic: state.isPublic,
          estimatedHours: state.estimatedHours,
          updatedAt: DateTime.now(),
        );
        course = await _courseService.updateCourse(updatedCourse);

        // Update lesson associations
        // First remove lessons that are no longer in the course
        final existingAssociations =
            await _courseService.getCourseLessons(course.id);
        for (final assoc in existingAssociations) {
          if (!state.lessons.any((item) => item.lesson.id == assoc.lessonId)) {
            await _courseService.removeLessonFromCourse(
              course.id,
              assoc.lessonId,
            );
          }
        }

        // Add new lessons (note: order updates would require removing and re-adding)
        for (final item in state.lessons) {
          final existsAlready = existingAssociations.any(
            (a) => a.lessonId == item.lesson.id,
          );

          if (!existsAlready) {
            // New lesson - add it
            await _courseService.addLessonToCourse(
              courseId: course.id,
              lessonId: item.lesson.id,
              orderIndex: item.order,
              isRequired: item.isRequired,
            );
          }
          // Note: Order updates would require more complex logic
          // (remove and re-add with new order) - not implemented for now
        }
      }

      state = state.copyWith(
        courseId: course.id,
        isSaving: false,
        isDirty: false,
      );

      debugPrint('✅ Course saved: ${course.id}');
      return course;
    } catch (e) {
      debugPrint('❌ Error saving course: $e');
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Failed to save course: $e',
      );
      return null;
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

/// Provider for course builder
final courseBuilderProvider = StateNotifierProvider.autoDispose
    .family<CourseBuilderNotifier, CourseBuilderState, String?>(
  (ref, courseId) {
    final courseService = CourseService();
    final lessonService = LessonService();

    return CourseBuilderNotifier(
      courseService: courseService,
      lessonService: lessonService,
      courseId: courseId,
    );
  },
);

/// Provider for available lessons (lessons not yet in the course)
final availableLessonsProvider =
    FutureProvider.autoDispose.family<List<Lesson>, String?>((ref, courseId) async {
  final lessonService = LessonService();
  final courseService = CourseService();

  try {
    // Get user ID from Supabase auth
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('No user logged in for available lessons');
      return [];
    }

    final allLessons = await lessonService.getLessonsForUser(userId);

    if (courseId != null) {
      final associations = await courseService.getCourseLessons(courseId);
      final lessonIdsInCourse = associations.map((a) => a.lessonId).toSet();
      return allLessons
          .where((lesson) => !lessonIdsInCourse.contains(lesson.id))
          .toList();
    }

    return allLessons;
  } catch (e) {
    debugPrint('Error loading available lessons: $e');
    return [];
  }
});

/// Difficulty levels for courses
const courseDifficultyLevels = [
  'beginner',
  'intermediate',
  'advanced',
  'expert',
];

/// Common course categories
const courseCategories = [
  'General',
  'Language',
  'Science',
  'Mathematics',
  'History',
  'Technology',
  'Arts',
  'Business',
  'Health',
  'Other',
];

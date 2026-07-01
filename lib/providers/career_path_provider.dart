import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/career_path.dart';
import '../services/career_path_service.dart';

/// Service provider for CareerPathService
final careerPathServiceProvider = Provider<CareerPathService>((ref) {
  return CareerPathService();
});

/// All public career paths
final careerPathsProvider = FutureProvider<List<CareerPath>>((ref) async {
  final service = ref.read(careerPathServiceProvider);
  return service.getCareerPaths();
});

/// Featured career paths
final featuredCareerPathsProvider = FutureProvider<List<CareerPath>>((ref) async {
  final service = ref.read(careerPathServiceProvider);
  return service.getCareerPaths(featuredOnly: true);
});

/// Official career paths only
final officialCareerPathsProvider = FutureProvider<List<CareerPath>>((ref) async {
  final service = ref.read(careerPathServiceProvider);
  return service.getCareerPaths(officialOnly: true);
});

/// Single career path by ID
final careerPathProvider =
    FutureProvider.family<CareerPath, String>((ref, pathId) async {
  final service = ref.read(careerPathServiceProvider);
  return service.getCareerPath(pathId);
});

/// Career path by slug
final careerPathBySlugProvider =
    FutureProvider.family<CareerPath?, String>((ref, slug) async {
  final service = ref.read(careerPathServiceProvider);
  return service.getCareerPathBySlug(slug);
});

/// User's enrolled career paths
final userCareerPathsProvider =
    StateNotifierProvider<UserCareerPathsNotifier, AsyncValue<List<UserCareerPath>>>(
        (ref) {
  final service = ref.read(careerPathServiceProvider);
  return UserCareerPathsNotifier(service);
});

/// Progress for a specific career path
final careerPathProgressProvider =
    FutureProvider.family<CareerPathProgress, String>((ref, pathId) async {
  final service = ref.read(careerPathServiceProvider);
  return service.getCareerPathProgress(pathId);
});

/// Notifier for user's career path enrollments
class UserCareerPathsNotifier
    extends StateNotifier<AsyncValue<List<UserCareerPath>>> {
  final CareerPathService _service;

  UserCareerPathsNotifier(this._service) : super(const AsyncValue.loading()) {
    _loadEnrollments();
  }

  Future<void> _loadEnrollments() async {
    try {
      state = const AsyncValue.loading();
      final enrollments = await _service.getUserCareerPaths();
      state = AsyncValue.data(enrollments);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _loadEnrollments();
  }

  Future<void> enroll(String pathId) async {
    try {
      await _service.enrollInCareerPath(pathId);
      await _loadEnrollments();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateStatus(String pathId, CareerPathStatus status) async {
    try {
      await _service.updateEnrollmentStatus(pathId, status);
      await _loadEnrollments();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> leave(String pathId) async {
    try {
      await _service.leaveCareerPath(pathId);
      await _loadEnrollments();
    } catch (e) {
      rethrow;
    }
  }

  /// Check if user is enrolled in a specific path
  bool isEnrolled(String pathId) {
    return state.maybeWhen(
      data: (paths) => paths.any((p) => p.careerPathId == pathId),
      orElse: () => false,
    );
  }

  /// Get enrollment for a specific path
  UserCareerPath? getEnrollment(String pathId) {
    return state.maybeWhen(
      data: (paths) {
        try {
          return paths.firstWhere((p) => p.careerPathId == pathId);
        } catch (_) {
          return null;
        }
      },
      orElse: () => null,
    );
  }
}

/// Career path creation/editing state
class CareerPathEditorState {
  final String? id;
  final String title;
  final String slug;
  final String description;
  final String? imageUrl;
  final int estimatedMonths;
  final bool isPublic;
  final List<String> courseIds;
  final List<String> skillIds;
  final bool isSaving;
  final String? error;

  const CareerPathEditorState({
    this.id,
    this.title = '',
    this.slug = '',
    this.description = '',
    this.imageUrl,
    this.estimatedMonths = 6,
    this.isPublic = false,
    this.courseIds = const [],
    this.skillIds = const [],
    this.isSaving = false,
    this.error,
  });

  bool get isNew => id == null;

  CareerPathEditorState copyWith({
    String? id,
    String? title,
    String? slug,
    String? description,
    String? imageUrl,
    int? estimatedMonths,
    bool? isPublic,
    List<String>? courseIds,
    List<String>? skillIds,
    bool? isSaving,
    String? error,
  }) {
    return CareerPathEditorState(
      id: id ?? this.id,
      title: title ?? this.title,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      estimatedMonths: estimatedMonths ?? this.estimatedMonths,
      isPublic: isPublic ?? this.isPublic,
      courseIds: courseIds ?? this.courseIds,
      skillIds: skillIds ?? this.skillIds,
      isSaving: isSaving ?? this.isSaving,
      error: error,
    );
  }
}

/// Provider for career path editor
final careerPathEditorProvider =
    StateNotifierProvider<CareerPathEditorNotifier, CareerPathEditorState>(
        (ref) {
  final service = ref.read(careerPathServiceProvider);
  return CareerPathEditorNotifier(service);
});

class CareerPathEditorNotifier extends StateNotifier<CareerPathEditorState> {
  final CareerPathService _service;

  CareerPathEditorNotifier(this._service)
      : super(const CareerPathEditorState());

  void reset() {
    state = const CareerPathEditorState();
  }

  void loadForEdit(CareerPath path) {
    state = CareerPathEditorState(
      id: path.id,
      title: path.title,
      slug: path.slug,
      description: path.description ?? '',
      imageUrl: path.imageUrl,
      estimatedMonths: path.estimatedMonths,
      isPublic: path.isPublic,
      courseIds: path.courses?.map((c) => c.courseId).toList() ?? [],
      skillIds: path.skills?.map((s) => s.skillId).toList() ?? [],
    );
  }

  void updateTitle(String title) {
    state = state.copyWith(title: title);
  }

  void updateSlug(String slug) {
    state = state.copyWith(slug: slug);
  }

  void updateDescription(String description) {
    state = state.copyWith(description: description);
  }

  void updateImageUrl(String? imageUrl) {
    state = state.copyWith(imageUrl: imageUrl);
  }

  void updateEstimatedMonths(int months) {
    state = state.copyWith(estimatedMonths: months);
  }

  void updateIsPublic(bool isPublic) {
    state = state.copyWith(isPublic: isPublic);
  }

  void addCourse(String courseId) {
    if (!state.courseIds.contains(courseId)) {
      state = state.copyWith(courseIds: [...state.courseIds, courseId]);
    }
  }

  void removeCourse(String courseId) {
    state = state.copyWith(
      courseIds: state.courseIds.where((id) => id != courseId).toList(),
    );
  }

  void reorderCourses(List<String> courseIds) {
    state = state.copyWith(courseIds: courseIds);
  }

  void addSkill(String skillId) {
    if (!state.skillIds.contains(skillId)) {
      state = state.copyWith(skillIds: [...state.skillIds, skillId]);
    }
  }

  void removeSkill(String skillId) {
    state = state.copyWith(
      skillIds: state.skillIds.where((id) => id != skillId).toList(),
    );
  }

  Future<CareerPath?> save() async {
    if (state.title.isEmpty || state.slug.isEmpty) {
      state = state.copyWith(error: 'Title and slug are required');
      return null;
    }

    state = state.copyWith(isSaving: true, error: null);

    try {
      CareerPath path;

      if (state.isNew) {
        path = await _service.createCareerPath(
          title: state.title,
          slug: state.slug,
          description: state.description.isEmpty ? null : state.description,
          imageUrl: state.imageUrl,
          estimatedMonths: state.estimatedMonths,
          isPublic: state.isPublic,
        );
      } else {
        path = await _service.updateCareerPath(
          state.id!,
          title: state.title,
          description: state.description.isEmpty ? null : state.description,
          imageUrl: state.imageUrl,
          estimatedMonths: state.estimatedMonths,
          isPublic: state.isPublic,
        );
      }

      // Update courses
      for (int i = 0; i < state.courseIds.length; i++) {
        await _service.addCourseToPath(
          pathId: path.id,
          courseId: state.courseIds[i],
          orderIndex: i,
        );
      }

      // Update skills
      for (final skillId in state.skillIds) {
        await _service.addSkillToPath(
          pathId: path.id,
          skillId: skillId,
        );
      }

      state = state.copyWith(isSaving: false);
      return path;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return null;
    }
  }
}

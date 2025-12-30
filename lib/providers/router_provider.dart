import 'package:learning_pwa/screens/settings_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/screens/home_screen.dart';
import 'package:learning_pwa/screens/lessons/create_lesson_screen.dart';
import 'package:learning_pwa/screens/lesson_editor_screen.dart';
import 'package:learning_pwa/screens/course_builder_screen.dart';
import 'package:learning_pwa/screens/study/lesson_screen.dart';
import 'package:learning_pwa/screens/study/study_set_screen.dart';
import 'package:learning_pwa/screens/lessons/lesson_selection_screen.dart';
import 'package:learning_pwa/screens/auth/login_screen.dart';
import 'package:learning_pwa/screens/profile_screen.dart';
import 'package:learning_pwa/screens/test/hands_free_test_screen.dart';
import 'package:learning_pwa/screens/course_management_screen.dart';
import 'package:learning_pwa/screens/courses/course_detail_screen.dart';
import 'package:learning_pwa/screens/study_sets/content_picker_screen.dart';
import 'package:learning_pwa/screens/progress/progress_dashboard_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      // Home route
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) {
          final searchQuery = state.uri.queryParameters['search'];
          final filter = state.uri.queryParameters['filter'];
          return HomeScreen(
              initialSearchQuery: searchQuery, initialFilter: filter);
        },
      ),

      // Create lesson route
      GoRoute(
        path: '/create-lesson',
        name: 'create-lesson',
        builder: (context, state) => const CreateLessonScreen(),
      ),

      // Course management route
      GoRoute(
        path: '/course-management',
        name: 'course-management',
        builder: (context, state) => const CourseManagementScreen(),
      ),

      // Course detail route
      GoRoute(
        path: '/courses/:courseId',
        name: 'course-detail',
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          return CourseDetailScreen(courseId: courseId);
        },
      ),

      // Study lesson route - this will show lesson content
      GoRoute(
        path: '/lesson/:lessonId',
        name: 'study-lesson',
        builder: (context, state) {
          final lessonId = state.pathParameters['lessonId']!;
          return LessonScreen(lessonId: lessonId);
        },
      ),

      // Alternative study modes could be added here
      GoRoute(
        path: '/lesson/:lessonId/study',
        name: 'lesson-study-mode',
        builder: (context, state) {
          final lessonId = state.pathParameters['lessonId']!;
          return LessonScreen(lessonId: lessonId);
        },
      ),
      GoRoute(
        path: '/study-set',
        name: 'study-set',
        builder: (context, state) {
          final idsParam = state.uri.queryParameters['ids'] ?? '';
          final lessonIds =
              idsParam.isNotEmpty ? idsParam.split(',') : <String>[];
          return StudySetScreen(lessonIds: lessonIds);
        },
      ),
      GoRoute(
        path: '/content-picker',
        name: 'content-picker',
        builder: (context, state) {
          final idsParam = state.uri.queryParameters['ids'] ?? '';
          final lessonIds =
              idsParam.isNotEmpty ? idsParam.split(',') : <String>[];
          final title = state.uri.queryParameters['title'];
          return ContentPickerScreen(lessonIds: lessonIds, title: title);
        },
      ),
      GoRoute(
        path: '/lesson-selection',
        name: 'lesson-selection',
        builder: (context, state) => const LessonSelectionScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/progress',
        name: 'progress-dashboard',
        builder: (context, state) => const ProgressDashboardScreen(),
      ),
      GoRoute(
        path: '/test/hands-free',
        name: 'hands-free-test',
        builder: (context, state) => const HandsFreeTestScreen(),
      ),

      // Lesson editor routes
      GoRoute(
        path: '/lesson-editor',
        name: 'lesson-editor-new',
        builder: (context, state) => const LessonEditorScreen(),
      ),
      GoRoute(
        path: '/lesson-editor/:lessonId',
        name: 'lesson-editor',
        builder: (context, state) {
          final lessonId = state.pathParameters['lessonId'];
          return LessonEditorScreen(lessonId: lessonId);
        },
      ),

      // Course builder routes
      GoRoute(
        path: '/course-builder',
        name: 'course-builder-new',
        builder: (context, state) => const CourseBuilderScreen(),
      ),
      GoRoute(
        path: '/course-builder/:courseId',
        name: 'course-builder',
        builder: (context, state) {
          final courseId = state.pathParameters['courseId'];
          return CourseBuilderScreen(courseId: courseId);
        },
      ),
    ],

    // Error handling
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page not found: ${state.error}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});

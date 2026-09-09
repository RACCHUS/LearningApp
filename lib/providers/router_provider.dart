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
import 'package:learning_pwa/screens/study_sets/saved_study_sets_screen.dart';
import 'package:learning_pwa/screens/progress/progress_dashboard_screen.dart';
import 'package:learning_pwa/screens/careers/career_paths_screen.dart';
import 'package:learning_pwa/screens/careers/career_path_create_screen.dart';
import 'package:learning_pwa/screens/careers/career_path_detail_screen.dart';
import 'package:learning_pwa/screens/careers/my_careers_screen.dart';
import 'package:learning_pwa/screens/skills/skills_profile_screen.dart';
import 'package:learning_pwa/screens/skills/skill_detail_screen.dart';
import 'package:learning_pwa/screens/assessment/assessment_screen.dart';
import 'package:learning_pwa/screens/settings/reset_center_screen.dart';
import 'package:learning_pwa/screens/lessons/guided_generation_screen.dart';
import 'package:learning_pwa/screens/onboarding/onboarding_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      if (state.matchedLocation == '/onboarding') return null;
      final onboarded = await hasCompletedOnboarding();
      if (!onboarded) return '/onboarding';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
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
        builder: (context, state) {
          final tabParam = state.uri.queryParameters['tab'];
          final contentParam = state.uri.queryParameters['content'];

          int initialTab = 0;
          int initialBuilderTab = 0;

          if (tabParam == 'json') {
            initialTab = 1;
          } else if (tabParam == 'manual') {
            initialTab = 2;
          }

          if (contentParam == 'mcq' || contentParam == 'question') {
            initialBuilderTab = 1;
          } else if (contentParam == 'concept') {
            initialBuilderTab = 2;
          } else {
            initialBuilderTab = 0;
          }

          return CreateLessonScreen(
            initialTabIndex: initialTab,
            initialBuilderTabIndex: initialBuilderTab,
          );
        },
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
        path: '/study-sets',
        name: 'study-sets',
        builder: (context, state) => const SavedStudySetsScreen(),
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
        builder: (context, state) {
          final tabParam = state.uri.queryParameters['tab'];
          int initialTab = 0;
          if (tabParam == 'mcq' || tabParam == 'question') {
            initialTab = 1;
          } else if (tabParam == 'concept') {
            initialTab = 2;
          }

          return LessonEditorScreen(initialTabIndex: initialTab);
        },
      ),
      GoRoute(
        path: '/lesson-editor/:lessonId',
        name: 'lesson-editor',
        builder: (context, state) {
          final lessonId = state.pathParameters['lessonId'];
          final tabParam = state.uri.queryParameters['tab'];
          int initialTab = 0;
          if (tabParam == 'mcq' || tabParam == 'question') {
            initialTab = 1;
          } else if (tabParam == 'concept') {
            initialTab = 2;
          }

          return LessonEditorScreen(
            lessonId: lessonId,
            initialTabIndex: initialTab,
          );
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

      // Career paths routes
      GoRoute(
        path: '/careers',
        name: 'career-paths',
        builder: (context, state) => const CareerPathsScreen(),
      ),
      // NOTE: Must be registered BEFORE the `/careers/:careerPathId` route
      // so the literal `create` segment wins over the path parameter.
      GoRoute(
        path: '/careers/create',
        name: 'career-path-create',
        builder: (context, state) => const CareerPathCreateScreen(),
      ),
      GoRoute(
        path: '/careers/:careerPathId',
        name: 'career-path-detail',
        builder: (context, state) {
          final careerPathId = state.pathParameters['careerPathId']!;
          return CareerPathDetailScreen(pathId: careerPathId);
        },
      ),
      GoRoute(
        path: '/my-careers',
        name: 'my-careers',
        builder: (context, state) => const MyCareersScreen(),
      ),

      // Skills routes
      GoRoute(
        path: '/skills',
        name: 'skills-profile',
        builder: (context, state) => const SkillsProfileScreen(),
      ),
      GoRoute(
        path: '/skills/:skillSlug',
        name: 'skill-detail',
        builder: (context, state) {
          final skillSlug = state.pathParameters['skillSlug']!;
          return SkillDetailScreen(skillSlug: skillSlug);
        },
      ),

      // Assessment route
      GoRoute(
        path: '/assess/:assessmentId',
        name: 'assessment',
        builder: (context, state) {
          final assessmentId = state.pathParameters['assessmentId']!;
          return AssessmentScreen(assessmentId: assessmentId);
        },
      ),

      // Guided generation route
      GoRoute(
        path: '/guided-generation',
        name: 'guided-generation',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          return GuidedGenerationScreen(
            initialSubject: q['subject'],
            initialAudience: q['audience'],
            initialDuration: int.tryParse(q['duration'] ?? ''),
            initialDifficulty: q['difficulty'],
            initialFocus: q['focus'],
          );
        },
      ),

      // Reset center route
      GoRoute(
        path: '/settings/reset',
        name: 'reset-center',
        builder: (context, state) => const ResetCenterScreen(),
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

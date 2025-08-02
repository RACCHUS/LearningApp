import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/screens/home_screen.dart';
import 'package:learning_pwa/screens/lessons/create_lesson_screen.dart';
import 'package:learning_pwa/screens/study/lesson_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      // Home route
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      
      // Create lesson route
      GoRoute(
        path: '/create-lesson',
        name: 'create-lesson',
        builder: (context, state) => const CreateLessonScreen(),
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

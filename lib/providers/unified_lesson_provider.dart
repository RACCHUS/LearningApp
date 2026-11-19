import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/unified_lesson.dart';
import 'package:learning_pwa/services/lesson/content_loading_service.dart';
import 'package:learning_pwa/providers/available_lessons_provider.dart';

final contentLoadingServiceProvider = Provider<ContentLoadingService>((ref) {
  return ContentLoadingService();
});

final unifiedLessonProvider =
    FutureProvider.family<UnifiedLesson, String>((ref, lessonId) async {
  final service = ref.watch(contentLoadingServiceProvider);
  try {
    return await service.loadUnifiedLesson(lessonId);
  } catch (e, stack) {
    log('⚠️ Failed to load online unified lesson, checking asset fallback: $e',
        name: 'UnifiedLessonProvider', error: e, stackTrace: stack);
    
    // Check asset lessons fallback
    try {
      final assetLessons = await ref.read(assetLessonsProvider.future);
      for (final asset in assetLessons) {
        if (asset.id == lessonId) {
          log('✅ Loaded asset lesson fallback for unified provider: $lessonId',
              name: 'UnifiedLessonProvider');
          final unified = UnifiedLesson(
            lesson: asset,
          );
          return unified;
        }
      }
    } catch (assetErr) {
      log('Asset lesson fallback error: $assetErr', name: 'UnifiedLessonProvider');
    }
    rethrow;
  }
});

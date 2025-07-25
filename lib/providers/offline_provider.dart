import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/services/hive_service.dart';

final offlineProvider = StateNotifierProvider<OfflineNotifier, OfflineState>((ref) {
  return OfflineNotifier(ref.read(hiveServiceProvider));
});

final hiveServiceProvider = Provider<HiveService>((ref) {
  return HiveService();
});

class OfflineNotifier extends StateNotifier<OfflineState> {
  final HiveService _hiveService;

  OfflineNotifier(this._hiveService) : super(OfflineInitial());

  Future<void> init() async {
    await _hiveService.init();
  }

  Future<void> cacheLesson(Lesson lesson) async {
    try {
      await _hiveService.cacheLesson(lesson);
    } catch (e) {
      // Handle error
    }
  }

  Future<Lesson?> getLesson(String lessonId) async {
    try {
      return await _hiveService.getLesson(lessonId);
    } catch (e) {
      // Handle error
      return null;
    }
  }
}

abstract class OfflineState {}

class OfflineInitial extends OfflineState {}

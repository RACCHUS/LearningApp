import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/user_progress.dart';
import 'package:learning_pwa/services/hive_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final offlineProvider =
    StateNotifierProvider<OfflineNotifier, OfflineState>((ref) {
  return OfflineNotifier(ref.read(hiveServiceProvider));
});

final hiveServiceProvider = Provider<HiveService>((ref) {
  return HiveService();
});

class OfflineNotifier extends StateNotifier<OfflineState> {
  final HiveService _hiveService;
  final _supabase = Supabase.instance.client;

  OfflineNotifier(this._hiveService) : super(OfflineInitial()) {
    Connectivity().onConnectivityChanged.listen((connectivityResult) {
      if (connectivityResult != ConnectivityResult.none) {
        syncProgress();
      }
    });
  }

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

  Future<void> cacheProgress(UserProgress progress) async {
    await _hiveService.cacheProgress(progress);
  }

  Future<void> syncProgress() async {
    final offlineProgress = await _hiveService.getProgress();
    if (offlineProgress.isNotEmpty) {
      try {
        await _supabase.from('user_progress').upsert(
              offlineProgress.map((e) => e.toJson()).toList(),
            );
        await _hiveService.clearProgress();
      } catch (e) {
        // Handle error
      }
    }
  }
}

abstract class OfflineState {}

class OfflineInitial extends OfflineState {}

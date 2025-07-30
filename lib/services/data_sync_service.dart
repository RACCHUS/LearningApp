import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/concept.dart';
import 'package:learning_pwa/models/mcq.dart';
import 'package:learning_pwa/models/user_progress.dart';
import 'package:learning_pwa/services/hive_service.dart';
import 'package:learning_pwa/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DataSyncService {
  final SupabaseClient _supabase;
  final HiveService _hiveService;
  final String _userId;

  DataSyncService({
    required SupabaseClient supabase,
    required HiveService hiveService,
    required String userId,
  })  : _supabase = supabase,
        _hiveService = hiveService,
        _userId = userId;

  /// Sync all data with the server
  Future<void> syncAllData() async {
    try {
      // Sync lessons
      await _syncLessons();
      
      // Sync concepts
      await _syncConcepts();
      
      // Sync MCQs
      await _syncMcqs();
      
      // Sync progress
      await _syncProgress();
    } catch (e) {
      throw Exception('Failed to sync data: $e');
    }
  }

  /// Sync lessons with the server
  Future<void> _syncLessons() async {
    try {
      // Fetch lessons from Supabase
      final response = await _supabase
          .from('lessons')
          .select()
          .order('created_at', ascending: false);
      
      if (response != null) {
        final lessons = (response as List)
            .map((json) => Lesson.fromJson(json))
            .toList();
        
        // Cache lessons locally
        await _hiveService.cacheLessons(lessons);
      }
    } catch (e) {
      throw Exception('Failed to sync lessons: $e');
    }
  }

  /// Sync concepts with the server
  Future<void> _syncConcepts() async {
    try {
      // Fetch concepts from Supabase
      final response = await _supabase
          .from('concepts')
          .select()
          .order('created_at', ascending: false);
      
      if (response != null) {
        final concepts = (response as List)
            .map((json) => Concept.fromJson(json))
            .toList();
        
        // Cache concepts locally
        await _hiveService.cacheConcepts(concepts);
      }
    } catch (e) {
      throw Exception('Failed to sync concepts: $e');
    }
  }

  /// Sync MCQs with the server
  Future<void> _syncMcqs() async {
    try {
      // Fetch MCQs from Supabase
      final response = await _supabase
          .from('mcqs')
          .select()
          .order('created_at', ascending: false);
      
      if (response != null) {
        final mcqs = (response as List)
            .map((json) => Mcq.fromJson(json))
            .toList();
        
        // Cache MCQs locally
        await _hiveService.cacheMcqs(mcqs);
      }
    } catch (e) {
      throw Exception('Failed to sync MCQs: $e');
    }
  }

  /// Sync user progress with the server
  Future<void> _syncProgress() async {
    try {
      // 1. Push local unsynced progress to server
      final unsyncedProgress = await _hiveService.getUnsyncedProgress();
      
      if (unsyncedProgress.isNotEmpty) {
        for (final progress in unsyncedProgress) {
          await _supabase.from('user_progress').upsert(progress.toJson());
        }
        
        // Mark as synced
        await _hiveService.markProgressAsSynced(
          unsyncedProgress.map((p) => p.id).toList(),
        );
      }
      
      // 2. Pull latest progress from server
      final response = await _supabase
          .from('user_progress')
          .select()
          .eq('user_id', _userId)
          .order('date', ascending: false);
      
      if (response != null) {
        final serverProgress = (response as List)
            .map((json) => UserProgress.fromJson(json))
            .toList();
        
        // Cache server progress locally
        for (final progress in serverProgress) {
          await _hiveService.cacheProgress(progress);
        }
      }
    } catch (e) {
      throw Exception('Failed to sync progress: $e');
    }
  }
  
  /// Get initial data for offline use
  Future<void> getInitialData() async {
    try {
      await Future.wait([
        _syncLessons(),
        _syncConcepts(),
        _syncMcqs(),
        _syncProgress(),
      ]);
    } catch (e) {
      throw Exception('Failed to get initial data: $e');
    }
  }
}

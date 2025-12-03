import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:learning_pwa/models/concept.dart';
import 'package:learning_pwa/models/concept_adapter.dart' as concept_adapter;
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/mcq.dart';
import 'package:learning_pwa/models/term_content.dart';
import 'package:learning_pwa/models/question_content.dart';
import 'package:learning_pwa/models/concept_content.dart';
import 'package:learning_pwa/models/lesson_progress.dart';
import 'package:learning_pwa/models/audio_settings.dart';
import 'package:learning_pwa/models/local_lesson.dart';

// Register Hive adapters for all models
void registerHiveAdapters() {
  // Register adapters if not already registered
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(LessonAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(concept_adapter.ConceptAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(McqAdapter());
  }
  if (!Hive.isAdapterRegistered(4)) {
    Hive.registerAdapter(TermContentAdapter());
  }
  if (!Hive.isAdapterRegistered(5)) {
    Hive.registerAdapter(QuestionContentAdapter());
  }
  if (!Hive.isAdapterRegistered(6)) {
    Hive.registerAdapter(ConceptContentAdapter());
  }
  if (!Hive.isAdapterRegistered(9)) {
    Hive.registerAdapter(LocalLessonAdapter());
  }
  if (!Hive.isAdapterRegistered(20)) {
    Hive.registerAdapter(AudioSettingsAdapter());
  }
  // UserProgress adapter should be registered if it exists
  // Add other adapters as needed
}

// Global instance to be initialized in main.dart
late final HiveService hiveService;

final hiveServiceProvider = Provider<HiveService>((ref) {
  return hiveService;
});

class HiveService {
  static const String _lessonsBox = 'lessons';
  static const String _localLessonsBox = 'local_lessons';
  static const String _conceptsBox = 'concepts';
  static const String _mcqsBox = 'mcqs';
  static const String _progressBox = 'progress';
  
  late final Box<Lesson> _lessonBox;
  late final Box<LocalLesson> _localLessonBox;
  late final Box<Concept> _conceptBox;
  late final Box<Mcq> _mcqBox;
  late final Box<UserProgress> _progressBoxInstance;
  
  Future<void> init() async {
    try {
      await Hive.initFlutter();
      
      // Open all boxes
      _lessonBox = await Hive.openBox<Lesson>(_lessonsBox);
      _localLessonBox = await Hive.openBox<LocalLesson>(_localLessonsBox);
      _conceptBox = await Hive.openBox<Concept>(_conceptsBox);
      _mcqBox = await Hive.openBox<Mcq>(_mcqsBox);
      _progressBoxInstance = await Hive.openBox<UserProgress>(_progressBox);
      
      debugPrint('✅ HiveService initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to initialize HiveService - $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Lesson methods
  Future<void> cacheLesson(Lesson lesson) async {
    try {
      await _lessonBox.put(lesson.id, lesson);
    } catch (e, stackTrace) {
      debugPrint('Failed to cache lesson: ${lesson.title} - $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<List<Lesson>> getOfflineLessons(String userId) async {
    return _lessonBox.values
        .where((lesson) => lesson.userId == userId)
        .toList();
  }

  Future<bool> isLessonOffline(String lessonId) async {
    return _lessonBox.containsKey(lessonId);
  }

  Future<void> deleteLessonOffline(String lessonId) async {
    await _lessonBox.delete(lessonId);
  }

  Future<void> clearOfflineLessons() async {
    await _lessonBox.clear();
  }
  
  Future<void> cacheLessons(List<Lesson> lessons) async {
    await _lessonBox.putAll(Map.fromEntries(
      lessons.map((lesson) => MapEntry(lesson.id, lesson)),
    ));
  }
  
  Future<Lesson?> getLesson(String lessonId) async {
    try {
      return _lessonBox.get(lessonId);
    } catch (e, stackTrace) {
      debugPrint('Failed to get lesson: $lessonId - $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }
  
  Future<List<Lesson>> getAllLessons() async {
    return _lessonBox.values.toList();
  }
  
  Future<List<Lesson>> searchLessons(String query) async {
    final normalizedQuery = query.toLowerCase();
    return _lessonBox.values
        .where((lesson) => 
          lesson.title.toLowerCase().contains(normalizedQuery) ||
          (lesson.description?.toLowerCase().contains(normalizedQuery) ?? false) ||
          lesson.tags.any((tag) => tag.toLowerCase().contains(normalizedQuery)))
        .toList();
  }

  Future<void> saveLesson(Lesson lesson) async {
    await _lessonBox.put(lesson.id, lesson);
  }

  // LocalLesson methods
  Future<void> cacheLocalLesson(LocalLesson lesson) async {
    await _localLessonBox.put(lesson.id, lesson);
  }

  Future<List<LocalLesson>> getLocalLessons(String userId) async {
    return _localLessonBox.values
        .where((lesson) => lesson.userId == userId)
        .toList();
  }

  Future<LocalLesson?> getLocalLesson(String lessonId) async {
    return _localLessonBox.get(lessonId);
  }

  Future<void> deleteLocalLesson(String lessonId) async {
    await _localLessonBox.delete(lessonId);
  }

  Future<void> saveProgress(UserProgress progress) async {
    await _progressBoxInstance.put(progress.id, progress);
  }

  // Concept methods
  Future<void> cacheConcept(Concept concept) async {
    await _conceptBox.put(concept.id, concept);
  }
  
  Future<void> cacheConcepts(List<Concept> concepts) async {
    await _conceptBox.putAll(Map.fromEntries(
      concepts.map((concept) => MapEntry(concept.id, concept)),
    ));
  }
  
  Future<Concept?> getConcept(String conceptId) async {
    return _conceptBox.get(conceptId);
  }
  
  Future<List<Concept>> getConceptsByLesson(String lessonId) async {
    final concepts = _conceptBox.values.toList();
    return concepts.where((concept) => concept.lessonId == lessonId).toList();
  }
  
  // MCQ methods
  Future<void> cacheMcq(Mcq mcq) async {
    await _mcqBox.put(mcq.id, mcq);
  }
  
  Future<void> cacheMcqs(List<Mcq> mcqs) async {
    await _mcqBox.putAll(Map.fromEntries(
      mcqs.map((mcq) => MapEntry(mcq.id, mcq)),
    ));
  }
  
  Future<Mcq?> getMcq(String mcqId) async {
    return _mcqBox.get(mcqId);
  }
  
  Future<List<Mcq>> getMcqsByLesson(String lessonId) async {
    final mcqs = _mcqBox.values.toList();
    return mcqs.where((mcq) => mcq.lessonId == lessonId).toList();
  }
  
  // Progress methods
  Future<void> cacheProgress(UserProgress progress) async {
    try {
      final existing = _progressBoxInstance.get(progress.id);
      
      // If progress exists, merge with existing data
      if (existing != null) {
        final merged = _mergeProgress(existing, progress);
        await _progressBoxInstance.put(progress.id, merged);
      } else {
        await _progressBoxInstance.put(progress.id, progress);
      }
    } catch (e, stackTrace) {
      debugPrint('Failed to cache progress for lesson: ${progress.lessonId} - $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Progress methods
  Future<List<UserProgress>> getProgress() async {
    try {
      return _progressBoxInstance.values.toList();
    } catch (e, stackTrace) {
      debugPrint('Failed to get progress - $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<List<UserProgress>> getUnsyncedProgress() async {
    try {
      final progress = _progressBoxInstance.values.toList();
      return progress.where((p) => !p.isSynced).toList();
    } catch (e, stackTrace) {
      debugPrint('Failed to get unsynced progress - $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<void> markProgressAsSynced(List<String> progressIds) async {
    if (progressIds.isEmpty) return;
    
    try {
      await _progressBoxInstance.putAll(
        Map.fromEntries(
          await Future.wait(
            progressIds.map((id) async {
              final progress = _progressBoxInstance.get(id);
              if (progress != null) {
                return MapEntry(id, progress.copyWith(isSynced: true));
              }
              return MapEntry(id, null);
            }),
          ).then((entries) => entries.where((e) => e.value != null).cast<MapEntry<String, UserProgress>>()),
        ),
      );
      
      debugPrint('✅ Marked ${progressIds.length} progress records as synced');
    } catch (e, stackTrace) {
      debugPrint('Failed to mark progress as synced - $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Clear methods
  Future<void> clearAllData() async {
    await Future.wait([
      _lessonBox.clear(),
      _localLessonBox.clear(),
      _conceptBox.clear(),
      _mcqBox.clear(),
      _progressBoxInstance.clear(),
    ]);
  }
  
  Future<void> clearProgress() => _progressBoxInstance.clear();
  
  // Close all boxes when done
  Future<void> close() async {
    await Future.wait([
      _lessonBox.close(),
      _localLessonBox.close(),
      _conceptBox.close(),
      _mcqBox.close(),
      _progressBoxInstance.close(),
    ]);
  }
  
  /// Merge two progress objects, keeping the most recent data
  UserProgress _mergeProgress(UserProgress existing, UserProgress newProgress) {
    return UserProgress(
      id: existing.id,
      userId: existing.userId,
      lessonId: existing.lessonId,
      contentId: newProgress.contentId ?? existing.contentId,
      studyMode: newProgress.studyMode,
      date: newProgress.date.isAfter(existing.date) ? newProgress.date : existing.date,
      questionsAnswered: existing.questionsAnswered + newProgress.questionsAnswered,
      correctCount: existing.correctCount + newProgress.correctCount,
      lessonCompleted: existing.lessonCompleted || newProgress.lessonCompleted,
      studyTimeSeconds: existing.studyTimeSeconds + newProgress.studyTimeSeconds,
      metadata: _mergeMetadata(existing.metadata, newProgress.metadata),
      isSynced: existing.isSynced && newProgress.isSynced,
    );
  }
  
  /// Merge metadata from two progress objects
  Map<String, dynamic>? _mergeMetadata(
    Map<String, dynamic>? existing,
    Map<String, dynamic>? newData,
  ) {
    if (existing == null) return newData;
    if (newData == null) return existing;
    
    return {...existing, ...newData};
  }
}

class LessonAdapter extends TypeAdapter<Lesson> {
  @override
  final int typeId = 0;

  @override
  Lesson read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Lesson(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String?,
      tags: (fields[3] as List).cast<String>(),
      createdAt: fields[4] as DateTime,
      updatedAt: fields[5] as DateTime,
      userId: fields[6] as String,
      terms: [],
      questions: [],
      concepts: [],
    );
  }

  @override
  void write(BinaryWriter writer, Lesson obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.tags)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.updatedAt)
      ..writeByte(6)
      ..write(obj.userId);
  }
}

class UserProgressAdapter extends TypeAdapter<UserProgress> {
  @override
  final int typeId = 1;

  @override
  UserProgress read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProgress(
      id: fields[0] as String,
      userId: fields[1] as String,
      lessonId: fields[2] as String,
      contentId: fields[3] as String?,
      studyMode: fields[4] != null 
          ? StudyMode.values.firstWhere(
              (e) => e.toString() == 'StudyMode.${fields[4]}',
              orElse: () => StudyMode.lesson,
            )
          : StudyMode.lesson,
      date: fields[5] as DateTime,
      questionsAnswered: fields[6] as int? ?? 0,
      correctCount: fields[7] as int? ?? 0,
      lessonCompleted: fields[8] as bool? ?? false,
      studyTimeSeconds: fields[9] as int? ?? 0,
      isSynced: fields[10] as bool? ?? false,
      metadata: fields[11] as Map<String, dynamic>?,
    );
  }

  @override
  void write(BinaryWriter writer, UserProgress obj) {
    writer
      ..writeByte(12) // Number of fields
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.lessonId)
      ..writeByte(3)
      ..write(obj.contentId)
      ..writeByte(4)
      ..write(obj.studyMode.toString().split('.').last)
      ..writeByte(5)
      ..write(obj.date)
      ..writeByte(6)
      ..write(obj.questionsAnswered)
      ..writeByte(7)
      ..write(obj.correctCount)
      ..writeByte(8)
      ..write(obj.lessonCompleted)
      ..writeByte(9)
      ..write(obj.studyTimeSeconds)
      ..writeByte(10)
      ..write(obj.isSynced)
      ..writeByte(11)
      ..write(obj.metadata);
  }
}

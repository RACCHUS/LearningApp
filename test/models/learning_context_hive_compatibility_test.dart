import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive/src/binary/binary_reader_impl.dart';
import 'package:hive/src/binary/binary_writer_impl.dart';
import 'package:learning_pwa/core/hive_type_ids.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/models/spaced_repetition.dart';

void main() {
  const testPath = 'build/test_hive_compat';

  setUpAll(() {
    final dir = Directory(testPath);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
    Hive.init(testPath);
    if (!Hive.isAdapterRegistered(HiveTypeIds.learningContext)) {
      Hive.registerAdapter(LearningContextAdapter());
    }
  });

  tearDownAll(() {
    final dir = Directory(testPath);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  group('HiveTypeIds allocations', () {
    test('allocates typeIds 12 and 13 for v2 scope cache and snapshot', () {
      expect(HiveTypeIds.resolvedScopeCache, 12);
      expect(HiveTypeIds.contextCurriculumSnapshot, 13);
      expect(HiveTypeIds.freeIds.contains(12), isFalse);
      expect(HiveTypeIds.freeIds.contains(13), isFalse);
    });
  });

  group('LearningContextAdapter backwards compatibility (legacy int ordinals)', () {
    test('deserializes legacy 9-field entries with integer rootType ordinals 0..4', () async {
      final box = await Hive.openBox('legacy_test_${DateTime.now().microsecondsSinceEpoch}');
      final adapter = LearningContextAdapter();

      // Legacy v1 mapping:
      // 0 -> path
      // 1 -> course
      // 2 -> module
      // 3 -> lesson
      // 4 -> studySet
      final legacyOrdinals = {
        0: ContextRootType.path,
        1: ContextRootType.course,
        2: ContextRootType.module,
        3: ContextRootType.lesson,
        4: ContextRootType.studySet,
      };

      for (final entry in legacyOrdinals.entries) {
        final binaryWriter = BinaryWriterImpl(Hive);
        // Legacy v1 write format: 9 fields, field 3 is int
        binaryWriter
          ..writeByte(9)
          ..writeByte(0)..write('ctx-${entry.key}')
          ..writeByte(1)..write('user-1')
          ..writeByte(2)..write('Legacy Context ${entry.key}')
          ..writeByte(3)..write(entry.key) // integer ordinal
          ..writeByte(4)..write('root-${entry.key}')
          ..writeByte(5)..write('📚')
          ..writeByte(6)..write(DateTime(2026, 1, 1))
          ..writeByte(7)..write(false)
          ..writeByte(8)..write(entry.key);

        final bytes = binaryWriter.toBytes();
        final binaryReader = BinaryReaderImpl(bytes, Hive);
        final context = adapter.read(binaryReader);

        expect(context.id, 'ctx-${entry.key}');
        expect(context.rootType, entry.value,
            reason: 'Legacy integer ${entry.key} must decode to ${entry.value}');
        expect(context.rootId, 'root-${entry.key}');
        expect(context.targetVersionId, isNull);
        expect(context.activeFocusType, isNull);
        expect(context.activeFocusId, isNull);
        expect(context.scopeMode, ScopeMode.coreAndPrerequisites);
        expect(context.scopeConfig, isEmpty);
      }

      await box.close();
    });
  });

  group('LearningContextAdapter forward compatibility (v2 string rootType)', () {
    test('writes and reads string rootType and v2 fields', () async {
      final adapter = LearningContextAdapter();

      final v2Context = LearningContext(
        id: 'ctx-target-1',
        userId: 'user-1',
        label: 'Florida AC Class A',
        rootType: ContextRootType.target,
        rootId: 'target-ac-1',
        emoji: '❄️',
        lastActiveAt: DateTime(2026, 9, 25),
        isArchived: false,
        sortOrder: 0,
        targetVersionId: 'version-2026',
        activeFocusType: 'exam_domain',
        activeFocusId: 'domain-refrigeration',
        scopeMode: ScopeMode.coreOnly,
        scopeConfig: const {'includeCalculations': true},
      );

      final writer = BinaryWriterImpl(Hive);
      adapter.write(writer, v2Context);
      final bytes = writer.toBytes();

      final reader = BinaryReaderImpl(bytes, Hive);
      final readBack = adapter.read(reader);

      expect(readBack.id, v2Context.id);
      expect(readBack.rootType, ContextRootType.target);
      expect(readBack.rootId, 'target-ac-1');
      expect(readBack.targetVersionId, 'version-2026');
      expect(readBack.activeFocusType, 'exam_domain');
      expect(readBack.activeFocusId, 'domain-refrigeration');
      expect(readBack.scopeMode, ScopeMode.coreOnly);
      expect(readBack.scopeConfig['includeCalculations'], isTrue);
    });

    test('round-trips concept rootType', () async {
      final adapter = LearningContextAdapter();

      final conceptContext = LearningContext(
        id: 'ctx-concept-1',
        userId: 'user-1',
        label: "Bayes' Theorem",
        rootType: ContextRootType.concept,
        rootId: 'concept-bayes-1',
        lastActiveAt: DateTime(2026, 9, 25),
        scopeMode: ScopeMode.coreAndPrerequisites,
        scopeConfig: const {'selectedLessonId': 'lesson-intro-bayes'},
      );

      final writer = BinaryWriterImpl(Hive);
      adapter.write(writer, conceptContext);
      final bytes = writer.toBytes();

      final reader = BinaryReaderImpl(bytes, Hive);
      final readBack = adapter.read(reader);

      expect(readBack.rootType, ContextRootType.concept);
      expect(readBack.rootId, 'concept-bayes-1');
      expect(readBack.scopeConfig['selectedLessonId'], 'lesson-intro-bayes');
    });

    test('toJson and fromJson handle v2 fields', () {
      final ctx = LearningContext(
        id: 'ctx-json-1',
        userId: 'u1',
        label: 'Computer Science BS',
        rootType: ContextRootType.target,
        rootId: 'target-cs',
        lastActiveAt: DateTime(2026, 9, 25),
        targetVersionId: 'v-2026',
        activeFocusType: 'major_core',
        activeFocusId: 'cs-core',
        scopeMode: ScopeMode.custom,
        scopeConfig: const {'excludeGenEd': true},
      );

      final json = ctx.toJson();
      expect(json['root_type'], 'target');
      expect(json['target_version_id'], 'v-2026');
      expect(json['scope_mode'], 'custom');
      expect(json['scope_config'], {'excludeGenEd': true});

      final fromJson = LearningContext.fromJson(json);
      expect(fromJson.rootType, ContextRootType.target);
      expect(fromJson.targetVersionId, 'v-2026');
      expect(fromJson.activeFocusType, 'major_core');
      expect(fromJson.activeFocusId, 'cs-core');
      expect(fromJson.scopeMode, ScopeMode.custom);
      expect(fromJson.scopeConfig['excludeGenEd'], isTrue);
    });
  });

  group('ReviewableItem standalone flashcard compatibility', () {
    test('supports nullable lessonId for standalone flashcards', () {
      final item = ReviewableItem(
        id: 'rev-flash-1',
        contentId: 'card-1',
        contentType: ReviewableContentType.flashcard,
        lessonId: null, // Standalone
        title: 'Carnot Cycle Efficiency',
        subtitle: 'Thermodynamics definition',
        nextReviewDate: DateTime(2026, 9, 26),
      );

      expect(item.lessonId, isNull);
      expect(item.contentType, ReviewableContentType.flashcard);
      expect(item.contentType.displayName, 'Flashcard');
      expect(item.contentType.icon, '🗂️');

      final json = item.toJson();
      expect(json['lesson_id'], isNull);
      expect(json['content_type'], 'flashcard');

      final fromJson = ReviewableItem.fromJson(json);
      expect(fromJson.lessonId, isNull);
      expect(fromJson.contentType, ReviewableContentType.flashcard);
    });
  });
}

import 'dart:developer';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/lesson_block.dart';
import 'package:learning_pwa/models/assessment_item.dart';
import 'package:learning_pwa/models/assessment_stimulus.dart';
import 'package:learning_pwa/models/knowledge_concept.dart';
import 'package:learning_pwa/models/content_provenance.dart';
import 'package:learning_pwa/models/unified_lesson.dart';
import 'package:learning_pwa/models/lesson_content.dart';
import 'package:learning_pwa/models/term_content.dart';
import 'package:learning_pwa/models/question_content.dart';
import 'package:learning_pwa/models/concept_content.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/concept.dart';

/// Unified Content-Loading Service for Phase D
/// 
/// Coordinates high-efficiency loading of the polymorphic V2 content primitives:
/// - Lesson metadata
/// - Ordered `lesson_blocks` (Markdown, Callout, Code, Table, Formula, Example, Practice Prompt)
/// - Extensible `assessment_items` with linked `assessment_stimuli` and concept junctions
/// - Canonical `knowledge_concepts`
/// - Authoritative `content_source_mappings` (provenance & citations)
/// - Graceful fallback to legacy terms/questions/concepts when blocks are not yet authored
class ContentLoadingService {
  final SupabaseClient _supabase;

  ContentLoadingService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Loads the complete, unified lesson document graph for a given lessonId
  Future<UnifiedLesson> loadUnifiedLesson(String lessonId) async {
    log('📚 ContentLoadingService: Loading unified lesson for ID: $lessonId', name: 'ContentLoadingService');

    // 1. Fetch lesson core row
    final lessonData = await _supabase
        .from('lessons')
        .select('*')
        .eq('id', lessonId)
        .single();

    final lesson = Lesson(
      id: lessonData['id'] as String,
      title: lessonData['title'] as String,
      description: lessonData['description'] as String?,
      tags: lessonData['tags'] != null ? List<String>.from(lessonData['tags']) : <String>[],
      createdAt: DateTime.parse(lessonData['created_at'] as String),
      updatedAt: DateTime.parse(lessonData['updated_at'] as String),
      userId: lessonData['user_id'] as String? ?? '',
      visibility: lessonData['visibility'] as String? ?? 'public',
      terms: <Term>[],
      questions: <Question>[],
      concepts: <Concept>[],
    );

    // 2. Fetch ordered lesson blocks (V2 document model)
    List<LessonBlock> blocks = [];
    try {
      final List<dynamic> blocksRaw = await _supabase
          .from('lesson_blocks')
          .select('*')
          .eq('lesson_id', lessonId)
          .order('sort_order', ascending: true);

      blocks = blocksRaw
          .map((b) => LessonBlock.fromJson((b as Map).cast<String, dynamic>()))
          .toList();
      log('✅ Loaded ${blocks.length} lesson_blocks', name: 'ContentLoadingService');
    } catch (e) {
      log('⚠️ Could not load lesson_blocks: $e', name: 'ContentLoadingService');
    }

    // 3. Fetch polymorphic assessment items (V2 items)
    List<AssessmentItem> assessmentItems = [];
    try {
      final List<dynamic> itemsRaw = await _supabase
          .from('assessment_items')
          .select('*, assessment_stimuli(*), assessment_item_concepts(*)')
          .eq('lesson_id', lessonId)
          .order('created_at', ascending: true);

      assessmentItems = itemsRaw.map((raw) {
        final map = (raw as Map).cast<String, dynamic>();
        AssessmentStimulus? stimulus;
        if (map['assessment_stimuli'] is Map) {
          stimulus = AssessmentStimulus.fromJson(
            (map['assessment_stimuli'] as Map).cast<String, dynamic>(),
          );
        }
        final item = AssessmentItem.fromJson(map);
        return stimulus != null ? item.copyWith(stimulus: stimulus) : item;
      }).toList();
      log('✅ Loaded ${assessmentItems.length} assessment_items', name: 'ContentLoadingService');
    } catch (e) {
      log('⚠️ Could not load assessment_items: $e', name: 'ContentLoadingService');
    }

    // 4. Fetch canonical concepts linked via lesson_concepts
    List<KnowledgeConcept> concepts = [];
    try {
      final List<dynamic> conceptsRaw = await _supabase
          .from('lesson_concepts')
          .select('knowledge_concepts(*)')
          .eq('lesson_id', lessonId);

      for (final row in conceptsRaw) {
        if (row is Map && row['knowledge_concepts'] is Map) {
          concepts.add(KnowledgeConcept.fromJson(
            (row['knowledge_concepts'] as Map).cast<String, dynamic>(),
          ));
        }
      }
      log('✅ Loaded ${concepts.length} linked knowledge_concepts', name: 'ContentLoadingService');
    } catch (e) {
      log('⚠️ Could not load lesson_concepts: $e', name: 'ContentLoadingService');
    }

    // 5. Fetch provenance & blueprint citations
    List<ContentSourceMapping> provenance = [];
    try {
      final List<String> entityIds = [
        lessonId,
        ...blocks.map((b) => b.id),
        ...assessmentItems.map((a) => a.id),
      ];

      final List<dynamic> provenanceRaw = await _supabase
          .from('content_source_mappings')
          .select('*, content_source_releases(*)')
          .inFilter('entity_id', entityIds);

      provenance = provenanceRaw
          .map((p) => ContentSourceMapping.fromJson((p as Map).cast<String, dynamic>()))
          .toList();
      log('✅ Loaded ${provenance.length} provenance citations', name: 'ContentLoadingService');
    } catch (e) {
      log('⚠️ Could not load content_source_mappings: $e', name: 'ContentLoadingService');
    }

    // 6. If no rich blocks exist, load legacy content for fallback synthesis
    List<LessonContent> legacyContent = [];
    if (blocks.isEmpty) {
      log('ℹ️ Lesson has no lesson_blocks; loading legacy terms/questions/concepts', name: 'ContentLoadingService');
      legacyContent = await _loadLegacyContent(lessonId, lesson);
    }

    return UnifiedLesson(
      lesson: lesson,
      blocks: blocks,
      assessmentItems: assessmentItems,
      concepts: concepts,
      provenance: provenance,
      legacyContent: legacyContent,
    );
  }

  Future<List<LessonContent>> _loadLegacyContent(String lessonId, Lesson lesson) async {
    final legacyItems = <LessonContent>[];
    var order = 0;

    // Load terms
    try {
      final List<dynamic> termsRaw = await _supabase
          .from('terms')
          .select('*')
          .eq('lesson_id', lessonId)
          .order('created_at');

      for (final t in termsRaw) {
        if (t is Map<String, dynamic>) {
          legacyItems.add(TermContent(
            id: t['id']?.toString() ?? '',
            lessonId: lessonId,
            order: (t['order_index'] as int?) ?? order++,
            term: t['term']?.toString() ?? '',
            definition: t['definition']?.toString() ?? '',
            example: t['example']?.toString() ?? '',
            createdAt: t['created_at'] != null ? DateTime.tryParse(t['created_at']) ?? DateTime.now() : DateTime.now(),
            updatedAt: t['updated_at'] != null ? DateTime.tryParse(t['updated_at']) ?? DateTime.now() : DateTime.now(),
          ));
        }
      }
    } catch (e) {
      log('Could not load legacy terms: $e', name: 'ContentLoadingService');
    }

    // Load questions
    try {
      final List<dynamic> questionsRaw = await _supabase
          .from('questions')
          .select('*')
          .eq('lesson_id', lessonId)
          .order('created_at');

      for (final q in questionsRaw) {
        if (q is Map<String, dynamic>) {
          legacyItems.add(QuestionContent(
            id: q['id']?.toString() ?? '',
            lessonId: lessonId,
            order: (q['order_index'] as int?) ?? (1000 + order++),
            questionText: q['question_text']?.toString() ?? '',
            options: q['options'] is List
                ? List<String>.from((q['options'] as List).map((o) => o?.toString() ?? ''))
                : <String>[],
            correctAnswer: q['correct_answer'] is int ? q['correct_answer'] as int : 0,
            explanation: q['explanation']?.toString() ?? '',
            createdAt: q['created_at'] != null ? DateTime.tryParse(q['created_at']) ?? DateTime.now() : DateTime.now(),
            updatedAt: q['updated_at'] != null ? DateTime.tryParse(q['updated_at']) ?? DateTime.now() : DateTime.now(),
          ));
        }
      }
    } catch (e) {
      log('Could not load legacy questions: $e', name: 'ContentLoadingService');
    }

    // Load concepts
    try {
      final List<dynamic> conceptsRaw = await _supabase
          .from('concepts')
          .select('*')
          .eq('lesson_id', lessonId)
          .order('created_at');

      for (final c in conceptsRaw) {
        if (c is Map<String, dynamic>) {
          legacyItems.add(ConceptContent(
            id: c['id']?.toString() ?? '',
            lessonId: lessonId,
            order: (c['order_index'] as int?) ?? (500 + order++),
            conceptText: c['concept_text']?.toString() ?? '',
            exampleText: c['example_text']?.toString() ?? '',
            keyPoints: c['key_points'] is List
                ? List<String>.from((c['key_points'] as List).map((k) => k?.toString() ?? ''))
                : null,
            createdAt: c['created_at'] != null ? DateTime.tryParse(c['created_at']) ?? DateTime.now() : DateTime.now(),
            updatedAt: c['updated_at'] != null ? DateTime.tryParse(c['updated_at']) ?? DateTime.now() : DateTime.now(),
          ));
        }
      }
    } catch (e) {
      log('Could not load legacy concepts: $e', name: 'ContentLoadingService');
    }

    legacyItems.sort((a, b) => a.order.compareTo(b.order));
    return legacyItems;
  }
}

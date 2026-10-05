import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/lesson_block.dart';
import 'package:learning_pwa/models/assessment_item.dart';
import 'package:learning_pwa/models/knowledge_concept.dart';
import 'package:learning_pwa/models/content_provenance.dart';
import 'package:learning_pwa/models/lesson_content.dart';
import 'package:learning_pwa/models/term_content.dart';
import 'package:learning_pwa/models/question_content.dart';
import 'package:learning_pwa/models/concept_content.dart';

/// A rich, unified lesson model that encapsulates:
/// 1. The core lesson metadata
/// 2. Ordered Lesson Blocks (Markdown, Callout, Code, Table, Formula, Example, Practice Prompt)
/// 3. Modern Assessment Items (Single-choice, Multi-select/SATA, Ordered Response, Matching)
/// 4. Linked Canonical Concepts
/// 5. Provenance & Citation records (authoritative standard, release, location, SHA-256)
/// 6. Fallback legacy content (terms, questions, concepts) for backward compatibility
class UnifiedLesson {
  final Lesson lesson;
  final List<LessonBlock> blocks;
  final List<AssessmentItem> assessmentItems;
  final List<KnowledgeConcept> concepts;
  final List<ContentSourceMapping> provenance;
  final List<LessonContent> legacyContent;

  const UnifiedLesson({
    required this.lesson,
    this.blocks = const [],
    this.assessmentItems = const [],
    this.concepts = const [],
    this.provenance = const [],
    this.legacyContent = const [],
  });

  bool get hasRichBlocks => blocks.isNotEmpty;
  bool get hasAssessmentItems => assessmentItems.isNotEmpty;
  bool get hasProvenance => provenance.isNotEmpty;

  /// Returns terms from legacy content if present
  List<TermContent> get terms => legacyContent.whereType<TermContent>().toList();

  /// Returns legacy questions if present
  List<QuestionContent> get legacyQuestions => legacyContent.whereType<QuestionContent>().toList();

  /// Returns legacy concepts if present
  List<ConceptContent> get legacyConcepts => legacyContent.whereType<ConceptContent>().toList();

  /// Synthesizes LessonBlocks from legacy content if no rich blocks exist
  List<LessonBlock> get effectiveBlocks {
    if (hasRichBlocks) {
      return blocks;
    }

    final synthesized = <LessonBlock>[];
    var order = 0;

    // 1. Introduction block if description exists
    if (lesson.description != null && lesson.description!.trim().isNotEmpty) {
      synthesized.add(LessonBlock(
        id: 'synth-desc-${lesson.id}',
        lessonId: lesson.id,
        sortOrder: order++,
        blockType: LessonBlockType.markdown,
        content: {'body': lesson.description!},
        createdAt: lesson.createdAt,
        updatedAt: lesson.updatedAt,
      ));
    }

    // 2. Legacy Terms converted to Markdown / Callout blocks
    for (final term in terms) {
      synthesized.add(LessonBlock(
        id: 'synth-term-${term.id}',
        lessonId: lesson.id,
        sortOrder: order++,
        blockType: LessonBlockType.callout,
        content: {
          'title': term.term,
          'body': term.definition,
          'callout_type': 'key_concept',
          if (term.example != null && term.example!.isNotEmpty) 'example': term.example,
        },
        createdAt: term.createdAt,
        updatedAt: term.updatedAt,
      ));
    }

    // 3. Legacy Concepts converted to Example / Callout blocks
    for (final concept in legacyConcepts) {
      synthesized.add(LessonBlock(
        id: 'synth-concept-${concept.id}',
        lessonId: lesson.id,
        sortOrder: order++,
        blockType: LessonBlockType.example,
        content: {
          'title': 'Core Principle',
          'scenario': concept.conceptText,
          if (concept.exampleText != null && concept.exampleText!.isNotEmpty) 'explanation': concept.exampleText,
        },
        createdAt: concept.createdAt,
        updatedAt: concept.updatedAt,
      ));
    }

    // 4. Legacy Questions converted to Practice Prompt blocks
    for (final q in legacyQuestions) {
      final correctOption = (q.options.isNotEmpty && q.correctAnswer >= 0 && q.correctAnswer < q.options.length)
          ? q.options[q.correctAnswer]
          : '';
      synthesized.add(LessonBlock(
        id: 'synth-q-${q.id}',
        lessonId: lesson.id,
        sortOrder: order++,
        blockType: LessonBlockType.practicePrompt,
        content: {
          'prompt': q.questionText,
          'options': q.options,
          'answer': correctOption,
          'explanation': q.explanation,
        },
        createdAt: q.createdAt,
        updatedAt: q.updatedAt,
      ));
    }

    return synthesized;
  }
}

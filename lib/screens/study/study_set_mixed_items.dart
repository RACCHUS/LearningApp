import '../../models/concept.dart';
import '../../models/concept_content.dart';
import '../../models/lesson_content.dart';
import '../../models/question_content.dart';
import '../../models/term_content.dart';
import '../../services/study_set_service.dart';
import 'mixed_mode_screen.dart';

List<ConceptContent> studySetConceptContent(List<Concept> concepts) => concepts
    .map(
      (concept) => ConceptContent(
        id: concept.id,
        lessonId: concept.lessonId,
        order: 0,
        conceptText: concept.conceptText,
        exampleText: concept.exampleText,
        keyPoints: null,
        createdAt: concept.createdAt,
        updatedAt: concept.createdAt,
      ),
    )
    .toList();

/// Includes every loaded item, even when the set contains lessons and
/// separately attached standalone flashcards.
List<MixedStudyItem> studySetMixedItems(
  StudySet set, {
  Iterable<LessonContent> orderedLessonContent = const [],
}) {
  final terms = {for (final term in set.terms) term.id: term};
  final questions = {
    for (final question in set.questions) question.id: question,
  };
  final concepts = {
    for (final concept in studySetConceptContent(set.concepts))
      concept.id: concept,
  };
  final items = <MixedStudyItem>[];
  final seen = <String>{};

  void add(String type, String id, Object data) {
    if (seen.add('$type:$id')) {
      items.add(MixedStudyItem(type: type, data: data));
    }
  }

  for (final content in orderedLessonContent) {
    if (content is TermContent && terms.containsKey(content.id)) {
      add('flashcard', content.id, terms[content.id]!);
    } else if (content is QuestionContent &&
        questions.containsKey(content.id)) {
      add('mcq', content.id, questions[content.id]!);
    } else if (content is ConceptContent && concepts.containsKey(content.id)) {
      add('concept', content.id, content);
    }
  }

  for (final term in set.terms) {
    add('flashcard', term.id, term);
  }
  for (final question in set.questions) {
    add('mcq', question.id, question);
  }
  for (final concept in concepts.values) {
    add('concept', concept.id, concept);
  }
  return items;
}

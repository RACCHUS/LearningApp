import 'package:learning_pwa/models/content_generation/slot_plan.dart';
import 'package:learning_pwa/services/content_generation/la_gen_parser.dart';

/// Converts accepted `la-gen/1.1` slots into flat personal-lesson JSON
/// (dialect P), the contract `LessonImportService` validates (master plan
/// v2.6 §5.6: the `PersonalLessonJsonAdapter`).
///
/// The canonical answer letter has already been resolved by [LaGenParser];
/// here it becomes the zero-based `correct_answer`. Text is copied as
/// written. The importer still re-validates everything before saving.
class LaGenPersonalAdapter {
  const LaGenPersonalAdapter._();

  static Map<String, dynamic> toPersonalLesson({
    required String title,
    String? description,
    List<String> tags = const [],
    required LaGenParseResult result,
    Map<String, int>? orderBySlot,
  }) {
    final terms = <Map<String, dynamic>>[];
    final concepts = <Map<String, dynamic>>[];
    final questions = <Map<String, dynamic>>[];

    // Plan order, not paste order.
    for (final spec in result.plan.slots) {
      final slot = result.accepted[spec.code];
      if (slot == null) continue;
      final f = slot.fields;
      final order = orderBySlot?[spec.code];
      switch (spec.kind) {
        case SlotKind.term:
          terms.add({
            'order': ?order,
            'term': f['term'],
            'definition': f['definition'],
            if (f['example'] != null) 'example': f['example'],
          });
        case SlotKind.explanation:
          final example = f['example'] as String?;
          concepts.add({
            'order': ?order,
            'concept_text': f['title'],
            'example_text': example == null
                ? f['text']
                : '${f['text']}\n\nExample: $example',
          });
        case SlotKind.mcq:
          questions.add({
            'order': ?order,
            'type': 'mcq',
            'question': f['stem'],
            'options': f['options'],
            'correct_answer': slot.correctIndex,
            if (f['why'] != null) 'explanation': f['why'],
          });
      }
    }

    return {
      'title': title,
      if (description != null) 'description': description,
      'tags': tags,
      if (terms.isNotEmpty) 'terms': terms,
      if (concepts.isNotEmpty) 'concepts': concepts,
      if (questions.isNotEmpty) 'questions': questions,
    };
  }
}

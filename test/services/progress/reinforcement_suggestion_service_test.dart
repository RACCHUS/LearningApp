import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/spaced_repetition.dart';
import 'package:learning_pwa/models/user_concept_state.dart';
import 'package:learning_pwa/services/progress/reinforcement_suggestion_service.dart';

import '../../test_helpers/fake_supabase_client.dart';

UserConceptState _state(String id, RetrievalBand band,
        {DateTime? last, ConceptConfidence confidence = ConceptConfidence.low}) =>
    UserConceptState(
      userId: 'u1',
      conceptId: id,
      retrievalBand: band,
      confidence: confidence,
      evidenceCount: 2,
      weightedCorrect: 1,
      weightedTotal: 2,
      lastEvidenceAt: last,
      updatedAt: DateTime.utc(2026, 11, 1),
    );

ReviewableItem _due(String contentId, {String? lessonId}) => ReviewableItem(
      id: 'ri-$contentId',
      contentId: contentId,
      contentType: ReviewableContentType.flashcard,
      lessonId: lessonId,
      title: contentId,
      nextReviewDate: DateTime.utc(2026, 11, 1),
    );

/// UI spec §5.5: weakest concepts, by readable name, each tied to the
/// learner's due review items so "Review" never opens an empty session.
void main() {
  late FakeSupabaseClient client;
  late Map<String, UserConceptState> states;
  late List<ReviewableItem> due;

  ReinforcementSuggestionService service() => ReinforcementSuggestionService(
        client: client,
        conceptStates: (_) async => states,
        dueItems: () async => due,
      );

  setUp(() {
    client = FakeSupabaseClient()
      ..setTableData('knowledge_concepts', [
        {'id': 'c-old', 'name': 'Beta blockers'},
        {'id': 'c-new', 'name': 'ACE inhibitors'},
        {'id': 'c-never', 'name': 'Diuretics'},
        {'id': 'c-ok', 'name': 'Statins'},
        {'id': 'c-noname', 'name': '  '},
      ])
      ..setTableData('flashcard_concepts', [
        {'concept_id': 'c-old', 'flashcard_id': 'fc-1'},
        {'concept_id': 'c-old', 'flashcard_id': 'fc-2'},
        {'concept_id': 'c-ok', 'flashcard_id': 'fc-9'},
      ])
      ..setTableData('question_concepts', [
        {'concept_id': 'c-new', 'question_id': 'q-1'},
      ])
      ..setTableData('term_concepts', <Map<String, dynamic>>[])
      ..setTableData('lesson_concepts', [
        {'concept_id': 'c-never', 'lesson_id': 'lesson-7'},
        {'concept_id': 'c-old', 'lesson_id': 'lesson-1'},
      ]);
    states = {
      'c-old': _state('c-old', RetrievalBand.needsReinforcement, last: DateTime.utc(2026, 9, 1)),
      'c-new': _state('c-new', RetrievalBand.needsReinforcement,
          last: DateTime.utc(2026, 11, 10), confidence: ConceptConfidence.medium),
      'c-never': _state('c-never', RetrievalBand.needsReinforcement),
      'c-ok': _state('c-ok', RetrievalBand.wellRetained, last: DateTime.utc(2026, 8, 1)),
      'c-noname': _state('c-noname', RetrievalBand.needsReinforcement),
    };
    due = [
      _due('fc-1'),
      _due('fc-2', lessonId: 'lesson-1'),
      _due('fc-3', lessonId: 'lesson-1'),
      _due('fc-9'),
      _due('x-7', lessonId: 'lesson-7'),
    ];
  });

  test('only needs-reinforcement concepts, oldest evidence first, by name', () async {
    final list = await service().load('u1');
    expect(list.map((s) => s.name), ['Diuretics', 'Beta blockers', 'ACE inhibitors']);
    expect(list.any((s) => s.conceptId == 'c-ok'), isFalse, reason: 'well retained');
    expect(list.any((s) => s.conceptId == 'c-noname'), isFalse,
        reason: 'never show a concept id in place of a name');
  });

  test('direct item mappings win; lessons only for unmapped concepts', () async {
    final byId = {for (final s in await service().load('u1')) s.conceptId: s};
    expect(byId['c-old']!.dueContentIds, unorderedEquals(['fc-1', 'fc-2']),
        reason: 'fc-3 shares the lesson but is not mapped to the concept');
    expect(byId['c-never']!.dueContentIds, ['x-7'], reason: 'lesson fallback');
    expect(byId['c-new']!.dueContentIds, isEmpty);
    expect(byId['c-new']!.hasDueItems, isFalse);
    expect(byId['c-new']!.confidence, ConceptConfidence.medium);
  });

  test('caps the number of suggestions', () async {
    states = {
      for (var i = 0; i < 20; i++)
        'k$i': _state('k$i', RetrievalBand.needsReinforcement),
    };
    client.setTableData('knowledge_concepts', [
      for (var i = 0; i < 20; i++) {'id': 'k$i', 'name': 'Concept $i'},
    ]);
    expect((await service().load('u1')).length,
        ReinforcementSuggestionService.maxSuggestions);
  });

  test('guests and signed-out learners get nothing, with no requests', () async {
    var asked = false;
    final s = ReinforcementSuggestionService(
      client: client,
      conceptStates: (_) async {
        asked = true;
        return states;
      },
      dueItems: () async => due,
    );
    expect(await s.load(''), isEmpty);
    expect(await s.load('local-user'), isEmpty);
    expect(asked, isFalse);
  });

  test('a failing due-items lookup still lists concepts, with nothing due', () async {
    final s = ReinforcementSuggestionService(
      client: client,
      conceptStates: (_) async => states,
      dueItems: () async => throw Exception('offline'),
    );
    final list = await s.load('u1');
    expect(list, isNotEmpty);
    expect(list.every((x) => !x.hasDueItems), isTrue);
  });
}

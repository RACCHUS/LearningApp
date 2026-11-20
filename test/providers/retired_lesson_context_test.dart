import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/providers/available_lessons_provider.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/retired_lesson_context_provider.dart';

import '../test_fixtures.dart';

const retiredId = '93bfa731-d581-420f-8b14-2ba5ea041a84';
const droppedId = '11111111-1111-4111-8111-111111111111';
const liveId = 'c24de489-4f43-4f52-90e0-2267a0c77fd8';
const unknownId = '22222222-2222-4222-8222-222222222222';

LearningContext lessonContext(String rootId, {String label = 'A lesson'}) =>
    LearningContext(
      id: 'ctx-$rootId',
      userId: 'local-user',
      label: label,
      rootType: ContextRootType.lesson,
      rootId: rootId,
      lastActiveAt: DateTime(2026, 11, 20),
    );

class RecordingNotifier extends LearningContextsNotifier {
  RecordingNotifier(List<LearningContext> contexts)
      : super.stub(LearningContextsState(contexts: contexts));

  final moves = <String, String?>{};

  @override
  Future<void> replaceRetiredLesson(
    LearningContext stale,
    String? replacementLessonId,
  ) async {
    moves[stale.rootId] = replacementLessonId;
  }
}

AvailableLessonsCatalog catalogWith(List<String> ids, {String? error}) =>
    AvailableLessonsCatalog(
      lessons: [for (final id in ids) TestFixtures.createTestLesson(id: id, title: id)],
      remoteError: error,
    );

void main() {
  setUp(resetRetiredLessonChecks);

  group('lessonContextsMissingFromCatalog', () {
    test('only active lesson contexts with server ids missing from the catalog', () {
      final contexts = [
        lessonContext(retiredId),
        lessonContext(liveId),
        lessonContext('asset-lesson-1'), // bundled lessons are not server ids
        LearningContext(
          id: 'ctx-target',
          userId: 'local-user',
          label: 'A target',
          rootType: ContextRootType.target,
          rootId: unknownId,
          lastActiveAt: DateTime(2026, 11, 20),
        ),
      ];
      final missing = lessonContextsMissingFromCatalog(contexts, catalogWith([liveId]));
      expect(missing.map((c) => c.rootId), [retiredId]);
    });

    test('nothing counts as missing while the remote catalog failed', () {
      final missing = lessonContextsMissingFromCatalog(
        [lessonContext(retiredId)],
        catalogWith(const [], error: 'offline'),
      );
      expect(missing, isEmpty);
    });
  });

  test('moves retired contexts, archives dropped ones, ignores the rest', () async {
    final notifier = RecordingNotifier([
      lessonContext(retiredId),
      lessonContext(droppedId),
      lessonContext(unknownId),
      lessonContext(liveId),
    ]);
    final asked = <String>[];
    final container = ProviderContainer(overrides: [
      learningContextsProvider.overrideWith((ref) => notifier),
      availableLessonsCatalogProvider.overrideWith((ref) async => catalogWith([liveId])),
      lessonReplacementLookupProvider.overrideWithValue((id) async {
        asked.add(id);
        return switch (id) {
          retiredId => const LessonReplacement(retired: true, replacementId: liveId),
          droppedId => const LessonReplacement(retired: true),
          _ => const LessonReplacement(retired: false),
        };
      }),
    ]);
    addTearDown(container.dispose);

    await container.read(retiredLessonContextRepairProvider.future);

    expect(asked, unorderedEquals([retiredId, droppedId, unknownId]));
    expect(notifier.moves, {retiredId: liveId, droppedId: null});

    // The same lesson is not asked about again in this session.
    container.invalidate(retiredLessonContextRepairProvider);
    await container.read(retiredLessonContextRepairProvider.future);
    expect(asked, hasLength(3));
  });

  test('a failed lookup leaves the context alone', () async {
    final logged = <String?>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => logged.add(message);
    addTearDown(() => debugPrint = original);
    final notifier = RecordingNotifier([lessonContext(retiredId)]);
    final container = ProviderContainer(overrides: [
      learningContextsProvider.overrideWith((ref) => notifier),
      availableLessonsCatalogProvider.overrideWith((ref) async => catalogWith(const [])),
      lessonReplacementLookupProvider.overrideWithValue((id) async => throw Exception('down')),
    ]);
    addTearDown(container.dispose);

    await container.read(retiredLessonContextRepairProvider.future);
    expect(notifier.moves, isEmpty);
    expect(logged.single, contains('Could not check lesson'));
  });

  test('parses the server answer', () {
    final a = LessonReplacement.fromJson({'retired': true, 'replacement_id': liveId});
    expect(a.retired, isTrue);
    expect(a.replacementId, liveId);
    final b = LessonReplacement.fromJson({'retired': false, 'replacement_id': null});
    expect(b.retired, isFalse);
    expect(b.replacementId, isNull);
  });
}

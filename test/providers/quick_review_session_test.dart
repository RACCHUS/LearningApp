import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/spaced_repetition.dart';
import 'package:learning_pwa/services/spaced_repetition_service.dart';

import '../test_helpers/fake_supabase_client.dart';

/// Fake service returning a fixed set of due items without hitting Supabase.
class _FakeSpacedRepetitionService extends SpacedRepetitionService {
  _FakeSpacedRepetitionService(this._due) : super(supabase: FakeSupabaseClient());

  final List<ReviewableItem> _due;

  @override
  Future<List<ReviewableItem>> getDueItems() async => _due;
}

List<ReviewableItem> _dueItems(int count) => List.generate(
      count,
      (i) => ReviewableItem(
        id: 'i$i',
        contentId: 'c$i',
        contentType: ReviewableContentType.term,
        lessonId: 'l1',
        title: 'Term $i',
        nextReviewDate: DateTime.now().subtract(const Duration(days: 1)),
      ),
    );

ProviderContainer _containerWith(int dueCount) {
  return ProviderContainer(
    overrides: [
      spacedRepetitionServiceProvider.overrideWithValue(
        _FakeSpacedRepetitionService(_dueItems(dueCount)),
      ),
    ],
  );
}

void main() {
  group('Quick Review session limit', () {
    test('caps the session to the requested limit', () async {
      final container = _containerWith(10);
      addTearDown(container.dispose);

      await container
          .read(reviewSessionProvider.notifier)
          .startSession(limit: 3);

      expect(container.read(reviewSessionProvider).items.length, 3);
    });

    test('uses all due items when the limit exceeds the count', () async {
      final container = _containerWith(2);
      addTearDown(container.dispose);

      await container
          .read(reviewSessionProvider.notifier)
          .startSession(limit: 15);

      expect(container.read(reviewSessionProvider).items.length, 2);
    });

    test('a null limit keeps every due item', () async {
      final container = _containerWith(7);
      addTearDown(container.dispose);

      await container.read(reviewSessionProvider.notifier).startSession();

      expect(container.read(reviewSessionProvider).items.length, 7);
    });

    test('completes immediately when nothing is due', () async {
      final container = _containerWith(0);
      addTearDown(container.dispose);

      await container
          .read(reviewSessionProvider.notifier)
          .startSession(limit: 5);

      final state = container.read(reviewSessionProvider);
      expect(state.items, isEmpty);
      expect(state.isComplete, isTrue);
    });
  });
}

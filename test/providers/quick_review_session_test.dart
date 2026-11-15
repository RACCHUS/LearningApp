import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/achievement.dart';
import 'package:learning_pwa/models/spaced_repetition.dart';
import 'package:learning_pwa/providers/xp_achievements_provider.dart';
import 'package:learning_pwa/services/spaced_repetition_service.dart';

import '../test_helpers/fake_supabase_client.dart';

/// Fake service returning a fixed set of due items without hitting Supabase.
class _FakeSpacedRepetitionService extends SpacedRepetitionService {
  _FakeSpacedRepetitionService(this._due) : super(supabase: FakeSupabaseClient());

  final List<ReviewableItem> _due;

  @override
  Future<List<ReviewableItem>> getDueItems() async => _due;

  @override
  Future<ReviewableItem?> processReview(
    ReviewableItem item,
    RecallQuality quality,
  ) async =>
      item;
}

/// Records XP claims instead of calling the server.
class _RecordingXpRecorder extends ActivityXpRecorder {
  _RecordingXpRecorder(super.ref);

  final calls = <(ActivityXpKind, String, String?)>[];

  @override
  Future<ActivityXpResult?> record(
    ActivityXpKind kind,
    String sourceId, {
    String? eventId,
  }) async {
    calls.add((kind, sourceId, eventId));
    return const ActivityXpResult(
      status: 'awarded',
      awardedXp: 25,
      totalXp: 25,
      newAchievements: ['first_review'],
    );
  }
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

  group('Review session XP claim', () {
    late _RecordingXpRecorder recorder;

    ProviderContainer containerWithRecorder(int dueCount) {
      return ProviderContainer(overrides: [
        spacedRepetitionServiceProvider.overrideWithValue(
          _FakeSpacedRepetitionService(_dueItems(dueCount)),
        ),
        activityXpRecorderProvider.overrideWith(
          (ref) => recorder = _RecordingXpRecorder(ref),
        ),
      ]);
    }

    test('claims once, keyed by the session id, when the session finishes',
        () async {
      final container = containerWithRecorder(2);
      addTearDown(container.dispose);
      final notifier = container.read(reviewSessionProvider.notifier);
      container.read(activityXpRecorderProvider);

      await notifier.startSession();
      final sessionId = container.read(reviewSessionProvider).sessionId;
      expect(sessionId, isNotNull);

      await notifier.processCurrentReview(RecallQuality.hesitant);
      expect(recorder.calls, isEmpty, reason: 'not finished yet');

      await notifier.processCurrentReview(RecallQuality.hesitant);
      expect(recorder.calls, [
        (ActivityXpKind.reviewSession, sessionId, sessionId),
      ]);
      final state = container.read(reviewSessionProvider);
      expect(state.xpResult?.awardedXp, 25);
      expect(state.xpResult?.newAchievements, ['first_review']);
    });

    test('an empty session claims nothing', () async {
      final container = containerWithRecorder(0);
      addTearDown(container.dispose);
      container.read(activityXpRecorderProvider);

      await container.read(reviewSessionProvider.notifier).startSession();
      expect(container.read(reviewSessionProvider).isComplete, isTrue);
      expect(recorder.calls, isEmpty);
    });

    test('each started session gets a new id', () async {
      final container = containerWithRecorder(1);
      addTearDown(container.dispose);
      final notifier = container.read(reviewSessionProvider.notifier);

      await notifier.startSession();
      final first = container.read(reviewSessionProvider).sessionId;
      await notifier.startSession();
      expect(container.read(reviewSessionProvider).sessionId,
          isNot(equals(first)));
    });
  });
}

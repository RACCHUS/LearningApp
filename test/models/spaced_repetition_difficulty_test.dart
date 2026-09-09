import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/spaced_repetition.dart';

ReviewableItem _itemAtLevel(int level) => ReviewableItem(
      id: 'i$level',
      contentId: 'c$level',
      contentType: ReviewableContentType.term,
      lessonId: 'l1',
      title: 'Term',
      repetitionLevel: level,
      nextReviewDate: DateTime.now(),
    );

void main() {
  group('ReviewableItem.difficultyCategory', () {
    test('level 0 (or reset) is learning', () {
      expect(_itemAtLevel(0).difficultyCategory, DifficultyCategory.learning);
    });

    test('levels 1-2 are familiar', () {
      expect(_itemAtLevel(1).difficultyCategory, DifficultyCategory.familiar);
      expect(_itemAtLevel(2).difficultyCategory, DifficultyCategory.familiar);
    });

    test('level 3 and above are mastered', () {
      expect(_itemAtLevel(3).difficultyCategory, DifficultyCategory.mastered);
      expect(_itemAtLevel(7).difficultyCategory, DifficultyCategory.mastered);
    });

    test('a lapse (processing a blackout) drops back to learning', () {
      final mastered = _itemAtLevel(4);
      final lapsed = mastered.processReview(RecallQuality.blackout);
      expect(lapsed.difficultyCategory, DifficultyCategory.learning);
    });
  });
}

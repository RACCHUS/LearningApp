import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/audio_lesson/lesson_flow_manager.dart';
import '../../test_fixtures.dart';

void main() {
  group('LessonFlowManager', () {
    late LessonFlowManager manager;

    setUp(() {
      manager = LessonFlowManager();
    });

    group('Initialization', () {
      test('initializeLesson() sets content list and index', () {
        final content = TestFixtures.createMixedContentList();

        manager.initializeLesson(content);

        expect(manager.contentList, hasLength(4));
        expect(manager.currentIndex, 0);
        expect(manager.isActive, isTrue);
      });

      test('initializeLesson() clamps startIndex to valid range', () {
        final content = TestFixtures.createMixedContentList();

        manager.initializeLesson(content, startIndex: 100);

        expect(manager.currentIndex, 3); // Last valid index
      });

      test('initializeLesson() handles negative startIndex', () {
        final content = TestFixtures.createMixedContentList();

        manager.initializeLesson(content, startIndex: -5);

        expect(manager.currentIndex, 0); // Clamped to 0
      });

      test('initializeLesson() rejects empty content', () {
        manager.initializeLesson([]);

        expect(manager.isActive, isFalse);
        expect(manager.contentList, isEmpty);
      });

      test('initializeLesson() sets starting index correctly', () {
        final content = TestFixtures.createMixedContentList();

        manager.initializeLesson(content, startIndex: 2);

        expect(manager.currentIndex, 2);
        expect(manager.isActive, isTrue);
      });
    });

    group('Navigation - Next', () {
      test('moveNext() increments index', () {
        final content = TestFixtures.createMixedContentList();
        manager.initializeLesson(content);

        final result = manager.moveNext();

        expect(result, isTrue);
        expect(manager.currentIndex, 1);
      });

      test('moveNext() returns false at last content', () {
        final content = TestFixtures.createMixedContentList();
        manager.initializeLesson(content, startIndex: 3);

        final result = manager.moveNext();

        expect(result, isFalse);
        expect(manager.currentIndex, 3); // Stays at last
      });

      test('moveNext() can navigate through all content', () {
        final content = TestFixtures.createMixedContentList();
        manager.initializeLesson(content);

        expect(manager.moveNext(), isTrue); // 0 -> 1
        expect(manager.moveNext(), isTrue); // 1 -> 2
        expect(manager.moveNext(), isTrue); // 2 -> 3
        expect(manager.moveNext(), isFalse); // At end
        expect(manager.currentIndex, 3);
      });
    });

    group('Navigation - Previous', () {
      test('movePrevious() decrements index', () {
        final content = TestFixtures.createMixedContentList();
        manager.initializeLesson(content, startIndex: 2);

        final result = manager.movePrevious();

        expect(result, isTrue);
        expect(manager.currentIndex, 1);
      });

      test('movePrevious() returns false at first content', () {
        final content = TestFixtures.createMixedContentList();
        manager.initializeLesson(content, startIndex: 0);

        final result = manager.movePrevious();

        expect(result, isFalse);
        expect(manager.currentIndex, 0); // Stays at first
      });

      test('movePrevious() can navigate backward through content', () {
        final content = TestFixtures.createMixedContentList();
        manager.initializeLesson(content, startIndex: 3);

        expect(manager.movePrevious(), isTrue); // 3 -> 2
        expect(manager.movePrevious(), isTrue); // 2 -> 1
        expect(manager.movePrevious(), isTrue); // 1 -> 0
        expect(manager.movePrevious(), isFalse); // At start
        expect(manager.currentIndex, 0);
      });
    });

    group('Navigation - Jump', () {
      test('jumpToIndex() moves to valid index', () {
        final content = TestFixtures.createMixedContentList();
        manager.initializeLesson(content);

        final result = manager.jumpToIndex(2);

        expect(result, isTrue);
        expect(manager.currentIndex, 2);
      });

      test('jumpToIndex() rejects negative index', () {
        final content = TestFixtures.createMixedContentList();
        manager.initializeLesson(content);

        final result = manager.jumpToIndex(-1);

        expect(result, isFalse);
        expect(manager.currentIndex, 0); // Unchanged
      });

      test('jumpToIndex() rejects index beyond bounds', () {
        final content = TestFixtures.createMixedContentList();
        manager.initializeLesson(content);

        final result = manager.jumpToIndex(10);

        expect(result, isFalse);
        expect(manager.currentIndex, 0); // Unchanged
      });

      test('jumpToIndex() can jump to first index', () {
        final content = TestFixtures.createMixedContentList();
        manager.initializeLesson(content, startIndex: 2);

        final result = manager.jumpToIndex(0);

        expect(result, isTrue);
        expect(manager.currentIndex, 0);
      });

      test('jumpToIndex() can jump to last index', () {
        final content = TestFixtures.createMixedContentList();
        manager.initializeLesson(content);

        final result = manager.jumpToIndex(3);

        expect(result, isTrue);
        expect(manager.currentIndex, 3);
      });
    });

    group('Content getters', () {
      test('currentContent returns correct item', () {
        final content = TestFixtures.createMixedContentList();
        manager.initializeLesson(content);

        final current = manager.currentContent;

        expect(current, isNotNull);
        expect(current?.id, 'tc-1');
      });

      test('currentContent returns null when not initialized', () {
        final current = manager.currentContent;

        expect(current, isNull);
      });

      test('currentContent updates after navigation', () {
        final content = TestFixtures.createMixedContentList();
        manager.initializeLesson(content);

        manager.moveNext();
        final current = manager.currentContent;

        expect(current?.id, 'qc-1');
      });

      test('totalContent returns correct count', () {
        final content = TestFixtures.createMixedContentList();
        manager.initializeLesson(content);

        expect(manager.totalContent, 4);
      });
    });

    group('State flags', () {
      test('isFirstContent is true at start', () {
        final content = TestFixtures.createMixedContentList();
        manager.initializeLesson(content);

        expect(manager.isFirstContent, isTrue);
      });

      test('isFirstContent is false after moving', () {
        final content = TestFixtures.createMixedContentList();
        manager.initializeLesson(content);
        manager.moveNext();

        expect(manager.isFirstContent, isFalse);
      });

      test('isLastContent is true at end', () {
        final content = TestFixtures.createMixedContentList();
        manager.initializeLesson(content, startIndex: 3);

        expect(manager.isLastContent, isTrue);
      });

      test('isLastContent is false before end', () {
        final content = TestFixtures.createMixedContentList();
        manager.initializeLesson(content, startIndex: 2);

        expect(manager.isLastContent, isFalse);
      });
    });

    group('Progress stream', () {
      test('progressStream emits on navigation', () async {
        final content = TestFixtures.createMixedContentList();
        manager.initializeLesson(content);

        final progressValues = <int>[];
        final subscription = manager.progressStream.listen(progressValues.add);

        manager.moveNext();
        manager.moveNext();

        await Future.delayed(const Duration(milliseconds: 50));

        expect(progressValues, contains(1));
        expect(progressValues, contains(2));

        await subscription.cancel();
      });

      test('progressStream emits on jumpToIndex', () async {
        final content = TestFixtures.createMixedContentList();
        manager.initializeLesson(content);

        final progressValues = <int>[];
        final subscription = manager.progressStream.listen(progressValues.add);

        manager.jumpToIndex(3);

        await Future.delayed(const Duration(milliseconds: 50));

        expect(progressValues, contains(3));

        await subscription.cancel();
      });
    });

    group('Edge cases', () {
      test('handles single content item', () {
        final content = [TestFixtures.createTestTermContent()];
        manager.initializeLesson(content);

        expect(manager.totalContent, 1);
        expect(manager.isFirstContent, isTrue);
        expect(manager.isLastContent, isTrue);
        expect(manager.moveNext(), isFalse);
        expect(manager.movePrevious(), isFalse);
      });

      test('navigation fails when not active', () {
        expect(manager.moveNext(), isFalse);
        expect(manager.movePrevious(), isFalse);
        expect(manager.jumpToIndex(0), isFalse);
      });
    });
  });
}

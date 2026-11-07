import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:learning_pwa/models/community/community_bookmark.dart';
import 'package:learning_pwa/services/community/community_bookmark_service.dart';

void main() {
  group('CommunityBookmarkService & CommunityBookmark', () {
    late CommunityBookmarkService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      service = CommunityBookmarkService();
      await service.loadBookmarks();
    });

    test('starts with empty bookmarks list', () {
      expect(service.currentBookmarks, isEmpty);
      expect(service.isBookmarked('ans_1'), isFalse);
    });

    test('adds and retrieves a bookmark', () async {
      final bookmark = CommunityBookmark(
        id: 'bmk_1',
        userId: 'user_1',
        contentType: 'answer',
        contentId: 'ans_1',
        title: 'Safety Eyewear Requirements',
        bodySnippet: 'Eye protection must meet ANSI Z87.1 standards...',
        conceptId: 'concept_safety',
        authorDisplayName: 'Instructor Davis',
        isVerifiedAuthor: true,
        createdAt: DateTime.now(),
      );

      final added = await service.addBookmark(bookmark);
      expect(added, isTrue);
      expect(service.isBookmarked('ans_1'), isTrue);
      expect(service.currentBookmarks.length, 1);
      expect(service.currentBookmarks.first.contentId, 'ans_1');
      expect(service.currentBookmarks.first.authorDisplayName, 'Instructor Davis');
      expect(service.currentBookmarks.first.isVerifiedAuthor, isTrue);
    });

    test('deduplicates bookmarks by contentId and sorts newest first', () async {
      final bm1 = CommunityBookmark(
        id: 'bmk_1',
        userId: 'user_1',
        contentType: 'answer',
        contentId: 'ans_common',
        title: 'First Save',
        bodySnippet: 'Original snippet',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      final bm2 = CommunityBookmark(
        id: 'bmk_2',
        userId: 'user_1',
        contentType: 'answer',
        contentId: 'ans_common',
        title: 'Updated Save',
        bodySnippet: 'Updated snippet',
        createdAt: DateTime.now(),
      );

      await service.addBookmark(bm1);
      await service.addBookmark(bm2);

      expect(service.currentBookmarks.length, 1);
      expect(service.currentBookmarks.first.title, 'Updated Save');
    });

    test('removes a bookmark by contentId', () async {
      final bm = CommunityBookmark(
        id: 'bmk_remove',
        userId: 'user_1',
        contentType: 'answer',
        contentId: 'ans_to_remove',
        title: 'Temporary Bookmark',
        bodySnippet: 'To be removed',
        createdAt: DateTime.now(),
      );

      await service.addBookmark(bm);
      expect(service.isBookmarked('ans_to_remove'), isTrue);

      final removed = await service.removeBookmark('ans_to_remove');
      expect(removed, isTrue);
      expect(service.isBookmarked('ans_to_remove'), isFalse);
      expect(service.currentBookmarks, isEmpty);

      // Removing non-existent content returns false
      final removedAgain = await service.removeBookmark('non_existent');
      expect(removedAgain, isFalse);
    });

    test('filters bookmarks by contentType and conceptId', () async {
      final bmAnswer1 = CommunityBookmark(
        id: 'bmk_ans_1',
        userId: 'user_1',
        contentType: 'answer',
        contentId: 'ans_101',
        title: 'Safety Quiz Answer',
        bodySnippet: 'Answer text',
        conceptId: 'concept_osha',
        createdAt: DateTime.now(),
      );

      final bmQuestion = CommunityBookmark(
        id: 'bmk_q_1',
        userId: 'user_1',
        contentType: 'question',
        contentId: 'q_201',
        title: 'Safety Question',
        bodySnippet: 'Question text',
        conceptId: 'concept_osha',
        createdAt: DateTime.now(),
      );

      final bmAnswer2 = CommunityBookmark(
        id: 'bmk_ans_2',
        userId: 'user_1',
        contentType: 'answer',
        contentId: 'ans_102',
        title: 'Math Answer',
        bodySnippet: 'Math text',
        conceptId: 'concept_math',
        createdAt: DateTime.now(),
      );

      await service.addBookmark(bmAnswer1);
      await service.addBookmark(bmQuestion);
      await service.addBookmark(bmAnswer2);

      expect(service.getBookmarks(contentType: 'answer').length, 2);
      expect(service.getBookmarks(contentType: 'question').length, 1);
      expect(service.getBookmarks(conceptId: 'concept_osha').length, 2);
      expect(service.getBookmarks(contentType: 'answer', conceptId: 'concept_osha').length, 1);
    });

    test('clears all bookmarks', () async {
      final bm = CommunityBookmark(
        id: 'bmk_clear',
        userId: 'user_1',
        contentType: 'answer',
        contentId: 'ans_clear',
        title: 'Clear Me',
        bodySnippet: 'Text',
        createdAt: DateTime.now(),
      );

      await service.addBookmark(bm);
      expect(service.currentBookmarks.length, 1);

      await service.clearBookmarks();
      expect(service.currentBookmarks, isEmpty);
      expect(service.isBookmarked('ans_clear'), isFalse);
    });

    test('round-trips CommunityBookmark through JSON', () {
      final now = DateTime.now();
      final original = CommunityBookmark(
        id: 'bmk_json',
        userId: 'user_42',
        contentType: 'explanation',
        contentId: 'exp_999',
        title: 'Explaining Voltage vs Current',
        bodySnippet: 'Voltage is the electrical pressure...',
        conceptId: 'concept_electrical',
        authorId: 'auth_55',
        authorDisplayName: 'Master Electrician Ray',
        isVerifiedAuthor: true,
        createdAt: now,
      );

      final json = original.toJson();
      final restored = CommunityBookmark.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.userId, original.userId);
      expect(restored.contentType, original.contentType);
      expect(restored.contentId, original.contentId);
      expect(restored.title, original.title);
      expect(restored.bodySnippet, original.bodySnippet);
      expect(restored.conceptId, original.conceptId);
      expect(restored.authorId, original.authorId);
      expect(restored.authorDisplayName, original.authorDisplayName);
      expect(restored.isVerifiedAuthor, original.isVerifiedAuthor);
    });
  });
}


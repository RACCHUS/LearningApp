import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:learning_pwa/models/community/community_bookmark.dart';
import 'package:learning_pwa/services/community/community_bookmark_service.dart';
import 'package:learning_pwa/widgets/community/bookmarked_explanations_sheet.dart';

void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  group('BookmarkedExplanationsSheet', () {
    late CommunityBookmarkService bookmarkService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      bookmarkService = CommunityBookmarkService();
      await bookmarkService.loadBookmarks();
    });

    testWidgets('displays empty state when no bookmarks exist', (tester) async {
      await tester.pumpWidget(buildApp(BookmarkedExplanationsSheet(
        bookmarkService: bookmarkService,
      )));

      expect(find.text('Saved Explanations & Answers'), findsOneWidget);
      expect(find.text('No saved items yet'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    });

    testWidgets('renders list of bookmarks and handles removal and filtering', (tester) async {
      final bm1 = CommunityBookmark(
        id: 'bmk_1',
        userId: 'u1',
        contentType: 'answer',
        contentId: 'ans_101',
        title: 'OSHA Eye Protection Specs',
        bodySnippet: 'Eye protection must meet ANSI Z87.1...',
        authorDisplayName: 'Instructor Lee',
        isVerifiedAuthor: true,
        createdAt: DateTime(2026, 6, 1),
      );

      final bm2 = CommunityBookmark(
        id: 'bmk_2',
        userId: 'u1',
        contentType: 'question',
        contentId: 'q_202',
        title: 'Florida DBPR Renewal Timelines',
        bodySnippet: 'When is cosmetology license renewal required?',
        createdAt: DateTime(2026, 6, 2),
      );

      await bookmarkService.addBookmark(bm1);
      await bookmarkService.addBookmark(bm2);

      await tester.pumpWidget(buildApp(BookmarkedExplanationsSheet(
        bookmarkService: bookmarkService,
      )));

      expect(find.text('OSHA Eye Protection Specs'), findsOneWidget);
      expect(find.text('Instructor Lee'), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsOneWidget); // verified author check
      expect(find.text('Florida DBPR Renewal Timelines'), findsOneWidget);

      // Filter by Answers
      await tester.tap(find.text('Answers'));
      await tester.pumpAndSettle();

      expect(find.text('OSHA Eye Protection Specs'), findsOneWidget);
      expect(find.text('Florida DBPR Renewal Timelines'), findsNothing);

      // Filter by Questions
      await tester.tap(find.text('Questions'));
      await tester.pumpAndSettle();

      expect(find.text('OSHA Eye Protection Specs'), findsNothing);
      expect(find.text('Florida DBPR Renewal Timelines'), findsOneWidget);

      // Reset to All
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      // Remove an individual bookmark
      final removeButtons = find.byTooltip('Remove bookmark');
      expect(removeButtons, findsNWidgets(2));
      await tester.tap(removeButtons.first);
      await tester.pumpAndSettle();

      expect(bookmarkService.currentBookmarks.length, 1);
    });

    testWidgets('clears all bookmarks from confirmation dialog', (tester) async {
      await bookmarkService.addBookmark(CommunityBookmark(
        id: 'bmk_sample',
        userId: 'u1',
        contentType: 'answer',
        contentId: 'ans_sample',
        title: 'Sample Item',
        bodySnippet: 'Sample snippet',
        createdAt: DateTime.now(),
      ));

      await tester.pumpWidget(buildApp(BookmarkedExplanationsSheet(
        bookmarkService: bookmarkService,
      )));

      expect(find.text('Sample Item'), findsOneWidget);

      // Tap Clear All
      await tester.tap(find.text('Clear All'));
      await tester.pumpAndSettle();

      expect(find.text('Clear All Bookmarks?'), findsOneWidget);

      // Confirm in dialog
      final confirmButton = find.widgetWithText(FilledButton, 'Clear All');
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(bookmarkService.currentBookmarks, isEmpty);
      expect(find.text('No saved items yet'), findsOneWidget);
    });
  });
}


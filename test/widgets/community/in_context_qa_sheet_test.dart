import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/community/community_question.dart';
import 'package:learning_pwa/services/community/community_qa_service.dart';
import 'package:learning_pwa/widgets/community/in_context_qa_sheet.dart';

class FakeCommunityQaService extends CommunityQaService {
  final List<CommunityQuestion> fakeSeeds;
  final List<CommunityQuestion> fakeDrafts;

  FakeCommunityQaService({
    required this.fakeSeeds,
    required this.fakeDrafts,
  });

  @override
  Future<List<CommunityQuestion>> fetchSeedFaqs({
    String? conceptId,
    String? targetId,
    String? lessonId,
  }) async {
    return fakeSeeds;
  }

  @override
  Future<List<CommunityQuestion>> fetchMyDrafts() async {
    return fakeDrafts;
  }

  @override
  Future<CommunityQuestion?> createDraftQuestion({
    required String title,
    required String bodyMarkdown,
    String? conceptId,
    String? targetId,
    String? lessonId,
    String? cipCode,
    bool submitForReview = false,
  }) async {
    final q = CommunityQuestion(
      id: 'mock-draft-1',
      authorId: 'user-mock',
      title: title,
      bodyMarkdown: bodyMarkdown,
      status: submitForReview ? 'under_review' : 'draft',
      isSeeded: false,
      conceptId: conceptId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    fakeDrafts.add(q);
    return q;
  }

  @override
  Future<Map<String, dynamic>> toggleVote({
    required String targetType,
    required String targetId,
  }) async {
    return {'voted': true, 'upvote_count': 10};
  }
}

void main() {
  final testSeeds = [
    CommunityQuestion(
      id: 'faq-1',
      authorId: 'admin-1',
      title: 'How does phonics blending work?',
      bodyMarkdown: 'Blending is smoothly combining individual sounds.',
      status: 'published',
      isSeeded: true,
      conceptId: 'literacy.phonics',
      upvoteCount: 9,
      answerCount: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  final testDrafts = [
    CommunityQuestion(
      id: 'draft-1',
      authorId: 'learner-1',
      title: 'My Private Question about Phonics',
      bodyMarkdown: 'Is the word ship a CVC word or a consonant digraph word?',
      status: 'under_review',
      isSeeded: false,
      conceptId: 'literacy.phonics',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  Widget buildTestWidget({CommunityQaService? service}) {
    return MaterialApp(
      home: Scaffold(
        body: InContextQaSheet(
          topicTitle: 'Phonics Blending Pilot',
          conceptId: 'literacy.phonics',
          service: service ?? FakeCommunityQaService(
            fakeSeeds: List.from(testSeeds),
            fakeDrafts: List.from(testDrafts),
          ),
        ),
      ),
    );
  }

  group('ECO-01: InContextQaSheet Widget Tests', () {
    testWidgets('renders topic header, pilot safety banner, and tabs', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Phonics Blending Pilot'), findsOneWidget);
      expect(find.textContaining('Phase 1 Pilot: Open public community posting is disabled'), findsOneWidget);
      expect(find.text('Seed FAQs (1)'), findsOneWidget);
      expect(find.text('Ask a Question'), findsOneWidget);
      expect(find.text('My Drafts (1)'), findsOneWidget);
    });

    testWidgets('displays seed FAQs with upvote counts and official badges', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('How does phonics blending work?'), findsOneWidget);
      expect(find.text('Official FAQ'), findsOneWidget);
      expect(find.text('9 upvotes'), findsOneWidget);
    });

    testWidgets('displays user private drafts in My Drafts tab', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('My Drafts (1)'));
      await tester.pumpAndSettle();

      expect(find.text('My Private Question about Phonics'), findsOneWidget);
      expect(find.text('Under Review'), findsOneWidget);
    });

    testWidgets('validates question title and body fields on submission', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ask a Question'));
      await tester.pumpAndSettle();

      // Tap submit with empty form
      await tester.tap(find.text('Save Private Question'));
      await tester.pumpAndSettle();

      expect(find.text('Title must be at least 5 characters'), findsOneWidget);
      expect(find.text('Details must be at least 10 characters'), findsOneWidget);
    });
  });
}

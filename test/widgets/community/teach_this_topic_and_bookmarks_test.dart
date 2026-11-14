import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:learning_pwa/models/community/community_question.dart';
import 'package:learning_pwa/models/community/community_answer.dart';
import 'package:learning_pwa/models/community/educator_profile.dart';
import 'package:learning_pwa/models/community/educator_verification.dart';
import 'package:learning_pwa/models/community/educator_reputation.dart';
import 'package:learning_pwa/services/community/community_qa_service.dart';
import 'package:learning_pwa/services/community/educator_service.dart';
import 'package:learning_pwa/services/community/educator_reputation_service.dart';
import 'package:learning_pwa/services/community/community_bookmark_service.dart';
import 'package:learning_pwa/widgets/community/in_context_qa_sheet.dart';
import 'package:learning_pwa/widgets/community/bookmarked_explanations_sheet.dart';
import '../../test_helpers/offline_supabase_client.dart';

class _MockQaService extends CommunityQaService {
  final List<CommunityQuestion> seedQuestions;
  final Map<String, List<CommunityAnswer>> answersMap;
  String? createdAnswerQuestionId;
  String? createdAnswerBody;
  bool? createdAnswerSubmitForReview;

  _MockQaService({
    required this.seedQuestions,
    required this.answersMap,
  }) : super(supabase: OfflineSupabaseClient());

  @override
  String? get currentUserId => 'educator_user_42';

  @override
  Future<List<CommunityQuestion>> fetchSeedFaqs({
    String? conceptId,
    String? targetId,
    String? lessonId,
  }) async {
    return seedQuestions;
  }

  @override
  Future<List<CommunityAnswer>> fetchAnswersForQuestion(String questionId) async {
    return answersMap[questionId] ?? [];
  }

  @override
  Future<CommunityAnswer?> createDraftAnswer({
    required String questionId,
    required String bodyMarkdown,
    bool submitForReview = false,
    bool isAiGenerated = false,
    String? aiModelName,
  }) async {
    createdAnswerQuestionId = questionId;
    createdAnswerBody = bodyMarkdown;
    createdAnswerSubmitForReview = submitForReview;
    return CommunityAnswer(
      id: 'ans_new_1',
      questionId: questionId,
      authorId: 'educator_user_42',
      bodyMarkdown: bodyMarkdown,
      status: submitForReview ? 'under_review' : 'draft',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<CommunityQuestion>> fetchMyDrafts() async => [];

  @override
  Future<List<CommunityAnswer>> fetchMyDraftAnswers() async => [];

  @override
  Future<Map<String, String>> fetchQuestionTitles(List<String> questionIds) async => {};
}

class _MockEducatorService extends EducatorService {
  final Map<String, List<EducatorVerification>> verificationsMap;

  _MockEducatorService({this.verificationsMap = const {}});

  @override
  Future<List<EducatorVerification>> fetchPublicVerifications(String educatorId) async {
    return verificationsMap[educatorId] ?? [];
  }

  @override
  Future<EducatorProfile?> fetchProfile(String educatorId) async {
    return EducatorProfile(
      id: educatorId,
      displayName: 'Instructor Davis',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

class _MockReputationService extends EducatorReputationService {
  final Map<String, EducatorReputation> reputationsMap;

  _MockReputationService({this.reputationsMap = const {}});

  @override
  Future<EducatorReputation> fetchReputation(String educatorId) async {
    return reputationsMap[educatorId] ?? EducatorReputation.compute(
      educatorId: educatorId,
      upvotesCount: 0,
      acceptedAnswersCount: 0,
      totalAnswersCount: 0,
    );
  }
}

void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  group('Phase 2 InContextQaSheet: Teach This Topic & Bookmarks', () {
    late _MockQaService qaService;
    late _MockEducatorService educatorService;
    late _MockReputationService reputationService;
    late CommunityBookmarkService bookmarkService;

    final testQuestion = CommunityQuestion(
      id: 'q_safety_1',
      authorId: 'system',
      title: 'What ANSI standard applies to protective eyewear?',
      bodyMarkdown: 'Requirements for eye protection in industrial and educational shops.',
      status: 'published',
      isSeeded: true,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final testAnswer = CommunityAnswer(
      id: 'ans_safety_1',
      questionId: 'q_safety_1',
      authorId: 'edu_verified_1',
      bodyMarkdown: 'Eyewear must conform to ANSI/ISEA Z87.1 for impact resistance.\n\nSource: OSHA 1910.133',
      isAccepted: true,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final testVerification = EducatorVerification(
      id: 'ver_safety_1',
      educatorId: 'edu_verified_1',
      verificationType: 'licensed_credential',
      issuer: 'FL DBPR',
      jurisdiction: 'FL',
      status: 'verified',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final testReputation = EducatorReputation.compute(
      educatorId: 'edu_verified_1',
      upvotesCount: 20,
      acceptedAnswersCount: 8,
      totalAnswersCount: 10,
      verifications: [testVerification],
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      bookmarkService = CommunityBookmarkService();
      await bookmarkService.loadBookmarks();

      qaService = _MockQaService(
        seedQuestions: [testQuestion],
        answersMap: {'q_safety_1': [testAnswer]},
      );

      educatorService = _MockEducatorService(
        verificationsMap: {'edu_verified_1': [testVerification]},
      );

      reputationService = _MockReputationService(
        reputationsMap: {'edu_verified_1': testReputation},
      );
    });

    testWidgets('displays Teach This Topic banner on FAQs tab', (tester) async {
      await tester.pumpWidget(buildApp(InContextQaSheet(
        conceptId: 'concept_safety',
        topicTitle: 'Industrial Safety',
        service: qaService,
        educatorService: educatorService,
        reputationService: reputationService,
        bookmarkService: bookmarkService,
        isAdultConfirmed: true,
      )));

      await tester.pumpAndSettle();

      expect(find.text('Teach This Topic'), findsOneWidget);
      expect(find.textContaining('Subject experts: share explanations'), findsOneWidget);
      expect(find.byKey(const Key('teach_first_topic_button')), findsOneWidget);
    });

    testWidgets('tapping Teach This Topic opens answer contribution dialog', (tester) async {
      await tester.pumpWidget(buildApp(InContextQaSheet(
        conceptId: 'concept_safety',
        topicTitle: 'Industrial Safety',
        service: qaService,
        educatorService: educatorService,
        reputationService: reputationService,
        bookmarkService: bookmarkService,
        isAdultConfirmed: true,
      )));

      await tester.pumpAndSettle();

      // Tap Contribute button in banner
      await tester.tap(find.byKey(const Key('teach_first_topic_button')));
      await tester.pumpAndSettle();

      // Verify Teach This Topic dialog opens
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('What ANSI standard applies to protective eyewear?'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('teach_topic_answer_field')), findsOneWidget);
      expect(find.byKey(const Key('submit_teach_answer_button')), findsOneWidget);

      // Enter answer text
      await tester.enterText(
        find.byKey(const Key('teach_topic_answer_field')),
        'Always ensure safety glasses carry the Z87.1 marking stamped on the temple.',
      );

      // Submit
      await tester.tap(find.byKey(const Key('submit_teach_answer_button')));
      await tester.pumpAndSettle();

      expect(qaService.createdAnswerQuestionId, 'q_safety_1');
      expect(qaService.createdAnswerBody, contains('Z87.1 marking'));
      expect(qaService.createdAnswerSubmitForReview, isTrue);
    });

    testWidgets('bookmarks answer and verifies in bookmark service and sheet', (tester) async {
      await tester.pumpWidget(buildApp(InContextQaSheet(
        conceptId: 'concept_safety',
        topicTitle: 'Industrial Safety',
        service: qaService,
        educatorService: educatorService,
        reputationService: reputationService,
        bookmarkService: bookmarkService,
        isAdultConfirmed: true,
      )));

      await tester.pumpAndSettle();

      // Expand question to view answer
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      // Verify answer and bookmark icon are present
      expect(find.byKey(const Key('bookmark_answer_ans_safety_1')), findsOneWidget);
      expect(bookmarkService.isBookmarked('ans_safety_1'), isFalse);

      // Tap bookmark button
      await tester.tap(find.byKey(const Key('bookmark_answer_ans_safety_1')));
      await tester.pumpAndSettle();

      expect(bookmarkService.isBookmarked('ans_safety_1'), isTrue);
      expect(bookmarkService.currentBookmarks.length, 1);
      expect(bookmarkService.currentBookmarks.first.contentId, 'ans_safety_1');

      // Tap open bookmarks button in header
      await tester.tap(find.byKey(const Key('open_bookmarks_button')));
      await tester.pumpAndSettle();

      expect(find.text('Saved Explanations & Answers'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BookmarkedExplanationsSheet),
          matching: find.text('What ANSI standard applies to protective eyewear?'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders verified educator badge on answer card', (tester) async {
      await tester.pumpWidget(buildApp(InContextQaSheet(
        conceptId: 'concept_safety',
        topicTitle: 'Industrial Safety',
        service: qaService,
        educatorService: educatorService,
        reputationService: reputationService,
        bookmarkService: bookmarkService,
        isAdultConfirmed: true,
      )));

      await tester.pumpAndSettle();

      // Expand question
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      // Verified state license badge and master contributor badge should be rendered
      expect(find.text('Licensed (FL DBPR)'), findsOneWidget);
      expect(find.textContaining('Master Contributor'), findsOneWidget);
    });
  });
}

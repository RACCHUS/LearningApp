import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/community/community_question.dart';
import 'package:learning_pwa/models/community/community_answer.dart';
import 'package:learning_pwa/models/community/community_review_audit.dart';
import 'package:learning_pwa/services/community/community_qa_service.dart';
import 'package:learning_pwa/services/governance/moderation_service.dart';
import 'package:learning_pwa/widgets/community/in_context_qa_sheet.dart';

class FakeCommunityQaService extends CommunityQaService {
  final List<CommunityQuestion> fakeSeeds;
  final List<CommunityQuestion> fakeDrafts;
  final List<CommunityQuestion> fakeReviewQueue;
  final List<CommunityAnswer> fakeReviewAnswers;
  final List<CommunityReviewAudit> fakeAuditLogs;
  final Map<String, List<CommunityAnswer>> fakeAnswers;
  final bool throwUgcDisabledOnPublish;

  String? lastReviewedQuestionId;
  String? lastReviewedAnswerId;
  String? lastReviewAction;
  String? lastAnswerReviewAction;
  String? lastReviewNotes;
  String? lastAcceptedAnswerId;

  FakeCommunityQaService({
    required this.fakeSeeds,
    required this.fakeDrafts,
    this.fakeReviewQueue = const [],
    this.fakeReviewAnswers = const [],
    this.fakeAuditLogs = const [],
    this.fakeAnswers = const {},
    this.throwUgcDisabledOnPublish = false,
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
  Future<List<CommunityQuestion>> fetchUnderReviewQuestions({int limit = 50}) async {
    return fakeReviewQueue;
  }

  @override
  Future<List<CommunityAnswer>> fetchUnderReviewAnswers({int limit = 50}) async {
    return fakeReviewAnswers;
  }

  @override
  Future<List<CommunityReviewAudit>> fetchReviewAuditHistory({
    String? targetType,
    String? targetId,
    int limit = 50,
  }) async {
    return fakeAuditLogs;
  }

  @override
  Future<List<CommunityAnswer>> fetchAnswersForQuestion(String questionId) async {
    return fakeAnswers[questionId] ?? [];
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

  @override
  Future<Map<String, dynamic>> reviewQuestion({
    required String questionId,
    required String action,
    String? notes,
  }) async {
    if (action == 'publish' && throwUgcDisabledOnPublish) {
      throw Exception('Public learner UGC is currently disabled. Learner questions cannot be published before operational launch clearance.');
    }
    lastReviewedQuestionId = questionId;
    lastReviewAction = action;
    lastReviewNotes = notes;
    return {'success': true, 'question_id': questionId, 'action': action};
  }

  @override
  Future<Map<String, dynamic>> reviewAnswer({
    required String answerId,
    required String action,
    String? notes,
  }) async {
    if (action == 'publish' && throwUgcDisabledOnPublish) {
      throw Exception('Public learner UGC is currently disabled. Learner answers cannot be published before operational launch clearance.');
    }
    lastReviewedAnswerId = answerId;
    lastAnswerReviewAction = action;
    lastReviewNotes = notes;
    return {'success': true, 'answer_id': answerId, 'action': action};
  }

  @override
  Future<Map<String, dynamic>> acceptAnswer({
    required String answerId,
  }) async {
    lastAcceptedAnswerId = answerId;
    return {'success': true, 'answer_id': answerId, 'is_accepted': true};
  }
}

class FakeModerationService extends ModerationService {
  final bool isMod;
  FakeModerationService({this.isMod = false});

  @override
  Future<bool> isModerator() async => isMod;

  @override
  Future<bool> isAdmin() async => isMod;
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

  final testReviewQueue = [
    CommunityQuestion(
      id: 'review-1',
      authorId: 'learner-2',
      title: 'Question for Moderator Review',
      bodyMarkdown: 'Can you explain the rules for Florida cosmetologist license renewal?',
      status: 'under_review',
      isSeeded: false,
      conceptId: 'licensure.cosmetology.ce',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  final offlineDemoSeed = [
    CommunityQuestion(
      id: 'seed-faq-001',
      authorId: 'offline-demo',
      title: 'What is the CVC pattern in phonics?',
      bodyMarkdown: 'A CVC word is composed of a Consonant, a Short Vowel, and a Consonant.',
      status: 'published',
      isSeeded: true,
      conceptId: 'literacy.cvc.basics',
      viewCount: 0,
      upvoteCount: 0,
      answerCount: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  Widget buildTestWidget({
    CommunityQaService? service,
    ModerationService? moderationService,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 700,
          child: InContextQaSheet(
            topicTitle: 'Phonics Blending Pilot',
            conceptId: 'literacy.phonics',
            service: service ?? FakeCommunityQaService(
              fakeSeeds: List.from(testSeeds),
              fakeDrafts: List.from(testDrafts),
            ),
            moderationService: moderationService ?? FakeModerationService(isMod: false),
          ),
        ),
      ),
    );
  }

  group('ECO-01: InContextQaSheet Learner Tests', () {
    testWidgets('renders topic header, pilot safety banner, and tabs for learner', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Phonics Blending Pilot'), findsOneWidget);
      expect(find.textContaining('Phase 1 Pilot: Open public community posting is disabled'), findsOneWidget);
      expect(find.text('FAQs (1)'), findsOneWidget);
      expect(find.text('Ask a Question'), findsOneWidget);
      expect(find.text('My Drafts (1)'), findsOneWidget);
      expect(find.textContaining('Review Queue'), findsNothing);
    });

    testWidgets('displays seed FAQs with upvote counts and official badges for reviewed records', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('How does phonics blending work?'), findsOneWidget);
      expect(find.text('Official FAQ'), findsOneWidget);
      expect(find.text('9 upvotes'), findsOneWidget);
    });

    testWidgets('displays offline demonstration preview badge without fabricated engagement', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        service: FakeCommunityQaService(
          fakeSeeds: offlineDemoSeed,
          fakeDrafts: [],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Offline Demo Preview'), findsOneWidget);
      expect(find.text('Official FAQ'), findsNothing);
      expect(find.textContaining('upvotes'), findsNothing);
    });

    testWidgets('disables voting on offline demo records', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        service: FakeCommunityQaService(
          fakeSeeds: offlineDemoSeed,
          fakeDrafts: [],
        ),
      ));
      await tester.pumpAndSettle();

      final voteButtonFinder = find.widgetWithIcon(IconButton, Icons.thumb_up_alt_outlined);
      expect(voteButtonFinder, findsOneWidget);
      final iconButton = tester.widget<IconButton>(voteButtonFinder);
      expect(iconButton.onPressed, isNull);
      expect(iconButton.tooltip, 'Voting disabled for offline preview');
    });

    testWidgets('displays Offline Example Answer label for offline demo answers', (tester) async {
      final offlineDemoAnswers = {
        'seed-faq-001': [
          CommunityAnswer(
            id: 'ans-demo-1',
            questionId: 'seed-faq-001',
            authorId: 'offline-demo',
            bodyMarkdown: 'A CVC word is composed of a Consonant, Short Vowel, and Consonant.',
            isAccepted: true,
            status: 'published',
            upvoteCount: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
      };

      await tester.pumpWidget(buildTestWidget(
        service: FakeCommunityQaService(
          fakeSeeds: offlineDemoSeed,
          fakeDrafts: [],
          fakeAnswers: offlineDemoAnswers,
        ),
      ));
      await tester.pumpAndSettle();

      // Expand the question
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      expect(find.text('Offline Example Answer:'), findsOneWidget);
      expect(find.text('Official Answer:'), findsNothing);
      expect(find.text('Accepted Answer:'), findsNothing);
    });

    testWidgets('distinguishes accepted answers from unreviewed community answers', (tester) async {
      final fakeAnswers = {
        'faq-1': [
          CommunityAnswer(
            id: 'ans-1',
            questionId: 'faq-1',
            authorId: 'admin-1',
            bodyMarkdown: 'Blending requires sound continuity.',
            isAccepted: true,
            status: 'published',
            upvoteCount: 5,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
      };

      await tester.pumpWidget(buildTestWidget(
        service: FakeCommunityQaService(
          fakeSeeds: List.from(testSeeds),
          fakeDrafts: [],
          fakeAnswers: fakeAnswers,
        ),
      ));
      await tester.pumpAndSettle();

      // Expand the question
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      expect(find.text('Accepted Answer:'), findsOneWidget);
      expect(find.text('Blending requires sound continuity.'), findsOneWidget);
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

  group('ECO-02: Moderator Review Queue & Answer Acceptance Tests', () {
    testWidgets('displays Review Queue tab when user has moderator privileges', (tester) async {
      final fakeService = FakeCommunityQaService(
        fakeSeeds: List.from(testSeeds),
        fakeDrafts: List.from(testDrafts),
        fakeReviewQueue: List.from(testReviewQueue),
      );

      await tester.pumpWidget(buildTestWidget(
        service: fakeService,
        moderationService: FakeModerationService(isMod: true),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Review Queue (1)'), findsOneWidget);

      // Tap Review Queue tab
      await tester.tap(find.text('Review Queue (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Question for Moderator Review'), findsOneWidget);
      expect(find.text('Publish'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
    });

    testWidgets('moderator tapping Publish calls reviewQuestion with publish', (tester) async {
      final fakeService = FakeCommunityQaService(
        fakeSeeds: List.from(testSeeds),
        fakeDrafts: List.from(testDrafts),
        fakeReviewQueue: List.from(testReviewQueue),
      );

      await tester.pumpWidget(buildTestWidget(
        service: fakeService,
        moderationService: FakeModerationService(isMod: true),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Review Queue (1)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Publish'));
      await tester.pumpAndSettle();

      expect(fakeService.lastReviewedQuestionId, 'review-1');
      expect(fakeService.lastReviewAction, 'publish');
    });

    testWidgets('moderator tapping Reject calls reviewQuestion with reject', (tester) async {
      final fakeService = FakeCommunityQaService(
        fakeSeeds: List.from(testSeeds),
        fakeDrafts: List.from(testDrafts),
        fakeReviewQueue: List.from(testReviewQueue),
      );

      await tester.pumpWidget(buildTestWidget(
        service: fakeService,
        moderationService: FakeModerationService(isMod: true),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Review Queue (1)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm Rejection'));
      await tester.pumpAndSettle();

      expect(fakeService.lastReviewedQuestionId, 'review-1');
      expect(fakeService.lastReviewAction, 'reject');
    });

    testWidgets('moderator can reject with editorial feedback notes which are saved to audit', (tester) async {
      final fakeService = FakeCommunityQaService(
        fakeSeeds: List.from(testSeeds),
        fakeDrafts: List.from(testDrafts),
        fakeReviewQueue: List.from(testReviewQueue),
      );

      await tester.pumpWidget(buildTestWidget(
        service: fakeService,
        moderationService: FakeModerationService(isMod: true),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Review Queue (1)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Please provide Florida statute citations.');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm Rejection'));
      await tester.pumpAndSettle();

      expect(fakeService.lastReviewedQuestionId, 'review-1');
      expect(fakeService.lastReviewAction, 'reject');
      expect(fakeService.lastReviewNotes, 'Please provide Florida statute citations.');
    });

    testWidgets('moderator can switch to Answers tab in review queue to review learner submitted answers', (tester) async {
      final reviewAnswer = CommunityAnswer(
        id: 'rev-ans-1',
        questionId: 'faq-1',
        authorId: 'learner-3',
        bodyMarkdown: 'You should pause slightly between consonants.',
        isAccepted: false,
        isAiGenerated: true,
        aiModelName: 'gemini-1.5-flash',
        status: 'under_review',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final fakeService = FakeCommunityQaService(
        fakeSeeds: List.from(testSeeds),
        fakeDrafts: [],
        fakeReviewQueue: [],
        fakeReviewAnswers: [reviewAnswer],
      );

      await tester.pumpWidget(buildTestWidget(
        service: fakeService,
        moderationService: FakeModerationService(isMod: true),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Review Queue (1)'));
      await tester.pumpAndSettle();

      // Switch to Answers sub-segment
      await tester.tap(find.text('Answers (1)'));
      await tester.pumpAndSettle();

      expect(find.text('You should pause slightly between consonants.'), findsOneWidget);
      expect(find.text('AI: gemini-1.5-flash'), findsOneWidget);

      // Tap Publish
      await tester.tap(find.text('Publish'));
      await tester.pumpAndSettle();

      expect(fakeService.lastReviewedAnswerId, 'rev-ans-1');
      expect(fakeService.lastAnswerReviewAction, 'publish');
    });

    testWidgets('moderator can view Audit Log segment displaying historical governance actions', (tester) async {
      final auditLog = CommunityReviewAudit(
        id: 'aud-1',
        targetType: 'question',
        targetId: 'review-1',
        action: 'reject',
        previousStatus: 'under_review',
        newStatus: 'archived',
        notes: 'Needs clearer regulatory context.',
        createdAt: DateTime.now(),
      );

      final fakeService = FakeCommunityQaService(
        fakeSeeds: List.from(testSeeds),
        fakeDrafts: [],
        fakeReviewQueue: [],
        fakeAuditLogs: [auditLog],
      );

      await tester.pumpWidget(buildTestWidget(
        service: fakeService,
        moderationService: FakeModerationService(isMod: true),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Review Queue (0)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Audit Log (1)'));
      await tester.pumpAndSettle();

      expect(find.text('REJECT'), findsOneWidget);
      expect(find.text('Status change: under_review -> archived'), findsOneWidget);
      expect(find.text('Needs clearer regulatory context.'), findsOneWidget);
    });

    testWidgets('handles UGC Launch Gate restriction gracefully when publish fails', (tester) async {
      final fakeService = FakeCommunityQaService(
        fakeSeeds: List.from(testSeeds),
        fakeDrafts: [],
        fakeReviewQueue: List.from(testReviewQueue),
        throwUgcDisabledOnPublish: true,
      );

      await tester.pumpWidget(buildTestWidget(
        service: fakeService,
        moderationService: FakeModerationService(isMod: true),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Review Queue (1)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Publish'));
      await tester.pumpAndSettle();

      // Displays Phase 1 Launch Gate Active dialog
      expect(find.text('Phase 1 Launch Gate Active'), findsOneWidget);
      expect(find.textContaining('Public learner UGC is disabled during Phase 1 private testing'), findsOneWidget);

      // Tap Understood
      await tester.tap(find.text('Understood'));
      await tester.pumpAndSettle();

      expect(find.text('Phase 1 Launch Gate Active'), findsNothing);
    });

    testWidgets('renders source attribution in a dedicated provenance box for verified FAQs', (tester) async {
      final answersWithAttribution = {
        'faq-1': [
          CommunityAnswer(
            id: 'ans-attr-1',
            questionId: 'faq-1',
            authorId: 'admin-1',
            bodyMarkdown: 'Phonics instruction requires sequential decoding. Source: National Reading Panel. Verified October 2026. Note: Platform-curated educational reference.',
            isAccepted: true,
            isSeeded: true,
            status: 'published',
            upvoteCount: 5,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
      };

      await tester.pumpWidget(buildTestWidget(
        service: FakeCommunityQaService(
          fakeSeeds: List.from(testSeeds),
          fakeDrafts: [],
          fakeAnswers: answersWithAttribution,
        ),
      ));
      await tester.pumpAndSettle();

      // Expand question
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      expect(find.text('Phonics instruction requires sequential decoding.'), findsOneWidget);
      expect(find.text('Platform Curated'), findsWidgets);
      expect(find.textContaining('Source: National Reading Panel. Verified October 2026.'), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
    });

    testWidgets('moderator can mark unaccepted answers as accepted', (tester) async {
      final fakeAnswers = {
        'faq-1': [
          CommunityAnswer(
            id: 'ans-unaccepted-1',
            questionId: 'faq-1',
            authorId: 'admin-1',
            bodyMarkdown: 'A newly proposed correct explanation.',
            isAccepted: false,
            status: 'published',
            upvoteCount: 2,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
      };

      final fakeService = FakeCommunityQaService(
        fakeSeeds: List.from(testSeeds),
        fakeDrafts: [],
        fakeAnswers: fakeAnswers,
      );

      await tester.pumpWidget(buildTestWidget(
        service: fakeService,
        moderationService: FakeModerationService(isMod: true),
      ));
      await tester.pumpAndSettle();

      // Expand question
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      expect(find.text('Accept'), findsOneWidget);

      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();

      expect(fakeService.lastAcceptedAnswerId, 'ans-unaccepted-1');
    });
  });
}

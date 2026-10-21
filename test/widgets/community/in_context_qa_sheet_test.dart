import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState, AuthChangeEvent, Session, User;
import 'package:learning_pwa/models/community/community_question.dart';
import 'package:learning_pwa/models/community/community_answer.dart';
import 'package:learning_pwa/models/community/community_review_audit.dart';
import 'package:learning_pwa/models/community/author_review_feedback.dart';
import 'package:learning_pwa/services/community/community_qa_service.dart';
import 'package:learning_pwa/services/governance/moderation_service.dart';
import 'package:learning_pwa/widgets/community/in_context_qa_sheet.dart';

class FakeCommunityQaService extends CommunityQaService {
  final List<CommunityQuestion> fakeSeeds;
  final List<CommunityQuestion> fakeDrafts;
  final List<CommunityAnswer> fakeDraftAnswers;
  final List<AuthorReviewFeedback> fakeFeedback;
  final Map<String, String> fakeQuestionTitles;
  final List<CommunityQuestion> fakeReviewQueue;
  final List<CommunityAnswer> fakeReviewAnswers;
  final List<CommunityReviewAudit> fakeAuditLogs;
  final Map<String, List<CommunityAnswer>> fakeAnswers;
  final Map<String, String> fakeAnswerParentMap;
  final bool throwUgcDisabledOnPublish;
  String? fakeUserId;
  final StreamController<AuthState>? authStreamController;

  String? lastReviewedQuestionId;
  String? lastReviewedAnswerId;
  String? lastReviewAction;
  String? lastAnswerReviewAction;
  String? lastReviewNotes;
  String? lastReviewInternalNotes;
  String? lastAcceptedAnswerId;

  Completer<CommunityQuestion?>? draftQuestionCompleter;
  Completer<List<CommunityAnswer>>? answersCompleter;
  Completer<CommunityAnswer?>? draftAnswerCompleter;
  String? lastCreatedAnswerQuestionId;
  String? lastCreatedAnswerBody;
  bool? lastCreatedAnswerSubmitForReview;

  FakeCommunityQaService({
    required this.fakeSeeds,
    required this.fakeDrafts,
    this.fakeDraftAnswers = const [],
    this.fakeFeedback = const [],
    this.fakeQuestionTitles = const {},
    this.fakeReviewQueue = const [],
    this.fakeReviewAnswers = const [],
    this.fakeAuditLogs = const [],
    this.fakeAnswers = const {},
    this.fakeAnswerParentMap = const {},
    this.fakeUserId,
    this.authStreamController,
    this.throwUgcDisabledOnPublish = false,
  });

  @override
  String? get currentUserId => fakeUserId;

  @override
  Stream<AuthState>? get authStateChanges => authStreamController?.stream;

  @override
  Future<Map<String, String>> fetchAnswerParentQuestionMap(List<String> answerIds) async {
    return fakeAnswerParentMap;
  }

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
    return List<CommunityQuestion>.from(fakeDrafts);
  }

  @override
  Future<List<CommunityAnswer>> fetchMyDraftAnswers() async {
    return List<CommunityAnswer>.from(fakeDraftAnswers);
  }

  @override
  Future<List<AuthorReviewFeedback>> fetchMySubmissionFeedback({String? targetId}) async {
    if (targetId != null) {
      return fakeFeedback.where((f) => f.targetId == targetId).toList();
    }
    return fakeFeedback;
  }

  @override
  Future<Map<String, String>> fetchQuestionTitles(List<String> questionIds) async {
    final result = <String, String>{};
    for (final q in [...fakeSeeds, ...fakeDrafts, ...fakeReviewQueue]) {
      if (questionIds.contains(q.id)) {
        result[q.id] = q.title;
      }
    }
    result.addAll(fakeQuestionTitles);
    return result;
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
    if (answersCompleter != null) {
      return answersCompleter!.future;
    }
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
    if (draftQuestionCompleter != null) {
      return draftQuestionCompleter!.future;
    }
    final q = CommunityQuestion(
      id: 'mock-draft-${fakeDrafts.length + 1}',
      authorId: fakeUserId ?? 'user-mock',
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
  Future<CommunityAnswer?> createDraftAnswer({
    required String questionId,
    required String bodyMarkdown,
    bool submitForReview = false,
    bool isAiGenerated = false,
    String? aiModelName,
  }) async {
    lastCreatedAnswerQuestionId = questionId;
    lastCreatedAnswerBody = bodyMarkdown;
    lastCreatedAnswerSubmitForReview = submitForReview;
    if (draftAnswerCompleter != null) {
      return draftAnswerCompleter!.future;
    }
    final a = CommunityAnswer(
      id: 'mock-ans-${fakeDraftAnswers.length + 1}',
      questionId: questionId,
      authorId: fakeUserId ?? 'user-mock',
      bodyMarkdown: bodyMarkdown,
      status: submitForReview ? 'under_review' : 'draft',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    fakeDraftAnswers.add(a);
    return a;
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
    String? internalNotes,
  }) async {
    if (action == 'publish' && throwUgcDisabledOnPublish) {
      throw Exception('Public learner UGC is currently disabled. Learner questions cannot be published before operational launch clearance.');
    }
    lastReviewedQuestionId = questionId;
    lastReviewAction = action;
    lastReviewNotes = notes;
    lastReviewInternalNotes = internalNotes;
    return {'success': true, 'question_id': questionId, 'action': action};
  }

  @override
  Future<Map<String, dynamic>> reviewAnswer({
    required String answerId,
    required String action,
    String? notes,
    String? internalNotes,
  }) async {
    if (action == 'publish' && throwUgcDisabledOnPublish) {
      throw Exception('Public learner UGC is currently disabled. Learner answers cannot be published before operational launch clearance.');
    }
    lastReviewedAnswerId = answerId;
    lastAnswerReviewAction = action;
    lastReviewNotes = notes;
    lastReviewInternalNotes = internalNotes;
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

      await tester.enterText(find.byType(TextField).first, 'Please provide Florida statute citations.');
      await tester.enterText(find.byType(TextField).at(1), 'Internal policy review needed.');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm Rejection'));
      await tester.pumpAndSettle();

      expect(fakeService.lastReviewedQuestionId, 'review-1');
      expect(fakeService.lastReviewAction, 'reject');
      expect(fakeService.lastReviewNotes, 'Please provide Florida statute citations.');
      expect(fakeService.lastReviewInternalNotes, 'Internal policy review needed.');
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
        reviewerId: 'mod-uuid-1234',
        action: 'reject',
        previousStatus: 'under_review',
        newStatus: 'archived',
        notes: 'Needs clearer regulatory context.',
        internalNotes: 'Internal check approved.',
        createdAt: DateTime.now(),
      );

      final fakeService = FakeCommunityQaService(
        fakeSeeds: List.from(testSeeds),
        fakeDrafts: [],
        fakeReviewQueue: [],
        fakeAuditLogs: [auditLog],
        fakeQuestionTitles: {'review-1': 'Question for Moderator Review'},
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
      expect(find.text('Author Feedback: Needs clearer regulatory context.'), findsOneWidget);
      expect(find.text('Internal Notes: Internal check approved.'), findsOneWidget);
      expect(find.textContaining('Reviewer: Moderator'), findsOneWidget);
      expect(find.text('Target: Question for Moderator Review'), findsOneWidget);
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

    testWidgets('Platform Curated badge is NOT displayed for non-seeded answers on seeded questions or for offline demos', (tester) async {
      final unseededAnswerOnSeededQuestion = {
        'faq-1': [
          CommunityAnswer(
            id: 'ans-unseeded-1',
            questionId: 'faq-1',
            authorId: 'learner-10',
            bodyMarkdown: 'Learner contribution that is not platform-curated.',
            isAccepted: false,
            isSeeded: false,
            status: 'published',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
      };

      final fakeService = FakeCommunityQaService(
        fakeSeeds: List.from(testSeeds),
        fakeDrafts: [],
        fakeAnswers: unseededAnswerOnSeededQuestion,
      );

      await tester.pumpWidget(buildTestWidget(service: fakeService));
      await tester.pumpAndSettle();

      // Expand question
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      expect(find.text('Learner contribution that is not platform-curated.'), findsOneWidget);
      expect(find.text('Platform Curated'), findsNothing);
    });

    testWidgets('author can view rejection decision feedback in My Drafts tab without exposing internal audit', (tester) async {
      final rejectedQuestion = CommunityQuestion(
        id: 'draft-rejected-1',
        authorId: 'user-mock',
        title: 'How do Florida barbers renew their licenses?',
        bodyMarkdown: 'My notes on barber license renewal requirements.',
        status: 'archived',
        isSeeded: false,
        createdAt: DateTime(2026, 10, 15),
        updatedAt: DateTime(2026, 10, 16),
      );

      final authorFeedback = AuthorReviewFeedback(
        id: 'fb-1',
        targetType: 'question',
        targetId: 'draft-rejected-1',
        action: 'reject',
        newStatus: 'archived',
        feedback: 'Please clarify that Florida barber licenses are renewed biennially by July 31st of even years.',
        createdAt: DateTime(2026, 10, 16),
      );

      final fakeService = FakeCommunityQaService(
        fakeSeeds: List.from(testSeeds),
        fakeDrafts: [rejectedQuestion],
        fakeFeedback: [authorFeedback],
      );

      await tester.pumpWidget(buildTestWidget(service: fakeService));
      await tester.pumpAndSettle();

      expect(find.text('My Drafts (1)'), findsOneWidget);

      await tester.tap(find.text('My Drafts (1)'));
      await tester.pumpAndSettle();

      expect(find.text('How do Florida barbers renew their licenses?'), findsOneWidget);
      expect(find.text('Rejected — Create a Revised Submission'), findsOneWidget);
      expect(find.text('Revise and Resubmit as New Question'), findsOneWidget);
      expect(find.text('Educator Review Feedback:'), findsOneWidget);
      expect(find.text('Please clarify that Florida barber licenses are renewed biennially by July 31st of even years.'), findsOneWidget);
    });

    testWidgets('account switch immediately clears private drafts/feedback and prevents cross-account leak', (tester) async {
      final userADraft = CommunityQuestion(
        id: 'draft-user-a',
        authorId: 'user-a',
        title: 'User A Secret Question',
        bodyMarkdown: 'Private notes belonging to User A.',
        status: 'archived',
        isSeeded: false,
        createdAt: DateTime(2026, 10, 15),
        updatedAt: DateTime(2026, 10, 16),
      );
      final userAFeedback = AuthorReviewFeedback(
        id: 'fb-user-a',
        targetType: 'question',
        targetId: 'draft-user-a',
        action: 'reject',
        newStatus: 'archived',
        feedback: 'Private feedback intended only for User A.',
        createdAt: DateTime(2026, 10, 16),
      );

      final authStreamController = StreamController<AuthState>.broadcast();
      final fakeService = FakeCommunityQaService(
        fakeSeeds: List.from(testSeeds),
        fakeDrafts: [userADraft],
        fakeFeedback: [userAFeedback],
        fakeUserId: 'user-a',
        authStreamController: authStreamController,
      );

      await tester.pumpWidget(buildTestWidget(service: fakeService));
      await tester.pumpAndSettle();

      // Go to My Drafts tab
      await tester.tap(find.text('My Drafts (1)'));
      await tester.pumpAndSettle();

      expect(find.text('User A Secret Question'), findsOneWidget);
      expect(find.text('Private feedback intended only for User A.'), findsOneWidget);

      // Now switch account to user-b
      fakeService.fakeUserId = 'user-b';
      fakeService.fakeDrafts.clear();
      fakeService.fakeFeedback.clear();

      final sessionB = Session(
        accessToken: 'mock-token-b',
        tokenType: 'bearer',
        user: User(
          id: 'user-b',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      authStreamController.add(AuthState(AuthChangeEvent.signedIn, sessionB));
      await tester.pumpAndSettle();

      // User A's private data must be completely cleared and absent
      expect(find.text('User A Secret Question'), findsNothing);
      expect(find.text('Private feedback intended only for User A.'), findsNothing);
      expect(find.text('You have not authored any private questions or answers yet.'), findsOneWidget);

      await authStreamController.close();
    });

    testWidgets('account switch clears unsubmitted draft form inputs, status message, and caches', (tester) async {
      final authStreamController = StreamController<AuthState>.broadcast();

      final fakeService = FakeCommunityQaService(
        fakeSeeds: List.from(testSeeds),
        fakeDrafts: [],
        fakeUserId: 'user-a',
        authStreamController: authStreamController,
      );

      await tester.pumpWidget(buildTestWidget(service: fakeService));
      await tester.pumpAndSettle();

      // User A goes to the "Ask a Question" tab and types sensitive unsubmitted text
      await tester.tap(find.text('Ask a Question'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Question Title'),
        'User A Highly Confidential Title',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Details / Context'),
        'User A Private Draft Body Content that should never leak to another user',
      );
      await tester.pumpAndSettle();

      expect(find.text('User A Highly Confidential Title'), findsOneWidget);
      expect(find.text('User A Private Draft Body Content that should never leak to another user'), findsOneWidget);

      // Now switch account to user-b
      fakeService.fakeUserId = 'user-b';
      final sessionB = Session(
        accessToken: 'mock-token-b',
        tokenType: 'bearer',
        user: User(
          id: 'user-b',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      authStreamController.add(AuthState(AuthChangeEvent.signedIn, sessionB));
      await tester.pumpAndSettle();

      // Form controllers MUST be completely cleared for User B
      expect(find.text('User A Highly Confidential Title'), findsNothing);
      expect(find.text('User A Private Draft Body Content that should never leak to another user'), findsNothing);

      await authStreamController.close();
    });

    testWidgets('delayed in-flight question submission under Account A is discarded across account switch', (tester) async {
      final authStreamController = StreamController<AuthState>.broadcast();
      final draftCompleter = Completer<CommunityQuestion?>();

      final fakeService = FakeCommunityQaService(
        fakeSeeds: List.from(testSeeds),
        fakeDrafts: [],
        fakeUserId: 'user-a',
        authStreamController: authStreamController,
      );
      fakeService.draftQuestionCompleter = draftCompleter;

      await tester.pumpWidget(buildTestWidget(service: fakeService));
      await tester.pumpAndSettle();

      // Navigate to Ask a Question tab and submit
      await tester.tap(find.text('Ask a Question'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Question Title'),
        'User A In-Flight Question Title',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Details / Context'),
        'User A In-Flight Body with sufficient length for valid form submission.',
      );
      await tester.pumpAndSettle();

      // Click submit (request goes in-flight)
      await tester.tap(find.text('Save Private Question'));
      await tester.pump();

      // While request is in-flight, account switches to user-b
      fakeService.fakeUserId = 'user-b';
      final sessionB = Session(
        accessToken: 'mock-token-b',
        tokenType: 'bearer',
        user: User(
          id: 'user-b',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      authStreamController.add(AuthState(AuthChangeEvent.signedIn, sessionB));
      await tester.pumpAndSettle();

      // Now complete the delayed in-flight question for User A
      draftCompleter.complete(CommunityQuestion(
        id: 'q-user-a-delayed',
        authorId: 'user-a',
        title: 'User A In-Flight Question Title',
        bodyMarkdown: 'User A In-Flight Body with sufficient length for valid form submission.',
        status: 'under_review',
        isSeeded: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await tester.pumpAndSettle();

      // Switch to My Drafts tab
      await tester.tap(find.text('My Drafts (0)'));
      await tester.pumpAndSettle();

      // User A's question must NOT have been inserted into User B's drafts
      expect(find.text('User A In-Flight Question Title'), findsNothing);
      expect(find.text('You have not authored any private questions or answers yet.'), findsOneWidget);

      await authStreamController.close();
    });

    testWidgets('delayed in-flight answer loading under Account A is discarded across account switch', (tester) async {
      final authStreamController = StreamController<AuthState>.broadcast();
      final answersCompleter = Completer<List<CommunityAnswer>>();

      final fakeService = FakeCommunityQaService(
        fakeSeeds: List.from(testSeeds),
        fakeDrafts: [],
        fakeUserId: 'user-a',
        authStreamController: authStreamController,
      );
      fakeService.answersCompleter = answersCompleter;

      await tester.pumpWidget(buildTestWidget(service: fakeService));
      await tester.pumpAndSettle();

      // User A taps to expand first FAQ, starting in-flight _loadAnswers
      await tester.tap(find.text(testSeeds.first.title));
      await tester.pump();

      // Account switches to user-b
      fakeService.fakeUserId = 'user-b';
      final sessionB = Session(
        accessToken: 'mock-token-b',
        tokenType: 'bearer',
        user: User(
          id: 'user-b',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      authStreamController.add(AuthState(AuthChangeEvent.signedIn, sessionB));
      await tester.pumpAndSettle();

      // Complete the delayed answers
      answersCompleter.complete([
        CommunityAnswer(
          id: 'delayed-ans-1',
          questionId: testSeeds.first.id,
          authorId: 'user-a',
          bodyMarkdown: 'Secret User A answer payload',
          status: 'published',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        )
      ]);
      await tester.pumpAndSettle();

      // Verify the delayed payload is not rendered or leaked
      expect(find.text('Secret User A answer payload'), findsNothing);

      await authStreamController.close();
    });

    testWidgets('displays latest review feedback decision when multiple review records exist for the same target', (tester) async {
      final rejectedQuestion = CommunityQuestion(
        id: 'draft-multi-review-1',
        authorId: 'user-mock',
        title: 'Multi-review decision question',
        bodyMarkdown: 'Draft body under repeated review cycles.',
        status: 'archived',
        isSeeded: false,
        createdAt: DateTime(2026, 10, 10),
        updatedAt: DateTime(2026, 10, 21),
      );

      final oldestFeedback = AuthorReviewFeedback(
        id: 'fb-old',
        targetType: 'question',
        targetId: 'draft-multi-review-1',
        action: 'reject',
        newStatus: 'archived',
        feedback: 'Old rejection feedback: Incomplete citation.',
        createdAt: DateTime(2026, 10, 15),
      );
      final latestFeedback = AuthorReviewFeedback(
        id: 'fb-new',
        targetType: 'question',
        targetId: 'draft-multi-review-1',
        action: 'reject',
        newStatus: 'archived',
        feedback: 'Latest rejection feedback: Please add Florida Rule 61G5 citation.',
        createdAt: DateTime(2026, 10, 21),
      );

      // CommunityQaService returns feedback ordered created_at DESC (latest first)
      final fakeService = FakeCommunityQaService(
        fakeSeeds: List.from(testSeeds),
        fakeDrafts: [rejectedQuestion],
        fakeFeedback: [latestFeedback, oldestFeedback],
      );

      await tester.pumpWidget(buildTestWidget(service: fakeService));
      await tester.pumpAndSettle();

      await tester.tap(find.text('My Drafts (1)'));
      await tester.pumpAndSettle();

      // Must display the newest feedback and not the older overwritten one
      expect(find.text('Latest rejection feedback: Please add Florida Rule 61G5 citation.'), findsOneWidget);
      expect(find.text('Old rejection feedback: Incomplete citation.'), findsNothing);
    });

    testWidgets('tapping "Revise and Resubmit as New Question" populates question form and navigates to Ask tab', (tester) async {
      final rejectedQuestion = CommunityQuestion(
        id: 'draft-to-revise-1',
        authorId: 'user-mock',
        title: 'How to obtain Florida Certified General Contractor license?',
        bodyMarkdown: 'Original draft text lacking experience details.',
        status: 'archived',
        isSeeded: false,
        createdAt: DateTime(2026, 10, 18),
        updatedAt: DateTime(2026, 10, 19),
      );

      final feedback = AuthorReviewFeedback(
        id: 'fb-rev-1',
        targetType: 'question',
        targetId: 'draft-to-revise-1',
        action: 'reject',
        newStatus: 'archived',
        feedback: 'Please explain 4-year experience requirement under Section 489.111, F.S.',
        createdAt: DateTime(2026, 10, 19),
      );

      final fakeService = FakeCommunityQaService(
        fakeSeeds: List.from(testSeeds),
        fakeDrafts: [rejectedQuestion],
        fakeFeedback: [feedback],
      );

      await tester.pumpWidget(buildTestWidget(service: fakeService));
      await tester.pumpAndSettle();

      await tester.tap(find.text('My Drafts (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Revise and Resubmit as New Question'), findsOneWidget);

      await tester.tap(find.text('Revise and Resubmit as New Question'));
      await tester.pumpAndSettle();

      // Verify form is pre-filled and Ask tab is selected with status message
      expect(find.text('How to obtain Florida Certified General Contractor license?'), findsOneWidget);
      expect(find.text('Original draft text lacking experience details.'), findsOneWidget);
      expect(find.text('Revise your question based on educator feedback and save as a new draft.'), findsOneWidget);
    });

    testWidgets('tapping "Revise and Resubmit Answer" opens answer composer dialog and submits revised under-review answer', (tester) async {
      final rejectedAnswer = CommunityAnswer(
        id: 'ans-to-revise-1',
        questionId: 'faq-1',
        authorId: 'user-mock',
        bodyMarkdown: 'Original answer text needing correction.',
        status: 'archived',
        createdAt: DateTime(2026, 10, 18),
        updatedAt: DateTime(2026, 10, 19),
      );

      final feedback = AuthorReviewFeedback(
        id: 'fb-ans-1',
        targetType: 'answer',
        targetId: 'ans-to-revise-1',
        action: 'reject',
        newStatus: 'archived',
        feedback: 'Answer needs to cite phonological awareness research.',
        createdAt: DateTime(2026, 10, 19),
      );

      final fakeService = FakeCommunityQaService(
        fakeSeeds: List.from(testSeeds),
        fakeDrafts: [],
        fakeDraftAnswers: [rejectedAnswer],
        fakeFeedback: [feedback],
        fakeQuestionTitles: {'faq-1': 'How does phonics blending work?'},
        fakeUserId: 'user-mock',
      );

      await tester.pumpWidget(buildTestWidget(service: fakeService));
      await tester.pumpAndSettle();

      await tester.tap(find.text('My Drafts (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Revise and Resubmit Answer'), findsOneWidget);

      await tester.tap(find.text('Revise and Resubmit Answer'));
      await tester.pumpAndSettle();

      // Verify dialog is displayed with context, educator feedback, and prefilled text
      expect(find.text('Revise and Resubmit Answer'), findsNWidgets(2)); // Button & Dialog Title
      expect(find.text('How does phonics blending work?'), findsOneWidget);
      expect(find.text('Answer needs to cite phonological awareness research.'), findsNWidgets(2)); // List & Dialog
      expect(find.text('Original answer text needing correction.'), findsNWidgets(2));

      // Edit answer text
      final answerField = find.widgetWithText(TextFormField, 'Your Revised Answer (Markdown supported)');
      expect(answerField, findsOneWidget);
      await tester.enterText(
        answerField,
        'Revised answer text citing Linnea Ehri (2005) phonological phase research with valid length.',
      );
      await tester.pumpAndSettle();

      // Submit revised answer
      await tester.tap(find.text('Submit Revised Answer'));
      await tester.pumpAndSettle();

      // Verify createDraftAnswer was called correctly on the service
      expect(fakeService.lastCreatedAnswerQuestionId, 'faq-1');
      expect(fakeService.lastCreatedAnswerBody, contains('Linnea Ehri (2005)'));
      expect(fakeService.lastCreatedAnswerSubmitForReview, isTrue);

      // Dialog should be dismissed and status message shown
      expect(find.text('Revised answer submitted for educator review.'), findsOneWidget);

      // Both the original archived answer and the new under-review answer must exist
      expect(find.text('My Drafts (2)'), findsOneWidget);
      expect(find.text('Rejected — Create a Revised Submission'), findsOneWidget);
      expect(find.text('Under Review'), findsOneWidget);
    });

    testWidgets('answer revision composer prevents cross-account submission if auth changes while dialog is open', (tester) async {
      final authStreamController = StreamController<AuthState>.broadcast();
      final rejectedAnswer = CommunityAnswer(
        id: 'ans-user-a-1',
        questionId: 'faq-1',
        authorId: 'user-a',
        bodyMarkdown: 'User A draft answer needing revision.',
        status: 'archived',
        createdAt: DateTime(2026, 10, 18),
        updatedAt: DateTime(2026, 10, 19),
      );

      final fakeService = FakeCommunityQaService(
        fakeSeeds: List.from(testSeeds),
        fakeDrafts: [],
        fakeDraftAnswers: [rejectedAnswer],
        fakeQuestionTitles: {'faq-1': 'How does phonics blending work?'},
        fakeUserId: 'user-a',
        authStreamController: authStreamController,
      );

      await tester.pumpWidget(buildTestWidget(service: fakeService));
      await tester.pumpAndSettle();

      await tester.tap(find.text('My Drafts (1)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Revise and Resubmit Answer'));
      await tester.pumpAndSettle();

      expect(find.text('Revise and Resubmit Answer'), findsNWidgets(2));

      // While dialog is open, switch account to user-b
      fakeService.fakeUserId = 'user-b';
      fakeService.fakeDraftAnswers.clear();
      final sessionB = Session(
        accessToken: 'mock-token-b',
        tokenType: 'bearer',
        user: User(
          id: 'user-b',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      authStreamController.add(AuthState(AuthChangeEvent.signedIn, sessionB));
      await tester.pumpAndSettle();

      // Attempt to submit in the open dialog
      await tester.tap(find.text('Submit Revised Answer'));
      await tester.pumpAndSettle();

      // Submission must not have been created for user-b
      expect(fakeService.lastCreatedAnswerQuestionId, isNull);
      expect(fakeService.fakeDraftAnswers, isEmpty);

      await authStreamController.close();
    });

    testWidgets('audit log resolves and displays parent question title for answer events', (tester) async {
      final audit = CommunityReviewAudit(
        id: 'audit-ans-1',
        targetType: 'answer',
        targetId: 'ans-audit-1',
        reviewerId: 'reviewer-1',
        action: 'reject',
        previousStatus: 'under_review',
        newStatus: 'archived',
        notes: 'Needs statutory citation.',
        createdAt: DateTime(2026, 10, 21),
      );

      final fakeService = FakeCommunityQaService(
        fakeSeeds: List.from(testSeeds),
        fakeDrafts: [],
        fakeAuditLogs: [audit],
        fakeAnswerParentMap: {'ans-audit-1': 'q-parent-1'},
        fakeQuestionTitles: {'q-parent-1': 'Florida Electrical Contractor Scope'},
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

      expect(find.text('Target: Answer to: "Florida Electrical Contractor Scope"'), findsOneWidget);
    });

    testWidgets('moderator review queue displays full context (author, date, parent question title)', (tester) async {
      final reviewQuestion = CommunityQuestion(
        id: 'rev-q-10',
        authorId: 'learner-author-1234',
        title: 'Safety Data Sheet format inquiry',
        bodyMarkdown: 'Are 16 sections required under OSHA GHS?',
        status: 'under_review',
        isSeeded: false,
        conceptId: 'workplace.safety.hazcom',
        createdAt: DateTime(2026, 10, 20),
        updatedAt: DateTime(2026, 10, 20),
      );

      final reviewAnswer = CommunityAnswer(
        id: 'rev-ans-20',
        questionId: 'rev-q-10',
        authorId: 'learner-ans-5678',
        bodyMarkdown: 'Yes, OSHA aligns with GHS Annex 4 requiring all 16 sections.',
        status: 'under_review',
        createdAt: DateTime(2026, 10, 21),
        updatedAt: DateTime(2026, 10, 21),
      );

      final fakeService = FakeCommunityQaService(
        fakeSeeds: List.from(testSeeds),
        fakeDrafts: [],
        fakeReviewQueue: [reviewQuestion],
        fakeReviewAnswers: [reviewAnswer],
        fakeQuestionTitles: {'rev-q-10': 'Safety Data Sheet format inquiry'},
      );

      await tester.pumpWidget(buildTestWidget(
        service: fakeService,
        moderationService: FakeModerationService(isMod: true),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Review Queue (2)'));
      await tester.pumpAndSettle();

      // Check Question Context: Author & Submitted date
      expect(find.text('Author: Learner (learner-)'), findsOneWidget);
      expect(find.text('Submitted: 10/20/2026'), findsOneWidget);
      expect(find.text('Safety Data Sheet format inquiry'), findsOneWidget);

      // Switch to Answers sub-segment
      await tester.tap(find.text('Answers (1)'));
      await tester.pumpAndSettle();

      // Check Answer Context: Parent Question Title, Author & Submitted date
      expect(find.text('Question: "Safety Data Sheet format inquiry"'), findsOneWidget);
      expect(find.text('Author: Learner (learner-)'), findsOneWidget);
      expect(find.text('Submitted: 10/21/2026'), findsOneWidget);
      expect(find.text('Yes, OSHA aligns with GHS Annex 4 requiring all 16 sections.'), findsOneWidget);
    });
  });
}

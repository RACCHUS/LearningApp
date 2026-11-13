import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/lesson_contribution_provider.dart';
import 'package:learning_pwa/screens/community/community_lessons_screen.dart';
import 'package:learning_pwa/screens/governance/contribution_review_screen.dart';
import 'package:learning_pwa/services/community/lesson_contribution_service.dart';
import 'package:learning_pwa/widgets/community/share_with_community_action.dart';

class FakeService extends LessonContributionService {
  final proposed = <String>[];
  final decisions = <String>[];
  List<RefreshProposal> open = [];
  List<RefreshProposal> accepted = [];

  @override
  Future<void> proposeRefresh({
    required String contributionId,
    required RefreshKind kind,
    required String description,
    String? itemRef,
    String? sourceUrl,
  }) async => proposed.add(
    '$contributionId|${kind.wire}|$itemRef|$description|${sourceUrl ?? ''}',
  );

  @override
  Future<List<RefreshProposal>> openProposals() async => open;

  @override
  Future<void> decideProposal(
    String id, {
    required bool accept,
    String? note,
  }) async => decisions.add('$id|$accept|${note ?? ''}');

  @override
  Future<List<RefreshProposal>> acceptedProposalsFor(String lessonId) async =>
      accepted;

  @override
  Future<ContributionStatus?> latestFor(String lessonId) async => null;

  @override
  Future<List<ContributionQueueItem>> fetchQueue(List<String> statuses) async =>
      const [];
}

ContributionQueueItem item() => ContributionQueueItem.fromJson({
  'id': 'c1',
  'version': 1,
  'status': 'published',
  'license': 'CC-BY-4.0',
  'ai_assisted': false,
  'created_at': '2026-11-13T10:00:00Z',
  'snapshot': {
    'title': 'Percent',
    'terms': [],
    'concepts': [],
    'questions': [
      {
        'question_text': 'Q',
        'options': ['a', 'b'],
        'correct_answer': 0,
      },
    ],
  },
});

const proposal = RefreshProposal(
  id: 'r1',
  contributionId: 'c1',
  kind: RefreshKind.sourceChanged,
  description: 'The textbook has a new edition.',
  status: 'open',
  itemRef: 'questions[0]',
  sourceUrl: 'https://openstax.org/x',
);

void main() {
  late FakeService service;
  setUp(() => service = FakeService());

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    bool refresh = true,
  }) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lessonContributionServiceProvider.overrideWithValue(service),
          publicContributionEnabledProvider.overrideWithValue(true),
          refreshProposalsEnabledProvider.overrideWithValue(refresh),
          contributionRolesProvider.overrideWith(
            (ref) async =>
                const ContributionRoles(moderator: true, admin: false),
          ),
        ],
        child: MaterialApp(home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('reader: no suggest button when the switch is OFF', (
    tester,
  ) async {
    await pump(
      tester,
      CommunityLessonReaderScreen(item: item()),
      refresh: false,
    );
    expect(find.byKey(const Key('community_suggest_update')), findsNothing);
    expect(find.byKey(const Key('community_report')), findsOneWidget);
  });

  testWidgets('reader: suggestion sends kind, part, text and link', (
    tester,
  ) async {
    await pump(tester, CommunityLessonReaderScreen(item: item()));
    await tester.tap(find.byKey(const Key('community_suggest_update')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('refresh_part')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Question 1').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('refresh_description')),
      'Option b is now correct.',
    );
    await tester.enterText(
      find.byKey(const Key('refresh_url')),
      'https://example.org/new',
    );
    await tester.tap(find.byKey(const Key('refresh_send')));
    await tester.pumpAndSettle();
    expect(service.proposed, [
      'c1|correction|questions[0]|Option b is now correct.|https://example.org/new',
    ]);
    expect(find.textContaining('A moderator will review'), findsOneWidget);
  });

  testWidgets('moderator: Suggestions tab accepts with a note', (tester) async {
    service.open = [proposal];
    await pump(tester, const ContributionReviewScreen());
    await tester.tap(find.text('Suggestions'));
    await tester.pumpAndSettle();
    expect(find.text('The textbook has a new edition.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('accept_r1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('review_reason_field')), 'ok');
    await tester.tap(find.byKey(const Key('review_reason_confirm')));
    await tester.pumpAndSettle();
    expect(service.decisions, ['r1|true|ok']);
    expect(find.textContaining('nothing was changed'), findsOneWidget);
  });

  testWidgets('moderator: decisions paused when the switch is OFF', (
    tester,
  ) async {
    service.open = [proposal];
    await pump(tester, const ContributionReviewScreen(), refresh: false);
    await tester.tap(find.text('Suggestions'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('accept_r1'))).onPressed,
      isNull,
    );
  });

  testWidgets('contributor sees accepted suggestions in the share dialog', (
    tester,
  ) async {
    service.accepted = [
      const RefreshProposal(
        id: 'r1',
        contributionId: 'c1',
        kind: RefreshKind.outdated,
        description: 'Figures are from 2019.',
        status: 'accepted',
      ),
    ];
    await pump(
      tester,
      const Scaffold(
        body: ShareWithCommunityDialog(lessonId: 'l1', lessonTitle: 'Mine'),
      ),
    );
    expect(find.byKey(const Key('accepted_suggestions')), findsOneWidget);
    expect(
      find.text('• It is out of date: Figures are from 2019.'),
      findsOneWidget,
    );
  });
}

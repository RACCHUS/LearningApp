import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/lesson_contribution_provider.dart';
import 'package:learning_pwa/screens/community/wanted_board_screen.dart';
import 'package:learning_pwa/services/community/wanted_board_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeWanted extends WantedBoardService {
  FakeWanted({
    this.needs = const [],
    this.mine = const [],
    this.proposed = const [],
  });

  List<WantedNeed> needs;
  final List<LinkableContribution> mine;
  final List<WantedNeed> proposed;
  final calls = <String>[];
  WantedBoardException? failNext;

  Future<void> _maybeFail() async {
    final f = failNext;
    failNext = null;
    if (f != null) throw f;
  }

  @override
  Future<List<WantedNeed>> board() async => needs;

  List<WantedPriority> priorities = const [];

  @override
  Future<List<WantedPriority>> priorityList() async => priorities;

  @override
  Future<void> propose(String title, {String? details, String? tag}) async {
    await _maybeFail();
    calls.add('propose:$title:$details:$tag');
  }

  @override
  Future<void> vote(String needId, bool vote) async {
    calls.add('vote:$needId:$vote');
    needs = [
      for (final n in needs)
        n.id == needId
            ? WantedNeed(id: n.id, title: n.title, hasVoted: vote)
            : n,
    ];
  }

  @override
  Future<List<LinkableContribution>> myContributions() async => mine;

  @override
  Future<void> link(String needId, String contributionId) async {
    calls.add('link:$needId:$contributionId');
  }

  @override
  Future<List<WantedNeed>> needsWithStatus(String status) async =>
      status == 'proposed' ? proposed : needs;

  @override
  Future<List<NeedLink>> linksFor(List<String> needIds) async => [
    for (final c in mine)
      if (needIds.isNotEmpty) NeedLink(needIds.first, c),
  ];

  @override
  Future<void> review(
    String needId, {
    required bool approve,
    String? note,
  }) async {
    calls.add('review:$needId:$approve:$note');
  }

  @override
  Future<void> setStatus(
    String needId,
    String status, {
    String? contributionId,
    String? note,
  }) async {
    calls.add('status:$needId:$status:$contributionId');
  }
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    FakeWanted service, {
    bool enabled = true,
    bool moderator = false,
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wantedBoardEnabledProvider.overrideWithValue(enabled),
          wantedBoardServiceProvider.overrideWithValue(service),
          contributionRolesProvider.overrideWith(
            (ref) async =>
                ContributionRoles(moderator: moderator, admin: false),
          ),
        ],
        child: const MaterialApp(home: WantedBoardScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  const vlookup = WantedNeed(
    id: 'n1',
    title: 'How VLOOKUP works',
    details: 'Step by step',
    subjectTag: 'excel',
  );

  testWidgets('switch OFF: a message only', (tester) async {
    await pump(tester, FakeWanted(needs: [vlookup]), enabled: false);
    expect(find.byKey(const Key('wanted_off')), findsOneWidget);
    expect(find.byKey(const Key('wanted_need_n1')), findsNothing);
  });

  testWidgets('the board shows suppressed and real demand', (tester) async {
    await pump(
      tester,
      FakeWanted(
        needs: [
          vlookup,
          const WantedNeed(id: 'n2', title: 'Pivot tables', votes: 4),
        ],
      ),
    );
    expect(find.text('Wanted by a few learners · excel'), findsOneWidget);
    expect(find.text('Wanted by 4 learners'), findsOneWidget);
    expect(find.byKey(const Key('wanted_review_tab')), findsNothing);
  });

  testWidgets('vote, ask and link my lesson', (tester) async {
    final s = FakeWanted(
      needs: [vlookup],
      mine: [
        const LinkableContribution('c1', 'My VLOOKUP lesson', 'submitted'),
      ],
    );
    await pump(tester, s);

    await tester.tap(find.byKey(const Key('wanted_vote_n1')));
    await tester.pumpAndSettle();
    expect(s.calls, contains('vote:n1:true'));

    await tester.tap(find.byKey(const Key('wanted_propose')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('wanted_title')),
      'Pivot tables',
    );
    await tester.enterText(find.byKey(const Key('wanted_tag')), 'Excel');
    await tester.tap(find.byKey(const Key('wanted_send')));
    await tester.pumpAndSettle();
    expect(s.calls, contains('propose:Pivot tables:null:excel'));
    expect(find.textContaining('A moderator will check it'), findsOneWidget);

    await tester.tap(find.byKey(const Key('wanted_fulfil_n1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wanted_link_c1')));
    await tester.pumpAndSettle();
    expect(s.calls, contains('link:n1:c1'));
  });

  testWidgets('server refusals are explained', (tester) async {
    final s = FakeWanted(needs: [vlookup])
      ..failNext = WantedBoardException('invalid_need');
    await pump(tester, s);
    await tester.tap(find.byKey(const Key('wanted_propose')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('wanted_title')), 'Hi');
    await tester.tap(find.byKey(const Key('wanted_send')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Please give a short title'), findsOneWidget);
  });

  testWidgets('moderators see the priority list with its terms', (
    tester,
  ) async {
    final s = FakeWanted(needs: [vlookup])
      ..priorities = const [
        WantedPriority(id: 'n1', title: 'Percent of a number', priority: 2,
            fanIn: 2, gapCount: 0, coverageDeficit: 1),
        WantedPriority(id: 'n2', title: 'Partly covered', priority: 0.5,
            fanIn: 1, gapCount: 0, coverageDeficit: 0.5),
      ];
    await pump(tester, s, moderator: true);
    await tester.tap(find.byKey(const Key('wanted_priority_tab')));
    await tester.pumpAndSettle();
    expect(find.text('2.00'), findsOneWidget);
    expect(find.text('used in 2 places · few requests · nothing linked'), findsOneWidget);
    expect(find.text('used in 1 place · few requests · partly covered'), findsOneWidget);
  });

  testWidgets('learners see no priority tab', (tester) async {
    await pump(tester, FakeWanted(needs: [vlookup]));
    expect(find.byKey(const Key('wanted_priority_tab')), findsNothing);
  });

  testWidgets('moderators approve, reject with a note and fulfil', (
    tester,
  ) async {
    final s = FakeWanted(
      needs: [vlookup],
      proposed: [
        const WantedNeed(id: 'p1', title: 'Charts', status: 'proposed'),
      ],
      mine: [const LinkableContribution('c9', 'Shared lesson', 'published')],
    );
    await pump(tester, s, moderator: true);
    await tester.tap(find.byKey(const Key('wanted_review_tab')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('wanted_approve_p1')));
    await tester.pumpAndSettle();
    expect(s.calls, contains('review:p1:true:null'));

    await tester.tap(find.byKey(const Key('wanted_reject_p1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('wanted_note')), 'Off topic');
    await tester.tap(find.byKey(const Key('wanted_note_confirm')));
    await tester.pumpAndSettle();
    expect(s.calls, contains('review:p1:false:Off topic'));

    await tester.tap(find.byKey(const Key('wanted_fulfilled_n1_c9')));
    await tester.pumpAndSettle();
    expect(s.calls, contains('status:n1:fulfilled:c9'));
  });

  test('error codes map from server messages', () {
    expect(
      WantedBoardException.from(
        const PostgrestException(message: 'published_link_required'),
      ).code,
      'published_link_required',
    );
    expect(WantedBoardException.from(StateError('x')).code, 'unknown');
  });
}

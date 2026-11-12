import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/lesson_contribution_provider.dart';
import 'package:learning_pwa/services/community/lesson_contribution_service.dart';
import 'package:learning_pwa/widgets/community/share_with_community_action.dart';

class FakeContributionService extends LessonContributionService {
  ContributionStatus? latest;
  ContributionStatus? next;
  ContributionException? error;
  final submitted = <Map<String, Object>>[];
  final withdrawn = <String>[];

  @override
  Future<ContributionStatus?> latestFor(String lessonId) async => latest;

  @override
  Future<ContributionStatus> submit({
    required String lessonId,
    required ContributionLicense license,
    required bool rightsAttested,
    required bool aiAssisted,
  }) async {
    submitted.add({
      'lesson': lessonId,
      'license': license.wire,
      'rights': rightsAttested,
      'ai': aiAssisted,
    });
    if (error != null) throw error!;
    return latest = next!;
  }

  @override
  Future<void> withdraw(String contributionId) async {
    withdrawn.add(contributionId);
    latest = ContributionStatus(
      id: contributionId,
      version: latest!.version,
      status: 'withdrawn',
    );
  }
}

void main() {
  late FakeContributionService service;

  setUp(() => service = FakeContributionService());

  Future<void> pump(
    WidgetTester tester, {
    bool enabled = true,
    bool owner = true,
    List<String> tags = const [],
  }) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          publicContributionEnabledProvider.overrideWithValue(enabled),
          lessonContributionServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                ShareWithCommunityAction(
                  lessonId: 'lesson-1',
                  lessonTitle: 'My lesson',
                  isOwner: owner,
                  tags: tags,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const action = Key('share_with_community_action');
  const submit = Key('contribution_submit');

  testWidgets('hidden when the gate is OFF or for non-owners', (tester) async {
    await pump(tester, enabled: false);
    expect(find.byKey(action), findsNothing);
    await pump(tester, owner: false);
    expect(find.byKey(action), findsNothing);
  });

  testWidgets('submit needs the rights checkbox and sends the choices', (
    tester,
  ) async {
    service.next = const ContributionStatus(
      id: 'c1',
      version: 1,
      status: 'submitted',
    );
    await pump(tester, tags: const ['ai-generated']);
    await tester.tap(find.byKey(action));
    await tester.pumpAndSettle();
    expect(find.textContaining('stays private'), findsWidgets);

    expect(
      tester.widget<FilledButton>(find.byKey(submit)).onPressed,
      isNull,
      reason: 'rights not yet confirmed',
    );
    await tester.tap(find.byKey(const Key('contribution_rights')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(submit));
    await tester.pumpAndSettle();

    expect(service.submitted.single, {
      'lesson': 'lesson-1',
      'license': 'CC-BY-4.0',
      'rights': true,
      'ai': true,
    });
    expect(find.text('Sent for review. Your lesson stays private.'), findsOne);
    expect(find.textContaining('Waiting for review'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(submit)).onPressed,
      isNull,
      reason: 'one open contribution at a time',
    );
  });

  testWidgets('failed checks are explained and can be resubmitted', (
    tester,
  ) async {
    service.latest = const ContributionStatus(
      id: 'c1',
      version: 1,
      status: 'checks_failed',
      issues: ['answer_key_out_of_range'],
    );
    await pump(tester);
    await tester.tap(find.byKey(action));
    await tester.pumpAndSettle();
    expect(find.textContaining('no valid correct answer'), findsOneWidget);
    expect(find.text('Submit again'), findsOneWidget);
  });

  testWidgets('server refusals show a plain message', (tester) async {
    service.error = ContributionException('rate_limited');
    await pump(tester);
    await tester.tap(find.byKey(action));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('contribution_rights')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(submit));
    await tester.pumpAndSettle();
    expect(find.textContaining('try again tomorrow'), findsOneWidget);
  });

  testWidgets('a published contribution can be withdrawn', (tester) async {
    service.latest = const ContributionStatus(
      id: 'c9',
      version: 2,
      status: 'published',
    );
    await pump(tester);
    await tester.tap(find.byKey(action));
    await tester.pumpAndSettle();
    expect(find.textContaining('labelled unreviewed'), findsOneWidget);
    await tester.tap(find.byKey(const Key('contribution_withdraw')));
    await tester.pumpAndSettle();
    expect(service.withdrawn, ['c9']);
    expect(find.text('Version 2: Withdrawn.'), findsOneWidget);
  });

  test('ContributionStatus parses server rows and RPC results', () {
    final fromRpc = ContributionStatus.fromJson({
      'id': 'x',
      'version': 3,
      'status': 'checks_failed',
      'issues': [
        {'path': 'questions[0]', 'code': 'duplicate_options'},
      ],
    });
    expect(fromRpc.issues, ['duplicate_options']);
    expect(fromRpc.isOpen, isTrue);
    final fromRow = ContributionStatus.fromJson({
      'id': 'y',
      'version': 1,
      'status': 'rejected',
      'check_issues': [],
      'review_note': 'Off topic',
    });
    expect(fromRow.reviewNote, 'Off topic');
    expect(fromRow.canWithdraw, isFalse);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_strategy.dart';
import 'package:learning_pwa/providers/learning_support_controller_provider.dart';
import 'package:learning_pwa/providers/lesson_contribution_provider.dart';
import 'package:learning_pwa/screens/governance/check_dispute_review_screen.dart';
import 'package:learning_pwa/services/learning_support/bridge_library.dart';
import 'package:learning_pwa/services/learning_support/check_dispute_service.dart';
import 'package:learning_pwa/services/learning_support/support_session_store.dart';
import 'package:learning_pwa/widgets/learning_support/learning_help_action.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeDisputeService extends CheckDisputeService {
  FakeDisputeService({this.quarantine = const {}, this.queue = const []});

  final Set<CheckRef> quarantine;
  final List<DisputedCheck> queue;
  final sent = <(CheckRef, CheckDisputeReason, String?)>[];
  final decisions = <(CheckRef, bool, String?)>[];
  DisputeSubmitOutcome reply = DisputeSubmitOutcome.sent;

  @override
  Future<DisputeSubmitOutcome> submit(
    CheckRef ref,
    CheckDisputeReason reason, {
    String? note,
  }) async {
    sent.add((ref, reason, note));
    return reply;
  }

  @override
  Future<Set<CheckRef>> quarantined() async => quarantine;

  @override
  Future<List<DisputedCheck>> openQueue() async => queue;

  @override
  Future<int> decide(CheckRef ref, {required bool uphold, String? note}) async {
    if (!uphold && (note ?? '').trim().isEmpty) {
      throw CheckDisputeException('dismiss_reason_required');
    }
    decisions.add((ref, uphold, note));
    return 2;
  }
}

const bridgeId = 'bridge-spreadsheet-percent-format';

CheckRef check(String item, {String version = '1.0.0'}) =>
    CheckRef(contentId: bridgeId, contentVersion: version, itemId: item);

void main() {
  late BridgeLibrary library;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    library = await BridgeLibrary.load(rootBundle);
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('learner side', () {
    Future<void> openBridge(
      WidgetTester tester,
      FakeDisputeService service, {
      required bool canSend,
    }) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            quickRescueEnabledProvider.overrideWithValue(true),
            autoGapSuggestionsEnabledProvider.overrideWithValue(true),
            canSendCheckDisputesProvider.overrideWithValue(canSend),
            checkDisputeServiceProvider.overrideWithValue(service),
            bridgeLibraryProvider.overrideWith((ref) async => library),
            supportSessionStoreProvider.overrideWithValue(
              SupportSessionStore(),
            ),
            supportOwnerScopeProvider.overrideWithValue('user-a'),
            supportContextIdProvider.overrideWith((ref, id) => 'ctx-1'),
            supportStrategyProvider.overrideWithValue(
              PersistedLearningStrategy.standard,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(
                actions: const [
                  LearningHelpAction(
                    lessonId: 'excel-101',
                    lessonTitle: 'Budget Totals in Excel',
                    tags: ['excel'],
                  ),
                ],
              ),
              body: const Text('lesson body'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('learning_help_action')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('support_choice_$bridgeId')));
      await tester.pumpAndSettle();
    }

    Future<void> reveal(WidgetTester tester, Finder f) async {
      await tester.scrollUntilVisible(
        f,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    Future<void> tapDispute(WidgetTester tester, String item) async {
      final f = find.byKey(Key('bridge-check-dispute-$item'));
      await reveal(tester, f);
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    testWidgets('a dispute is sent with a reason and note, never the answer', (
      tester,
    ) async {
      final service = FakeDisputeService();
      await openBridge(tester, service, canSend: true);
      await tapDispute(tester, 'sp-check-2');

      // Send stays disabled until a reason is chosen.
      final send = find.byKey(const Key('check-dispute-send'));
      expect(tester.widget<FilledButton>(send).onPressed, isNull);
      await tester.tap(find.byKey(const Key('check-dispute-reason-unclear')));
      await tester.enterText(
        find.byKey(const Key('check-dispute-note')),
        '  Two answers look right  ',
      );
      await tester.pumpAndSettle();
      await tester.tap(send);
      await tester.pumpAndSettle();

      expect(service.sent.single.$1, check('sp-check-2'));
      expect(service.sent.single.$2, CheckDisputeReason.unclear);
      expect(service.sent.single.$3, 'Two answers look right');
      expect(find.text('Sent for review. Thank you.'), findsOneWidget);
      expect(
        find.byKey(const Key('bridge-check-disputed-sp-check-2')),
        findsOneWidget,
      );
    });

    testWidgets('cancelling sends nothing but keeps the local dispute', (
      tester,
    ) async {
      final service = FakeDisputeService();
      await openBridge(tester, service, canSend: true);
      await tapDispute(tester, 'sp-check-2');
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(service.sent, isEmpty);
      expect(
        find.byKey(const Key('bridge-check-disputed-sp-check-2')),
        findsOneWidget,
      );
    });

    testWidgets('a failed send still leaves the question out', (tester) async {
      final service = FakeDisputeService()..reply = DisputeSubmitOutcome.failed;
      await openBridge(tester, service, canSend: true);
      await tapDispute(tester, 'sp-check-2');
      await tester.tap(
        find.byKey(const Key('check-dispute-reason-wrong_answer')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('check-dispute-send')));
      await tester.pumpAndSettle();
      expect(find.textContaining("Couldn't send it"), findsOneWidget);
    });

    testWidgets('switched off or a guest: no dialog, nothing sent', (
      tester,
    ) async {
      final service = FakeDisputeService();
      await openBridge(tester, service, canSend: false);
      await tapDispute(tester, 'sp-check-2');
      expect(find.byKey(const Key('check-dispute-send')), findsNothing);
      expect(service.sent, isEmpty);
      expect(
        find.byKey(const Key('bridge-check-disputed-sp-check-2')),
        findsOneWidget,
      );
    });

    testWidgets('an upheld check is hidden; another version is not', (
      tester,
    ) async {
      final service = FakeDisputeService(
        quarantine: {
          check('sp-check-2'),
          check('sp-check-1', version: '0.9.0'),
        },
      );
      await openBridge(tester, service, canSend: false);
      final hidden = find.byKey(
        const Key('bridge-check-quarantined-sp-check-2'),
      );
      await reveal(tester, hidden);
      expect(find.textContaining('is being corrected'), findsOneWidget);
      expect(
        find.byKey(const Key('bridge-check-dispute-sp-check-2')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('bridge-check-quarantined-sp-check-1')),
        findsNothing,
        reason: 'the quarantine names version 0.9.0, the app has 1.0.0',
      );
    });
  });

  group('moderator review', () {
    Future<void> openReview(
      WidgetTester tester,
      FakeDisputeService service, {
      bool enabled = true,
      bool moderator = true,
    }) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checkDisputesEnabledProvider.overrideWithValue(enabled),
            checkDisputeServiceProvider.overrideWithValue(service),
            bridgeLibraryProvider.overrideWith((ref) async => library),
            contributionRolesProvider.overrideWith(
              (ref) async =>
                  ContributionRoles(moderator: moderator, admin: false),
            ),
          ],
          child: const MaterialApp(home: CheckDisputeReviewScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    final queue = [
      DisputedCheck(
        ref: check('sp-check-2'),
        reasons: const {
          CheckDisputeReason.wrongAnswer: 2,
          CheckDisputeReason.unclear: 1,
        },
        notes: const ['The key looks off'],
        firstReported: DateTime.utc(2026, 11, 19),
      ),
    ];

    testWidgets('shows the question, the marked answer and the reasons', (
      tester,
    ) async {
      await openReview(tester, FakeDisputeService(queue: queue));
      final c = library[bridgeId]!.checks.firstWhere(
        (c) => c.itemId == 'sp-check-2',
      );
      expect(find.text(c.prompt), findsOneWidget);
      expect(
        find.byKey(const Key('dispute_expected_sp-check-2')),
        findsOneWidget,
      );
      expect(
        find.textContaining('3 learner(s): The marked answer is wrong (2)'),
        findsOneWidget,
      );
      expect(find.textContaining('The key looks off'), findsOneWidget);
    });

    testWidgets('uphold and dismiss go to the server with the note', (
      tester,
    ) async {
      final service = FakeDisputeService(queue: queue);
      await openReview(tester, service);

      await tester.tap(find.byKey(const Key('dispute_dismiss_sp-check-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dispute_note_confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Please say why the question is fine.'), findsOneWidget);
      expect(service.decisions, isEmpty);

      await tester.tap(find.byKey(const Key('dispute_uphold_sp-check-2')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('dispute_note_field')),
        'Fix key',
      );
      await tester.tap(find.byKey(const Key('dispute_note_confirm')));
      await tester.pumpAndSettle();
      expect(service.decisions.single, (check('sp-check-2'), true, 'Fix key'));
      expect(find.textContaining('Upheld 2 dispute(s)'), findsOneWidget);
    });

    testWidgets('non-moderators and the OFF switch see a message only', (
      tester,
    ) async {
      await openReview(
        tester,
        FakeDisputeService(queue: queue),
        moderator: false,
      );
      expect(
        find.byKey(const Key('dispute_review_not_moderator')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('dispute_uphold_sp-check-2')), findsNothing);

      await openReview(
        tester,
        FakeDisputeService(queue: queue),
        enabled: false,
      );
      expect(find.byKey(const Key('dispute_review_disabled')), findsOneWidget);
    });
  });
}

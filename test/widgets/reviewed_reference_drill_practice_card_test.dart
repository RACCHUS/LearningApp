import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/services/assessment/exam_reference_drill_event_service.dart';
import 'package:learning_pwa/services/assessment/exam_reference_drill_practice_service.dart';
import 'package:learning_pwa/services/assessment/exam_reference_drill_scoring_service.dart';
import 'package:learning_pwa/widgets/targets/reviewed_reference_drill_practice_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../test_helpers/fake_supabase_client.dart';

const manifest = '33333333-3333-4333-8333-333333333333';
const item = '11111111-1111-4111-8111-111111111111';
const binding = '22222222-2222-4222-8222-222222222222';
const eventId = '44444444-4444-4444-8444-444444444444';

User _user(String id, {bool guest = false}) => User(
  id: id, isAnonymous: guest, appMetadata: const {},
  userMetadata: const {}, aud: 'authenticated',
  createdAt: '2026-10-20T00:00:00Z',
);

class _AuthForTest extends StateNotifier<AuthState> implements AuthNotifier {
  _AuthForTest(super.initial);
  void switchTo(AuthState state) => this.state = state;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ApprovedReferenceDrillPractice _practice() =>
    ApprovedReferenceDrillPractice.fromRpc({
      'assessment_item_id': item,
      'approved_binding_id': binding,
      'manifest_revision_id': manifest,
      'exam_part_key': 'project_management',
      'administration_date': '2027-06-01',
      'item_content_revision': 1,
      'answer_location_revision': 1,
      'steps': {
        for (final step in const [
          'resource_choice','section_location','interpretation','application'
        ]) step: {
          'prompt': 'Reviewed practice question for $step',
          'choices': [
            {'value': 'choice_a', 'label': 'Choice A'},
            {'value': 'choice_b', 'label': 'Choice B'},
          ],
        },
      },
    }, manifestId: manifest, partKey: 'project_management',
       examDate: DateTime.utc(2027,6,1));

class _FakePracticeApi extends ExamReferenceDrillPracticeService {
  _FakePracticeApi() : super(client: FakeSupabaseClient());
  final owners = <String>[];
  Completer<ApprovedReferenceDrillPractice?>? pending;
  ApprovedReferenceDrillPractice? delivered = _practice();

  @override
  Future<ApprovedReferenceDrillPractice?> fetch({
    required String expectedOwnerId,
    required String manifestRevisionId,
    required String examPartKey,
    required DateTime administrationDate,
  }) {
    owners.add(expectedOwnerId);
    if (pending != null) return pending!.future;
    if (manifestRevisionId != manifest ||
        examPartKey != 'project_management' ||
        administrationDate != DateTime.utc(2027, 6, 1)) {
      return Future.value(null);
    }
    return Future.value(delivered);
  }
}

class _FakeEventApi extends ExamReferenceDrillEventService {
  _FakeEventApi() : super(client: FakeSupabaseClient());
  final steps = <String>[];
  @override
  Future<Map<String, dynamic>> recordStep({
    String? expectedOwnerId,
    required String clientAttemptId,
    required String assessmentItemId,
    required String approvedBindingId,
    required String manifestRevisionId,
    required String examPartKey,
    required DateTime administrationDate,
    required int itemContentRevision,
    required int answerLocationRevision,
    required String step,
    required bool responded,
    required Duration appElapsed,
    required DateTime startedAt,
    required DateTime completedAt,
    Duration? selfReportedBookTime,
  }) async {
    expect(expectedOwnerId, 'A');
    expect(manifestRevisionId, manifest);
    expect(assessmentItemId, item);
    steps.add(step);
    return {'id': eventId};
  }
}

class _FakeScoreApi extends ExamReferenceDrillScoringService {
  _FakeScoreApi() : super(client: FakeSupabaseClient());
  final List<String> requested = [];
  bool failOnce = false;
  int completed = 0;
  @override
  Future<VerifiedReferenceDrillStepScore> scoreRecordedStep({
    required String expectedOwnerId,
    required String eventId,
    required String answerToken,
  }) async {
    requested.add(answerToken);
    if (failOnce) {
      failOnce = false;
      throw StateError('temporary network error');
    }
    completed++;
    return VerifiedReferenceDrillStepScore(
      step: const {
        1: 'resource_choice',
        2: 'section_location',
        3: 'interpretation',
        4: 'application',
      }[completed] ?? 'resource_choice',
      isCorrect: true, scoringVersion: 1,
      gradedAt: DateTime.utc(2027, 1, 1),
    );
  }
}

Future<void> _mount(WidgetTester tester, _AuthForTest auth,
    _FakePracticeApi practice, _FakeEventApi events, _FakeScoreApi scores) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [authProvider.overrideWith((ref) => auth)],
    child: MaterialApp(home: Scaffold(
      body: SingleChildScrollView(
        child: ReviewedReferenceDrillPracticeCard(
          manifestRevisionId: manifest,
          examPartKey: 'project_management',
          administrationDate: DateTime.utc(2027, 6, 1),
          practiceService: practice,
          eventService: events,
          scoringService: scores,
        ),
      ),
    )),
  ));
}

void main() {
  testWidgets('Guest and anonymous sessions never request reviewed prompts',
      (tester) async {
    final auth = _AuthForTest(GuestMode());
    final practice = _FakePracticeApi();
    await _mount(tester, auth, practice, _FakeEventApi(), _FakeScoreApi());
    expect(find.textContaining('Sign in with a permanent'), findsOneWidget);
    expect(find.text('Start reviewed practice'), findsNothing);
    auth.switchTo(AuthSuccess(_user('guest', guest:true)));
    await tester.pump();
    expect(find.text('Start reviewed practice'), findsNothing);
    expect(practice.owners, isEmpty);
  });

  testWidgets('Original prompts require explicit start, and R1-R4 persist',
      (tester) async {
    final auth = _AuthForTest(AuthSuccess(_user('A')));
    final practice = _FakePracticeApi();
    final events = _FakeEventApi();
    final scores = _FakeScoreApi();
    await _mount(tester, auth, practice, events, scores);
    expect(practice.owners, isEmpty);
    await tester.tap(find.text('Start reviewed practice'));
    await tester.pumpAndSettle();
    expect(practice.owners, ['A']);
    for (var i=0; i<4; i++) {
      expect(find.byKey(const Key('reviewed-drill-prompt')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('drill-choice:choice_a')));
      await tester.tap(find.byKey(const Key('drill-choice:choice_a')));
      await tester.ensureVisible(find.byKey(
        const Key('submit-reviewed-drill-step')));
      await tester.tap(find.byKey(const Key('submit-reviewed-drill-step')));
      await tester.pumpAndSettle();
    }
    expect(events.steps, [
      'resource_choice','section_location','interpretation','application',
    ]);
    expect(scores.requested.length,4);
    expect(find.byKey(const Key('reviewed-drill-complete')),findsOneWidget);
    expect(find.textContaining('do not predict licensing-exam success'),
        findsOneWidget);
  });

  testWidgets('Saved step retries scoring without writing another event',
      (tester) async {
    final auth = _AuthForTest(AuthSuccess(_user('A')));
    final practice = _FakePracticeApi();
    final events = _FakeEventApi();
    final scores = _FakeScoreApi()..failOnce = true;
    await _mount(tester, auth, practice, events, scores);
    await tester.tap(find.text('Start reviewed practice'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('drill-choice:choice_a')));
    await tester.tap(find.byKey(const Key('submit-reviewed-drill-step')));
    await tester.pumpAndSettle();
    expect(events.steps, ['resource_choice']);
    expect(find.text('Retry scoring'),findsOneWidget);
    await tester.tap(find.text('Retry scoring'));
    await tester.pumpAndSettle();
    expect(events.steps, ['resource_choice']);
    expect(scores.requested.length,2);
    expect(find.textContaining('R2 · Locate'),findsOneWidget);
  });

  testWidgets('Account switch while loading hides old owner questions',
      (tester) async {
    final auth = _AuthForTest(AuthSuccess(_user('A')));
    final practice = _FakePracticeApi();
    practice.pending = Completer<ApprovedReferenceDrillPractice?>();
    await _mount(tester, auth, practice, _FakeEventApi(), _FakeScoreApi());
    await tester.tap(find.text('Start reviewed practice'));
    await tester.pump();
    auth.switchTo(AuthSuccess(_user('B')));
    await tester.pump();
    practice.pending!.complete(_practice());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reviewed-drill-prompt')), findsNothing);
    expect(find.text('Start reviewed practice'), findsOneWidget);
    expect(practice.owners, ['A']);
  });

  testWidgets('No independently approved practice leaves general study open',
      (tester) async {
    final auth = _AuthForTest(AuthSuccess(_user('A')));
    final practice = _FakePracticeApi()..delivered = null;
    await _mount(tester, auth, practice, _FakeEventApi(), _FakeScoreApi());
    await tester.tap(find.text('Start reviewed practice'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No independently reviewed practice'),
        findsOneWidget);
    expect(find.byKey(const Key('reviewed-drill-prompt')), findsNothing);
  });
}

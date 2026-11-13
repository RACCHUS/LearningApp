import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/lesson_contribution_provider.dart';
import 'package:learning_pwa/screens/governance/contribution_review_screen.dart';
import 'package:learning_pwa/services/community/lesson_contribution_service.dart';

ContributionQueueItem item(String id, String status) =>
    ContributionQueueItem.fromJson({
      'id': id,
      'version': 1,
      'status': status,
      'license': 'CC-BY-4.0',
      'ai_assisted': true,
      'created_at': '2026-11-13T10:00:00Z',
      'snapshot': {
        'title': 'Lesson $id',
        'terms': [
          {'term': 'Base', 'definition': 'Starting amount'},
        ],
        'concepts': [],
        'questions': [
          {
            'question_text': 'Pick B',
            'options': ['A', 'B'],
            'correct_answer': 1,
          },
        ],
      },
    });

class FakeService extends LessonContributionService {
  final byStatus = <String, List<ContributionQueueItem>>{};
  final calls = <String>[];
  ContributionException? error;

  @override
  Future<List<ContributionQueueItem>> fetchQueue(List<String> statuses) async =>
      [for (final s in statuses) ...?byStatus[s]];

  Future<void> _record(String call) async {
    calls.add(call);
    if (error != null) throw error!;
  }

  @override
  Future<void> review(String id, {required bool approve, String? note}) =>
      _record('${approve ? 'approve' : 'reject'}:$id:${note ?? ''}');

  @override
  Future<void> publish(String id) => _record('publish:$id');

  @override
  Future<void> takedown(String id, String reason) =>
      _record('takedown:$id:$reason');
}

void main() {
  late FakeService service;

  setUp(() => service = FakeService());

  Future<void> pump(
    WidgetTester tester, {
    bool moderator = true,
    bool admin = false,
    bool enabled = true,
  }) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lessonContributionServiceProvider.overrideWithValue(service),
          publicContributionEnabledProvider.overrideWithValue(enabled),
          contributionRolesProvider.overrideWith(
            (ref) async =>
                ContributionRoles(moderator: moderator, admin: admin),
          ),
        ],
        child: const MaterialApp(home: ContributionReviewScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> expand(WidgetTester tester, String id) async {
    await tester.tap(find.text('Lesson $id'));
    await tester.pumpAndSettle();
  }

  testWidgets('non-moderators are refused', (tester) async {
    await pump(tester, moderator: false);
    expect(find.byKey(const Key('contribution_review_denied')), findsOne);
  });

  testWidgets('shows the frozen snapshot with the marked answer', (
    tester,
  ) async {
    service.byStatus['submitted'] = [item('a', 'submitted')];
    await pump(tester);
    expect(find.textContaining('CC-BY-4.0 · AI-assisted'), findsOneWidget);
    await expand(tester, 'a');
    expect(find.text('Base: Starting amount'), findsOneWidget);
    expect(find.text('✓ B'), findsOneWidget);
    expect(find.text('· A'), findsOneWidget);
  });

  testWidgets('approve with an optional note; reject needs the dialog', (
    tester,
  ) async {
    service.byStatus['submitted'] = [item('a', 'submitted')];
    await pump(tester);
    await expand(tester, 'a');
    expect(find.byKey(const Key('publish_a')), findsNothing);

    await tester.tap(find.byKey(const Key('approve_a')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('review_reason_field')), 'ok');
    await tester.tap(find.byKey(const Key('review_reason_confirm')));
    await tester.pumpAndSettle();
    expect(service.calls, ['approve:a:ok']);
  });

  testWidgets('moderators do not see Publish on approved items', (
    tester,
  ) async {
    service.byStatus['ready_for_publication'] = [
      item('b', 'ready_for_publication'),
    ];
    await pump(tester);
    await tester.tap(find.text('Approved'));
    await tester.pumpAndSettle();
    await expand(tester, 'b');
    expect(find.byKey(const Key('publish_b')), findsNothing);
    expect(find.byKey(const Key('reject_b')), findsOneWidget);
  });

  testWidgets('admins can publish approved items', (tester) async {
    service.byStatus['ready_for_publication'] = [
      item('b', 'ready_for_publication'),
    ];
    await pump(tester, admin: true);
    await tester.tap(find.text('Approved'));
    await tester.pumpAndSettle();
    await expand(tester, 'b');
    await tester.tap(find.byKey(const Key('publish_b')));
    await tester.pumpAndSettle();
    expect(service.calls, ['publish:b']);
    expect(find.textContaining('Community · unreviewed'), findsOneWidget);
  });

  testWidgets('switch OFF pauses review but takedown still works', (
    tester,
  ) async {
    service.byStatus['submitted'] = [item('a', 'submitted')];
    service.byStatus['published'] = [item('p', 'published')];
    await pump(tester, enabled: false);
    expect(find.byKey(const Key('contribution_review_paused')), findsOne);
    await expand(tester, 'a');
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('approve_a'))).onPressed,
      isNull,
    );

    await tester.tap(find.text('Published'));
    await tester.pumpAndSettle();
    await expand(tester, 'p');
    await tester.tap(find.byKey(const Key('takedown_p')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('review_reason_field')),
      'copyright report',
    );
    await tester.tap(find.byKey(const Key('review_reason_confirm')));
    await tester.pumpAndSettle();
    expect(service.calls, ['takedown:p:copyright report']);
  });

  testWidgets('server refusals are shown in plain language', (tester) async {
    service.byStatus['submitted'] = [item('a', 'submitted')];
    service.error = ContributionException('cannot_review_own_contribution');
    await pump(tester);
    await expand(tester, 'a');
    await tester.tap(find.byKey(const Key('reject_a')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('review_reason_field')), 'x');
    await tester.tap(find.byKey(const Key('review_reason_confirm')));
    await tester.pumpAndSettle();
    expect(find.text('You cannot review your own lesson.'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/lesson_contribution_provider.dart';
import 'package:learning_pwa/screens/community/community_lessons_screen.dart';
import 'package:learning_pwa/services/community/lesson_contribution_service.dart';

class FakeService extends LessonContributionService {
  List<ContributionQueueItem> published = [];
  final reports = <String>[];
  ContributionException? error;

  @override
  Future<List<ContributionQueueItem>> listPublished({int limit = 50}) async =>
      published;

  @override
  Future<void> report(String id, String reason, {String? description}) async {
    reports.add('$id:$reason:${description ?? ''}');
    if (error != null) throw error!;
  }
}

ContributionQueueItem shared() => ContributionQueueItem.fromJson({
  'id': 'p1',
  'version': 2,
  'status': 'published',
  'license': 'CC-BY-SA-4.0',
  'ai_assisted': true,
  'created_at': '2026-11-13T10:00:00Z',
  'snapshot': {
    'title': 'Fractions basics',
    'terms': [
      {'term': 'Numerator', 'definition': 'The top number'},
    ],
    'concepts': [],
    'questions': [
      {
        'question_text': '1/2 as a decimal?',
        'options': ['0.2', '0.5'],
        'correct_answer': 1,
        'explanation': '1 ÷ 2',
      },
    ],
  },
});

void main() {
  late FakeService service;
  setUp(() => service = FakeService());

  Future<void> pump(WidgetTester tester, {bool enabled = true}) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lessonContributionServiceProvider.overrideWithValue(service),
          publicContributionEnabledProvider.overrideWithValue(enabled),
        ],
        child: const MaterialApp(home: CommunityLessonsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('switch OFF: nothing is listed', (tester) async {
    service.published = [shared()];
    await pump(tester, enabled: false);
    expect(find.byKey(const Key('community_lessons_off')), findsOneWidget);
    expect(find.text('Fractions basics'), findsNothing);
  });

  testWidgets('lists copies with the unreviewed label', (tester) async {
    service.published = [shared()];
    await pump(tester);
    expect(find.text('Fractions basics'), findsOneWidget);
    expect(
      find.text('Community · unreviewed · CC-BY-SA-4.0 · AI-assisted'),
      findsOneWidget,
    );
  });

  testWidgets('reader hides answers until asked', (tester) async {
    service.published = [shared()];
    await pump(tester);
    await tester.tap(find.text('Fractions basics'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('community_label')), findsOneWidget);
    expect(find.text('Numerator: The top number'), findsOneWidget);
    expect(find.text('· 0.5'), findsOneWidget);
    expect(find.text('✓ 0.5'), findsNothing);
    await tester.tap(find.byKey(const Key('community_reveal_0')));
    await tester.pumpAndSettle();
    expect(find.text('✓ 0.5'), findsOneWidget);
    expect(find.text('Why: 1 ÷ 2'), findsOneWidget);
  });

  testWidgets('report sends reason and details', (tester) async {
    service.published = [shared()];
    await pump(tester);
    await tester.tap(find.text('Fractions basics'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('community_report')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('report_details')),
      'Answer key wrong',
    );
    await tester.tap(find.byKey(const Key('report_send')));
    await tester.pumpAndSettle();
    expect(service.reports, ['p1:misinformation:Answer key wrong']);
    expect(find.textContaining('A moderator will look at it'), findsOneWidget);
  });

  testWidgets('a duplicate report is explained', (tester) async {
    service.published = [shared()];
    service.error = ContributionException('already_reported');
    await pump(tester);
    await tester.tap(find.text('Fractions basics'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('community_report')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report_send')));
    await tester.pumpAndSettle();
    expect(find.textContaining('already reported'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/lesson_block.dart';
import 'package:learning_pwa/models/unified_lesson.dart';
import 'package:learning_pwa/providers/local_ai_provider.dart';
import 'package:learning_pwa/providers/unified_lesson_provider.dart';
import 'package:learning_pwa/services/ai/local_ai/local_ai_benchmark.dart';
import 'package:learning_pwa/services/ai/local_ai/local_ai_section_text.dart';
import 'package:learning_pwa/services/ai/local_ai/local_summarizer.dart';
import 'package:learning_pwa/widgets/ai/local_key_points_action.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_fixtures.dart';

LessonBlock block(String id, String type, Map<String, dynamic> content, int order) =>
    LessonBlock.fromJson({
      'id': id,
      'lesson_id': 'l1',
      'block_type': type,
      'sort_order': order,
      'content': content,
    });

final longText =
    r'A **percent** is a ratio whose denominator is $100$. ' * 4;

final blocks = [
  block('b1', 'markdown', {'text': '### Intro\n\n$longText'}, 1),
  block('b2', 'practice_prompt', {'prompt': 'SECRET-PRACTICE', 'answer': 'SECRET-ANSWER'}, 2),
  block('b3', 'callout', {'title': 'Key idea', 'body': 'Percent means per hundred.'}, 3),
];

class FakeSummarizer implements LocalSummarizer {
  FakeSummarizer(this.state, {this.fail = false});
  LocalAiAvailability state;
  final bool fail;
  final inputs = <String>[];

  @override
  Future<LocalAiAvailability> availability() async => state;

  @override
  Future<String> keyPoints(
    String text, {
    void Function(double fraction)? onDownloadProgress,
  }) async {
    inputs.add(text);
    if (fail) throw StateError('model crashed');
    onDownloadProgress?.call(1);
    return '- A percent is out of 100.\n- Percent means per hundred.';
  }
}

void main() {
  group('section text', () {
    test('reading blocks only, plain text, from the current block', () {
      final text = sectionTextForSummary(blocks, currentBlockId: 'b3');
      expect(text, 'Key idea\nPercent means per hundred.');
      final all = sectionTextForSummary(blocks);
      expect(all, contains('A percent is a ratio whose denominator is 100.'));
      expect(all, isNot(contains('SECRET')));
      expect(all, isNot(contains('**')));
      expect(all, isNot(contains(r'$')));
    });

    test('stops at the length limit', () {
      expect(sectionTextForSummary(blocks, maxChars: 60).length, lessThanOrEqualTo(60));
    });
  });

  group('benchmark', () {
    test('keeps the last 10 timings and a median, counts failures', () {
      var b = const LocalAiBenchmark();
      for (var i = 1; i <= 12; i++) {
        b = b.recordSuccess(Duration(milliseconds: i * 100));
      }
      b = b.recordFailure();
      expect(b.recentMs, hasLength(10));
      expect(b.recentMs.first, 300);
      expect(b.runs, 13);
      expect(b.failures, 1);
      expect(b.medianMs, 800);
      expect(LocalAiBenchmark.fromJson(b.toJson()).recentMs, b.recentMs);
    });
  });

  test('availability parsing never guesses', () {
    expect(LocalAiAvailability.parse('available'), LocalAiAvailability.available);
    expect(LocalAiAvailability.parse('something-new'), LocalAiAvailability.unsupported);
    expect(LocalAiAvailability.unavailable.usable, isFalse);
    expect(LocalAiAvailability.downloadable.usable, isTrue);
  });

  group('action', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<FakeSummarizer> pump(
      WidgetTester tester, {
      bool enabled = true,
      LocalAiAvailability state = LocalAiAvailability.available,
      bool fail = false,
    }) async {
      final fake = FakeSummarizer(state, fail: fail);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          localAiEnabledProvider.overrideWithValue(enabled),
          localSummarizerProvider.overrideWithValue(fake),
          unifiedLessonProvider('l1').overrideWith(
            (ref) async => UnifiedLesson(
              lesson: TestFixtures.createTestLesson(id: 'l1', title: 'Percent'),
              blocks: blocks,
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: LocalKeyPointsAction(lessonId: 'l1')),
        ),
      ));
      await tester.pumpAndSettle();
      return fake;
    }

    const action = Key('local_ai_key_points_action');

    testWidgets('hidden when switched off or unsupported', (tester) async {
      await pump(tester, enabled: false);
      expect(find.byKey(action), findsNothing);
      await pump(tester, state: LocalAiAvailability.unsupported);
      expect(find.byKey(action), findsNothing);
      await pump(tester, state: LocalAiAvailability.unavailable);
      expect(find.byKey(action), findsNothing);
    });

    testWidgets('summarizes on this device and shows the caveat and timing', (tester) async {
      final fake = await pump(tester);
      await tester.tap(find.byKey(action));
      await tester.pumpAndSettle();
      expect(fake.inputs, hasLength(1));
      expect(fake.inputs.single, isNot(contains('SECRET')));
      expect(find.byKey(const Key('local_ai_key_points_sheet')), findsOneWidget);
      expect(find.textContaining('Percent means per hundred.'), findsWidgets);
      expect(find.textContaining('It can be wrong'), findsOneWidget);
      expect(find.textContaining('on this device'), findsWidgets);
      final bench = await LocalAiBenchmark.load();
      expect(bench.runs, 1);
    });

    testWidgets('a first download is disclosed and can be declined', (tester) async {
      final fake = await pump(tester, state: LocalAiAvailability.downloadable);
      await tester.tap(find.byKey(action));
      await tester.pumpAndSettle();
      expect(find.textContaining('22 GB'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(fake.inputs, isEmpty);

      await tester.tap(find.byKey(action));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('local_ai_download_confirm')));
      await tester.pumpAndSettle();
      expect(fake.inputs, hasLength(1));
    });

    testWidgets('a failure says nothing was sent and is counted', (tester) async {
      await pump(tester, fail: true);
      await tester.tap(find.byKey(action));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nothing was sent anywhere'), findsOneWidget);
      expect((await LocalAiBenchmark.load()).failures, 1);
    });
  });
}

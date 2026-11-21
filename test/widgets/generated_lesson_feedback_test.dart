import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/widgets/lesson/generated_lesson_feedback_action.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

class FakeFeedbackApi implements LessonFeedbackApi {
  FakeFeedbackApi(this.current, {this.fail = false});
  LessonFeedbackChip? current;
  final bool fail;
  final calls = <LessonFeedbackChip?>[];

  @override
  Future<LessonFeedbackChip?> mine(String lessonId) async => current;

  @override
  Future<void> set(String lessonId, LessonFeedbackChip? chip) async {
    if (fail) throw StateError('down');
    calls.add(chip);
    current = chip;
  }
}

User user({bool anonymous = false}) => User(
  id: 'u1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-11-21T00:00:00Z',
  isAnonymous: anonymous,
);

void main() {
  test('shown only on AI-generated lessons, for permanent accounts, when on', () {
    final signedIn = AuthSuccess(user());
    expect(showLessonFeedback(enabled: true, auth: signedIn, tags: ['ai-generated']), isTrue);
    expect(showLessonFeedback(enabled: false, auth: signedIn, tags: ['ai-generated']), isFalse);
    expect(showLessonFeedback(enabled: true, auth: signedIn, tags: ['algebra']), isFalse);
    expect(showLessonFeedback(enabled: true, auth: GuestMode(), tags: ['ai-generated']), isFalse);
    expect(
      showLessonFeedback(enabled: true, auth: AuthSuccess(user(anonymous: true)), tags: ['ai-generated']),
      isFalse,
    );
  });

  Future<FakeFeedbackApi> pump(WidgetTester tester, FakeFeedbackApi api) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [lessonFeedbackApiProvider.overrideWithValue(api)],
      child: const MaterialApp(home: Scaffold(body: GeneratedLessonFeedbackSheet(lessonId: 'l1'))),
    ));
    await tester.pumpAndSettle();
    return api;
  }

  bool selected(WidgetTester tester, String wire) =>
      tester.widget<ChoiceChip>(find.byKey(Key('lesson_feedback_$wire'))).selected;

  testWidgets('shows the five chips and the earlier choice', (tester) async {
    await pump(tester, FakeFeedbackApi(LessonFeedbackChip.confusing));
    for (final c in LessonFeedbackChip.values) {
      expect(find.text(c.label), findsOneWidget);
    }
    expect(selected(tester, 'confusing'), isTrue);
    expect(find.textContaining('does not change the lesson'), findsOneWidget);
  });

  testWidgets('picking sets it; picking again clears it', (tester) async {
    final api = await pump(tester, FakeFeedbackApi(null));
    await tester.tap(find.byKey(const Key('lesson_feedback_too_hard')));
    await tester.pumpAndSettle();
    expect(api.calls, [LessonFeedbackChip.tooHard]);
    expect(selected(tester, 'too_hard'), isTrue);
    await tester.tap(find.byKey(const Key('lesson_feedback_too_hard')));
    await tester.pumpAndSettle();
    expect(api.calls, [LessonFeedbackChip.tooHard, null]);
    expect(selected(tester, 'too_hard'), isFalse);
    expect(find.text('Cleared.'), findsOneWidget);
  });

  testWidgets('a failure keeps the old choice and says so', (tester) async {
    await pump(tester, FakeFeedbackApi(null, fail: true));
    await tester.tap(find.byKey(const Key('lesson_feedback_wrong')));
    await tester.pumpAndSettle();
    expect(selected(tester, 'wrong'), isFalse);
    expect(find.textContaining('Could not save'), findsOneWidget);
  });

  test('wire values match the server', () {
    expect(LessonFeedbackChip.values.map((c) => c.wire),
        ['too_hard', 'too_easy', 'confusing', 'wrong', 'not_what_i_needed']);
  });
}

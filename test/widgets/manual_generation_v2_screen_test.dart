import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/providers/manual_generation_v2_provider.dart';
import 'package:learning_pwa/screens/lessons/manual_generation_v2_screen.dart';
import 'package:learning_pwa/services/content_generation/manual_job.dart';
import 'package:learning_pwa/services/content_generation/manual_job_store.dart';
import 'package:learning_pwa/services/content_generation/manual_prompt_builder.dart';
import 'package:learning_pwa/services/content_generation/model_capability_profile.dart';
import 'package:learning_pwa/services/content_generation/model_capability_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late List<String> imported;
  String? clipboard;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    imported = [];
    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String?;
          }
          if (call.method == 'Clipboard.getData') {
            return {'text': clipboard};
          }
          return null;
        });
  });

  Future<void> pump(WidgetTester tester, {required bool enabled}) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/gen',
      routes: [
        GoRoute(
          path: '/gen',
          builder: (_, __) =>
              const ManualGenerationV2Screen(initialSubject: 'Percentages'),
        ),
        GoRoute(
          path: '/lesson/:id',
          builder: (_, s) => Text('lesson ${s.pathParameters['id']}'),
        ),
        GoRoute(
          path: '/create-lesson',
          builder: (_, __) => const Text('create'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          manualGenerationV2EnabledProvider.overrideWithValue(enabled),
          manualJobOwnerProvider.overrideWithValue('owner-1'),
          manualDraftImporterProvider.overrideWithValue((json) async {
            imported.add(json);
            return 'new-lesson';
          }),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('flag OFF shows a safe message and nothing else', (tester) async {
    await pump(tester, enabled: false);
    expect(find.byKey(const Key('manual_v2_disabled')), findsOneWidget);
    expect(find.byKey(const Key('manual_v2_make_plan')), findsNothing);
  });

  testWidgets('plan → copy → paste → import a private draft', (tester) async {
    await pump(tester, enabled: true);
    await tester.enterText(
      find.byKey(const Key('manual_v2_ideas')),
      'Percent change',
    );
    await tester.tap(find.byKey(const Key('manual_v2_make_plan')));
    await tester.pumpAndSettle();
    expect(find.textContaining('0 of 4 items ready'), findsOneWidget);

    await tester.tap(find.byKey(const Key('manual_v2_copy_prompt')));
    await tester.pumpAndSettle();
    expect(clipboard, contains('FILL EXACTLY THESE 3 SLOTS'));
    final job = RegExp(r'"job": "(J\w{4})"').firstMatch(clipboard!)!.group(1)!;

    // First reply: S1 and S2 only, with no end marker.
    await tester.enterText(
      find.byKey(const Key('manual_v2_paste')),
      jsonEncode({
        'schema': 'la-gen/1.1',
        'job': job,
        'items': [
          {
            'slot': 'S1',
            'kind': 'explanation',
            'concept': 'C1',
            'title': 'Percent change',
            'text': 'Change divided by the original.',
          },
          {
            'slot': 'S2',
            'kind': 'term',
            'concept': 'C1',
            'term': 'Original amount',
            'definition': 'The starting value.',
          },
        ],
      }),
    );
    await tester.tap(find.byKey(const Key('manual_v2_check')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Accepted 2 new item(s)'), findsOneWidget);
    expect(find.textContaining('may have been cut off'), findsOneWidget);
    expect(find.textContaining('Still needed: S3, S4'), findsOneWidget);
    expect(
      find.textContaining('Import the 2 ready item(s) only'),
      findsOneWidget,
    );

    // The rest, as one-object-per-line records.
    await tester.tap(find.byKey(const Key('manual_v2_copy_prompt')));
    await tester.pumpAndSettle();
    expect(clipboard, contains('FILL EXACTLY THESE 2 SLOTS'));
    String q(String slot, String answer) => jsonEncode({
      'slot': slot,
      'kind': 'mcq',
      'concept': 'C1',
      'stem': 'From 50 to 60 is what change?',
      'options': ['10%', '20%', '60%'],
      'answer': answer,
    });
    await tester.enterText(
      find.byKey(const Key('manual_v2_paste')),
      '${q('S3', 'B')}\n${q('S4', 'Z')}\n{"end":"END-$job"}',
    );
    await tester.tap(find.byKey(const Key('manual_v2_check')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Accepted 1 new item(s)'), findsOneWidget);
    expect(find.textContaining('3 of 4 items ready'), findsOneWidget);

    expect(find.textContaining('Unreviewed AI content'), findsOneWidget);
    await tester.tap(find.byKey(const Key('manual_v2_import')));
    await tester.pumpAndSettle();
    expect(find.text('lesson new-lesson'), findsOneWidget);
    final lesson = jsonDecode(imported.single) as Map<String, dynamic>;
    expect(lesson['title'], 'Percentages');
    expect((lesson['questions'] as List).single['correct_answer'], 1);
    expect(lesson['tags'], contains('unreviewed'));
  });

  testWidgets('invalid plans explain themselves', (tester) async {
    await pump(tester, enabled: true);
    await tester.tap(find.byKey(const Key('manual_v2_make_plan')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('manual_v2_plan_error')), findsOneWidget);
    expect(find.byKey(const Key('manual_v2_copy_prompt')), findsNothing);
  });

  testWidgets('a saved job is offered and resumes with its items', (
    tester,
  ) async {
    final job = ManualJob.plan(
      ManualJobRequest(
        subject: 'Saved topic',
        concepts: ['Idea'],
        questionsPerConcept: 0,
        includeTerms: false,
      ),
    );
    final saved = ManualJobSession(job)
      ..applyPaste(
        jsonEncode({
          'schema': 'la-gen/1.1',
          'job': job.plan.jobCode,
          'items': [
            {
              'slot': 'S1',
              'kind': 'explanation',
              'concept': 'C1',
              'title': 'Idea',
              'text': 'Explained.',
            },
          ],
        }),
      );
    await ManualJobStore(editorId: 'earlier').save('owner-1', saved);

    await pump(tester, enabled: true);
    expect(find.byKey(const Key('manual_v2_resume_card')), findsOneWidget);
    expect(find.textContaining('"Saved topic", 1 of 1 items ready'), findsOne);
    await tester.tap(find.byKey(const Key('manual_v2_resume')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 of 1 items ready'), findsWidgets);
    expect(find.byKey(const Key('manual_v2_import')), findsOneWidget);
  });

  testWidgets('progress is saved after checking a reply', (tester) async {
    await pump(tester, enabled: true);
    await tester.enterText(find.byKey(const Key('manual_v2_ideas')), 'Idea');
    await tester.tap(find.byKey(const Key('manual_v2_make_plan')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('manual_v2_save_status'))).data,
      'Saved on this device.',
    );
    final stored = await ManualJobStore(editorId: 'x').load('owner-1');
    expect(stored!.session.job.request.subject, 'Percentages');
  });

  group('AI chat capability profile', () {
    ModelSizeTier tier(WidgetTester tester) => tester
        .widget<SegmentedButton<ModelSizeTier>>(
          find.byKey(const Key('manual_v2_tier')),
        )
        .selected
        .single;

    testWidgets('picking a chat applies its saved suggestion', (tester) async {
      var p = const ModelCapabilityProfile(label: AiChatLabel.gemini);
      for (var i = 0; i < 3; i++) {
        p = p.record(
          const ReplyObservation(
            mode: ManualOutputMode.package,
            requested: 3,
            filled: 3,
            itemProblems: 0,
            unreadable: false,
            endMarker: true,
          ),
        );
      }
      await ModelCapabilityStore().save(
        'owner-1',
        CapabilityProfiles(profiles: {AiChatLabel.gemini: p}),
      );
      await pump(tester, enabled: true);
      expect(tier(tester), ModelSizeTier.compact);
      expect(find.byKey(const Key('manual_v2_ai_suggestion')), findsNothing);

      await tester.tap(find.byKey(const Key('manual_v2_ai_gemini')));
      await tester.pumpAndSettle();
      expect(tier(tester), ModelSizeTier.standard);
      expect(find.textContaining('Based on 3 replies'), findsOneWidget);
      expect(
        (await ModelCapabilityStore().load('owner-1')).selected,
        AiChatLabel.gemini,
      );
    });

    testWidgets('a checked reply counts once, and can be forgotten', (
      tester,
    ) async {
      await pump(tester, enabled: true);
      await tester.tap(find.byKey(const Key('manual_v2_ai_claude')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Not enough replies'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('manual_v2_ideas')), 'Idea');
      await tester.tap(find.byKey(const Key('manual_v2_make_plan')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('manual_v2_copy_prompt')));
      await tester.pumpAndSettle();
      final job = RegExp(
        r'"job": "(J\w{4})"',
      ).firstMatch(clipboard!)!.group(1)!;
      await tester.enterText(
        find.byKey(const Key('manual_v2_paste')),
        jsonEncode({
          'schema': 'la-gen/1.1',
          'job': job,
          'items': [
            {
              'slot': 'S1',
              'kind': 'explanation',
              'concept': 'C1',
              'title': 'Idea',
              'text': 'Explained.',
            },
          ],
          'end': 'END-$job',
        }),
      );
      await tester.tap(find.byKey(const Key('manual_v2_check')));
      await tester.pumpAndSettle();
      // Checking the same reply again without a new prompt is not counted.
      await tester.tap(find.byKey(const Key('manual_v2_check')));
      await tester.pumpAndSettle();

      final saved = await ModelCapabilityStore().load('owner-1');
      final claude = saved.profileFor(AiChatLabel.claude);
      expect(claude.replies, 1);
      expect(claude.clean, 0, reason: 'asked for 3 slots, filled 1');
      expect(claude.missingEnd, 0);
      final raw = jsonEncode(claude.toJson());
      expect(raw, isNot(contains('Explained')));

      await tester.tap(find.byKey(const Key('manual_v2_ai_forget')));
      await tester.pumpAndSettle();
      final cleared = await ModelCapabilityStore().load('owner-1');
      expect(cleared.profiles, isEmpty);
      expect(cleared.selected, AiChatLabel.claude);
    });

    testWidgets('no chat picked: nothing is learned', (tester) async {
      await pump(tester, enabled: true);
      await tester.enterText(find.byKey(const Key('manual_v2_ideas')), 'Idea');
      await tester.tap(find.byKey(const Key('manual_v2_make_plan')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('manual_v2_copy_prompt')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('manual_v2_paste')), '{}');
      await tester.tap(find.byKey(const Key('manual_v2_check')));
      await tester.pumpAndSettle();
      expect((await ModelCapabilityStore().load('owner-1')).profiles, isEmpty);
    });
  });

  group('blocked clipboard (browsers may refuse access)', () {
    void blockClipboard() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData' ||
                call.method == 'Clipboard.getData') {
              throw PlatformException(code: 'NotAllowedError');
            }
            if (call.method == 'Clipboard.hasStrings') return {'value': false};
            return null;
          });
    }

    String reply(String job) => jsonEncode({
      'schema': 'la-gen/1.1',
      'job': job,
      'items': [
        {
          'slot': 'S1',
          'kind': 'explanation',
          'concept': 'C1',
          'title': 'Idea',
          'text': 'Explained.',
        },
      ],
      'end': 'END-$job',
    });

    Future<String> planOneSlot(WidgetTester tester) async {
      await pump(tester, enabled: true);
      await tester.tap(find.byKey(const Key('manual_v2_ai_claude')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('manual_v2_ideas')), 'Idea');
      await tester.tap(find.byKey(const Key('manual_v2_questions')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('0 questions per idea').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Key terms'));
      await tester.tap(find.byKey(const Key('manual_v2_make_plan')));
      await tester.pumpAndSettle();
      final progress = tester
          .widget<Text>(find.byKey(const Key('manual_v2_progress')))
          .data!;
      expect(progress, contains('0 of 1 items ready'));
      return RegExp(r'Job (J\w{4})').firstMatch(progress)!.group(1)!;
    }

    Future<void> checkReply(WidgetTester tester, String job) async {
      await tester.enterText(
        find.byKey(const Key('manual_v2_paste')),
        reply(job),
      );
      await tester.tap(find.byKey(const Key('manual_v2_check')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Accepted 1 new item(s)'), findsOneWidget);
    }

    testWidgets('a failed copy explains itself and the reply still counts', (
      tester,
    ) async {
      final job = await planOneSlot(tester);
      blockClipboard();
      await tester.tap(find.byKey(const Key('manual_v2_copy_prompt')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining("Couldn't copy automatically"), findsOne);

      await checkReply(tester, job);
      final p = (await ModelCapabilityStore().load(
        'owner-1',
      )).profileFor(AiChatLabel.claude);
      expect(p.replies, 1);
      expect(p.clean, 1);
    });

    testWidgets('copying by hand from "Show the prompt" counts too', (
      tester,
    ) async {
      final job = await planOneSlot(tester);
      await tester.tap(find.text('Show the prompt'));
      await tester.pumpAndSettle();
      await checkReply(tester, job);
      final p = (await ModelCapabilityStore().load(
        'owner-1',
      )).profileFor(AiChatLabel.claude);
      expect(p.replies, 1);
    });

    testWidgets('a blocked paste explains itself', (tester) async {
      await planOneSlot(tester);
      blockClipboard();
      await tester.tap(find.text('Paste from clipboard'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining("Couldn't read the clipboard"), findsOne);
    });
  });

  testWidgets(
    'after a refresh, saved work appears once the switch settings arrive',
    (tester) async {
      final job = ManualJob.plan(
        ManualJobRequest(
          subject: 'Saved topic',
          concepts: ['Idea'],
          questionsPerConcept: 0,
          includeTerms: false,
        ),
      );
      await ManualJobStore(
        editorId: 'earlier',
      ).save('owner-1', ManualJobSession(job));
      await ModelCapabilityStore().save(
        'owner-1',
        const CapabilityProfiles(selected: AiChatLabel.gemini),
      );

      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // Switch settings load after the first frame, as on a page refresh.
      final switchOn = StateProvider<bool>((ref) => false);
      final container = ProviderContainer(
        overrides: [
          manualGenerationV2EnabledProvider.overrideWith(
            (ref) => ref.watch(switchOn),
          ),
          manualJobOwnerProvider.overrideWithValue('owner-1'),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ManualGenerationV2Screen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('manual_v2_disabled')), findsOneWidget);

      container.read(switchOn.notifier).state = true;
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('manual_v2_resume_card')), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('manual_v2_ai_gemini')))
            .selected,
        isTrue,
      );
    },
  );

  testWidgets('the optional quick test sets a starting suggestion', (
    tester,
  ) async {
    await pump(tester, enabled: true);
    expect(find.byKey(const Key('manual_v2_probe')), findsNothing);
    await tester.tap(find.byKey(const Key('manual_v2_ai_copilot')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quick test of this AI (optional)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('manual_v2_probe_copy')));
    await tester.pumpAndSettle();
    expect(clipboard, contains('la-probe/1'));

    await tester.enterText(
      find.byKey(const Key('manual_v2_probe_reply')),
      '{"schema":"la-probe/1","items":[{"n":1,"v":"ok"},{"n":2,"v":"ok"}],'
      '"end":"END-PROBE"}',
    );
    await tester.tap(find.byKey(const Key('manual_v2_probe_check')));
    await tester.pumpAndSettle();
    expect(find.textContaining('It worked'), findsOneWidget);
    expect(
      tester
          .widget<SegmentedButton<ModelSizeTier>>(
            find.byKey(const Key('manual_v2_tier')),
          )
          .selected
          .single,
      ModelSizeTier.standard,
    );
    final saved = (await ModelCapabilityStore().load(
      'owner-1',
    )).profileFor(AiChatLabel.copilot);
    expect(saved.probePassed, isTrue);
    expect(saved.replies, 0, reason: 'a probe is not a real reply');
  });
}

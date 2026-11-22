import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/prompt_quality_provider.dart';
import 'package:learning_pwa/services/analytics/prompt_quality_reporter.dart';
import 'package:learning_pwa/services/content_generation/manual_job.dart';
import 'package:learning_pwa/services/content_generation/manual_prompt_builder.dart';
import 'package:learning_pwa/services/content_generation/model_capability_profile.dart';
import 'package:learning_pwa/widgets/analytics/prompt_quality_privacy_section.dart';
import 'package:learning_pwa/widgets/lesson/prompt_quality_opt_in.dart';

ManualJobSession newSession() => ManualJobSession(
  ManualJob.plan(
    ManualJobRequest(
      subject: 'Percentages',
      concepts: ['Percent change'],
      questionsPerConcept: 1,
      includeTerms: false,
    ),
    random: Random(3),
  ),
);

const secretText = 'Compare with the start. SECRET-REPLY-TEXT';

String reply(ManualJobSession s, {bool withQuestion = true, bool end = true}) =>
    jsonEncode({
      'schema': 'la-gen/1.1',
      'job': s.job.plan.jobCode,
      'items': [
        {'slot': 'S1', 'kind': 'explanation', 'concept': 'C1', 'title': 'Change', 'text': secretText},
        if (withQuestion)
          {
            'slot': 'S2', 'kind': 'mcq', 'concept': 'C1', 'stem': '100 to 120?',
            'options': ['10%', '20%', '25%'], 'answer': 'B',
          },
      ],
      if (end) 'end': s.job.plan.endSentinel,
    });

PromptQualityEvent eventFor(ManualJobSession s, String text) {
  final requested = s.missing;
  final outcome = s.applyPaste(text);
  final observation = ReplyObservation.from(
    mode: ManualOutputMode.package,
    requested: requested,
    outcome: outcome,
    nowAccepted: s.accepted.keys.toSet(),
  );
  return PromptQualityEvent.fromReply(
    aiLabel: AiChatLabel.gemini,
    tier: ModelSizeTier.compact,
    observation: observation,
    outcome: outcome,
  );
}

class FakeApi implements PromptQualityApi {
  FakeApi(this.current);
  PromptQualityStatus current;
  final sent = <PromptQualityEvent>[];
  final consents = <bool>[];

  @override
  Future<PromptQualityStatus> status() async => current;

  @override
  Future<void> setConsent(bool consent) async {
    consents.add(consent);
    current = PromptQualityStatus(enabled: true, available: true, consented: consent);
  }

  @override
  Future<void> record(List<PromptQualityEvent> events) async => sent.addAll(events);

  @override
  Future<String> export() async => '{"events":[]}';
}

void main() {
  group('PromptQualityEvent', () {
    test('a complete reply is clean, with codes and counts only', () {
      final s = newSession();
      final e = eventFor(s, reply(s));
      expect(e.outcome, 'clean');
      expect(e.errorCode, 'none');
      expect(e.requested, 2);
      expect(e.accepted, 2);
      expect(e.sentinel, isTrue);
      final json = e.toJson();
      expect(json.keys.toSet(), {
        'event_id', 'pack_version', 'ai_label', 'tier', 'mode', 'outcome',
        'error_code', 'requested', 'accepted', 'sentinel',
      });
      expect(json['pack_version'], 'la-gen-1.1');
      expect(json['ai_label'], 'gemini');
      expect(json['tier'], 'compact');
      expect(json['mode'], 'package');
      expect(jsonEncode(json), isNot(contains('SECRET')));
      expect(jsonEncode(json), isNot(contains('Percent')));
    });

    test('a reply missing slots is partial', () {
      final s = newSession();
      final e = eventFor(s, reply(s, withQuestion: false));
      expect(e.outcome, 'partial');
      expect(e.accepted, 1);
    });

    test('an unreadable reply is refused with its error code', () {
      final s = newSession();
      final e = eventFor(s, 'Sure! Here is your lesson about percentages.');
      expect(e.outcome, 'refused');
      expect(e.errorCode, matches(RegExp(r'^[a-z_]+$')));
      expect(e.errorCode, isNot('none'));
      expect(e.accepted, 0);
    });
  });

  group('reporter', () {
    final event = PromptQualityEvent(
      aiLabel: AiChatLabel.claude, tier: ModelSizeTier.standard, mode: 'package',
      outcome: 'clean', errorCode: 'none', requested: 3, accepted: 3, sentinel: true,
    );

    Future<FakeApi> run(PromptQualityStatus status) async {
      final api = FakeApi(status);
      final container = ProviderContainer(overrides: [
        promptQualityApiProvider.overrideWithValue(api),
        promptQualityStatusProvider.overrideWith((ref) async => api.current),
      ]);
      addTearDown(container.dispose);
      await container.read(promptQualityReporterProvider)(event);
      return api;
    }

    test('sends nothing without the opt-in', () async {
      final api = await run(const PromptQualityStatus(enabled: true, available: true));
      expect(api.sent, isEmpty);
    });

    test('sends nothing while the switch is off', () async {
      final api = await run(const PromptQualityStatus(consented: true));
      expect(api.sent, isEmpty);
    });

    test('sends after opting in', () async {
      final api = await run(
        const PromptQualityStatus(enabled: true, available: true, consented: true),
      );
      expect(api.sent, [event]);
    });
  });

  group('opt-in', () {
    Future<FakeApi> pump(WidgetTester tester, PromptQualityStatus status) async {
      final api = FakeApi(status);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          promptQualityApiProvider.overrideWithValue(api),
          promptQualityStatusProvider.overrideWith((ref) async => api.current),
        ],
        child: const MaterialApp(home: Scaffold(body: PromptQualityOptIn())),
      ));
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('hidden unless the account may opt in', (tester) async {
      await pump(tester, const PromptQualityStatus(enabled: true));
      expect(find.byKey(const Key('prompt_quality_opt_in')), findsNothing);
      await pump(tester, PromptQualityStatus.off);
      expect(find.byKey(const Key('prompt_quality_opt_in')), findsNothing);
    });

    testWidgets('an opt-in under the older wording is offered the current one', (tester) async {
      final api = await pump(tester,
          const PromptQualityStatus(enabled: true, available: true, consented: true, scope: 1));
      expect(find.textContaining('later checks on that topic'), findsOneWidget);
      await tester.tap(find.byKey(const Key('prompt_quality_update_scope')));
      await tester.pumpAndSettle();
      expect(api.consents, [true]);
    });

    testWidgets('no scope offer once the current wording was accepted', (tester) async {
      await pump(tester,
          const PromptQualityStatus(enabled: true, available: true, consented: true, scope: 2));
      expect(find.byKey(const Key('prompt_quality_update_scope')), findsNothing);
    });

    test('status reads the consent scope', () {
      expect(PromptQualityStatus.fromJson({'consented': true, 'scope': 1}).scope, 1);
      expect(PromptQualityStatus.fromJson({'consented': true}).scope, 0);
    });

    testWidgets('with the switch off, an earlier opt-in can still be withdrawn', (tester) async {
      final api = await pump(tester, const PromptQualityStatus(consented: true, storedEvents: 3));
      final tile = tester.widget<SwitchListTile>(find.byKey(const Key('prompt_quality_opt_in')));
      expect(tile.value, isTrue);
      expect(tile.onChanged, isNotNull);
      await tester.tap(find.byKey(const Key('prompt_quality_opt_in')));
      await tester.pumpAndSettle();
      expect(api.consents, [false]);
    });

    testWidgets('privacy screen section: status, withdraw and export', (tester) async {
      final api = FakeApi(const PromptQualityStatus(enabled: true, available: true, consented: true, storedEvents: 2));
      await tester.pumpWidget(ProviderScope(
        overrides: [
          promptQualityApiProvider.overrideWithValue(api),
          promptQualityStatusProvider.overrideWith((ref) async => api.current),
        ],
        child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: PromptQualityPrivacySection()))),
      ));
      await tester.pumpAndSettle();
      expect(find.text('On: 2 row(s) stored.'), findsOneWidget);
      expect(find.textContaining('Never your prompts'), findsOneWidget);
      await tester.tap(find.byKey(const Key('prompt_quality_withdraw')));
      await tester.pumpAndSettle();
      expect(api.consents, [false]);
      expect(find.textContaining('Everything shared was deleted'), findsOneWidget);
    });

    testWidgets('off by default; turning it on saves the choice', (tester) async {
      final api = await pump(tester, const PromptQualityStatus(enabled: true, available: true));
      final tile = tester.widget<SwitchListTile>(find.byKey(const Key('prompt_quality_opt_in')));
      expect(tile.value, isFalse);
      expect(find.textContaining('Never your prompts'), findsOneWidget);

      await tester.tap(find.byKey(const Key('prompt_quality_opt_in')));
      await tester.pumpAndSettle();
      expect(api.consents, [true]);
      expect(
        tester.widget<SwitchListTile>(find.byKey(const Key('prompt_quality_opt_in'))).value,
        isTrue,
      );
    });
  });
}

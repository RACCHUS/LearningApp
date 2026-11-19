import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/content_generation/manual_job.dart';
import 'package:learning_pwa/services/content_generation/manual_prompt_builder.dart';
import 'package:learning_pwa/services/content_generation/model_capability_profile.dart';
import 'package:learning_pwa/services/content_generation/model_capability_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

ReplyObservation reply({
  int requested = 3,
  int? filled,
  int problems = 0,
  bool unreadable = false,
  bool end = true,
  ManualOutputMode mode = ManualOutputMode.package,
}) => ReplyObservation(
  mode: mode,
  requested: requested,
  filled: filled ?? requested,
  itemProblems: problems,
  unreadable: unreadable,
  endMarker: end,
);

ModelCapabilityProfile after(Iterable<ReplyObservation> replies) {
  var p = const ModelCapabilityProfile(label: AiChatLabel.claude);
  for (final r in replies) {
    p = p.record(r);
  }
  return p;
}

void main() {
  group('ModelCapabilityProfile', () {
    test('unknown starts compact with no rates and no mode suggestion', () {
      const p = ModelCapabilityProfile(label: AiChatLabel.notSure);
      expect(p.suggestedTier, ModelSizeTier.compact);
      expect(p.jsonReliability, isNull);
      expect(p.truncationRate, isNull);
      expect(p.suggestedMode, isNull);
      expect(p.explanation, contains('Not enough replies'));
    });

    test('two clean replies are not enough to move up', () {
      expect(after([reply(), reply()]).suggestedTier, ModelSizeTier.compact);
    });

    test('three clean compact replies suggest standard', () {
      final p = after([reply(), reply(), reply()]);
      expect(p.jsonReliability, 1);
      expect(p.largestCleanBatch, 3);
      expect(p.suggestedTier, ModelSizeTier.standard);
    });

    test('large needs six replies and a clean standard-size batch', () {
      final small = after(List.filled(8, reply()));
      expect(small.suggestedTier, ModelSizeTier.standard);
      final big = after([...List.filled(5, reply()), reply(requested: 8)]);
      expect(big.suggestedTier, ModelSizeTier.large);
    });

    test('frequent cut-offs fall back to compact', () {
      final p = after([
        ...List.filled(5, reply(requested: 8)),
        reply(requested: 8, filled: 5, end: false),
        reply(requested: 8, filled: 5, end: false),
      ]);
      expect(p.truncationRate, closeTo(2 / 7, 1e-9));
      expect(p.suggestedTier, ModelSizeTier.compact);
    });

    test('a reply is clean only if it filled everything asked, tidily', () {
      expect(reply().clean, isTrue);
      expect(reply(filled: 2).clean, isFalse);
      expect(reply(problems: 1).clean, isFalse);
      expect(reply(end: false).clean, isFalse);
      expect(reply(unreadable: true, filled: 0).clean, isFalse);
      expect(reply(requested: 0).clean, isFalse);
    });

    test('suggests the mode that clearly worked better', () {
      final p = after([
        ...List.filled(3, reply(unreadable: true, filled: 0)),
        ...List.filled(3, reply(mode: ManualOutputMode.lines)),
      ]);
      expect(p.suggestedMode, ManualOutputMode.lines);
      expect(p.unreadable, 3);
      final even = after([
        ...List.filled(3, reply()),
        ...List.filled(3, reply(mode: ManualOutputMode.lines)),
      ]);
      expect(even.suggestedMode, isNull);
    });

    test('JSON round-trips; damaged or inflated saves are rejected', () {
      final p = after([reply(), reply(requested: 8), reply(end: false)]);
      final back = ModelCapabilityProfile.fromJson(
        jsonDecode(jsonEncode(p.toJson())),
      )!;
      expect(back.toJson(), p.toJson());

      Map<String, Object?> edited(String k, Object? v) => {...p.toJson(), k: v};
      expect(ModelCapabilityProfile.fromJson(edited('version', 2)), isNull);
      expect(ModelCapabilityProfile.fromJson(edited('label', 'x')), isNull);
      expect(ModelCapabilityProfile.fromJson(edited('missing_end', 9)), isNull);
      expect(
        ModelCapabilityProfile.fromJson(edited('largest_clean_batch', 99)),
        isNull,
      );
      // A tally claiming more clean replies than replies is not trusted.
      final forged = ModelCapabilityProfile.fromJson(
        edited('package', {'replies': 1, 'clean': 50}),
      );
      expect(forged, isNull);
    });
  });

  group('ModelCapabilityStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('saves, reloads, and keeps owners apart', () async {
      final store = ModelCapabilityStore();
      final p = after([reply(), reply(), reply()]);
      await store.save(
        'owner-1',
        CapabilityProfiles(
          selected: AiChatLabel.claude,
          profiles: {AiChatLabel.claude: p},
        ),
      );
      final back = await store.load('owner-1');
      expect(back.selected, AiChatLabel.claude);
      expect(back.profileFor(AiChatLabel.claude).replies, 3);
      expect((await store.load('owner-2')).profiles, isEmpty);
    });

    test('a save copied under another owner key is ignored', () async {
      SharedPreferences.setMockInitialValues({
        ModelCapabilityStore.keyFor('owner-2'): ModelCapabilityStore.encode(
          'owner-1',
          const CapabilityProfiles(selected: AiChatLabel.gemini),
        ),
      });
      final back = await ModelCapabilityStore().load('owner-2');
      expect(back.selected, isNull);
    });

    test('unreadable storage starts over; clear removes it', () async {
      SharedPreferences.setMockInitialValues({
        ModelCapabilityStore.keyFor('owner-1'): '{not json',
      });
      final store = ModelCapabilityStore();
      expect((await store.load('owner-1')).profiles, isEmpty);
      await store.save(
        'owner-1',
        const CapabilityProfiles(selected: AiChatLabel.copilot),
      );
      await store.clear('owner-1');
      expect((await store.load('owner-1')).selected, isNull);
    });

    test('one bad profile does not drop the others', () {
      final good = after([reply()]).toJson();
      final decoded = ModelCapabilityStore.decode({
        'owner': 'o',
        'profiles': [
          good,
          {'version': 1, 'label': 'gemini'},
        ],
      }, 'o');
      expect(decoded.profiles.keys, [AiChatLabel.claude]);
    });
  });
}

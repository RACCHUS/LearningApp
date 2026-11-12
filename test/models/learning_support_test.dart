import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_strategy.dart';
import 'package:learning_pwa/models/learning_support/content_need.dart';
import 'package:learning_pwa/models/learning_support/learning_support_kinds.dart';
import 'package:learning_pwa/models/learning_support/learning_support_origin.dart';
import 'package:learning_pwa/models/learning_support/return_anchor.dart';
import 'package:learning_pwa/models/learning_support/return_anchor_stack.dart';
import 'package:learning_pwa/models/learning_support/return_position_resolver.dart';
import 'package:learning_pwa/models/learning_support/support_identifiers.dart';

ReturnAnchor anchor({
  String session = 'rs-1',
  String context = 'ctx-1',
  String route = '/lesson/excel-101',
  String? assetVersionId = 'av-3',
  String? blockId = 'blk-7',
  String? itemId,
  String? intra = 'step:2',
  String? scroll,
  PersistedLearningStrategy strategy = PersistedLearningStrategy.fast,
}) => ReturnAnchor(
  learningContextId: context,
  rootType: ReturnAnchorRootType.lesson,
  rootId: 'excel-101',
  originRoute: route,
  activeLearningStrategy: strategy,
  originActivityStateRevision: 12,
  rescueSessionId: session,
  createdAt: DateTime.utc(2026, 11, 12, 9),
  targetVersionId: 'tv-1',
  lessonId: 'excel-101',
  assetVersionId: assetVersionId,
  blockId: blockId,
  assessmentItemId: itemId,
  intraBlockAnchor: intra,
  pageOrScrollAnchor: scroll,
);

Map<String, Object?> anchorJson([Map<String, Object?> overrides = const {}]) =>
    {...anchor().toJson(), ...overrides};

class FakeView implements ReturnTargetView {
  bool open = true;
  Set<String> blocks = {'av-3/blk-7'};
  Set<String> cursors = {'av-3/blk-7/step:2'};
  Map<String, MappedBlock> mapped = {};
  Set<String> routes = {'/lesson/excel-101'};

  @override
  bool canOpen(ReturnAnchor a) => open;
  @override
  bool hasBlock(String v, String b) => blocks.contains('$v/$b');
  @override
  bool isValidIntraBlockAnchor(String v, String b, String t) =>
      cursors.contains('$v/$b/$t');
  @override
  MappedBlock? mappedReplacement(String v, String b) => mapped['$v/$b'];
  @override
  bool routeAvailable(String r) => routes.contains(r);
  @override
  String goalFallbackRoute(ReturnAnchor a) => '/learn';
}

void main() {
  group('SupportIdentifiers', () {
    test('accepts opaque ids, tokens and in-app routes', () {
      expect(SupportIdentifiers.isId('9b2f-uuid_1:x.y'), isTrue);
      expect(SupportIdentifiers.isToken('step:3'), isTrue);
      expect(SupportIdentifiers.isRoute('/lesson/abc-1'), isTrue);
      expect(SupportIdentifiers.isRoute('/'), isTrue);
    });

    test('rejects text, URLs, queries and traversal', () {
      expect(SupportIdentifiers.isId('has space'), isFalse);
      expect(SupportIdentifiers.isId(''), isFalse);
      expect(SupportIdentifiers.isId('a' * 129), isFalse);
      expect(SupportIdentifiers.isToken('x' * 65), isFalse);
      for (final r in [
        'https://evil.test/x',
        '//evil.test',
        '/lesson?answer=B',
        '/lesson#frag',
        '/lesson/../admin',
        '/a//b',
        'lesson/1',
        '/lesson/ä',
      ]) {
        expect(SupportIdentifiers.isRoute(r), isFalse, reason: r);
      }
    });
  });

  group('ReturnAnchor', () {
    test('round-trips through JSON with the §10.5 field names', () {
      final json = jsonDecode(jsonEncode(anchor().toJson())) as Map;
      expect(json['return_anchor_version'], 1);
      expect(json['active_learning_strategy'], 'fast');
      expect(json['root_type'], 'lesson');
      expect(json['created_at'], '2026-11-12T09:00:00.000Z');
      final back = ReturnAnchor.decode(json);
      expect(back.isOk, isTrue);
      expect(jsonEncode(back.anchor!.toJson()), jsonEncode(json));
    });

    test('omits absent optional fields', () {
      final json = anchor(blockId: null, intra: null).toJson();
      expect(json.containsKey('block_id'), isFalse);
      expect(json.containsKey('intra_block_anchor'), isFalse);
    });

    test('drops unknown fields such as answer keys on decode', () {
      final r = ReturnAnchor.decode(
        anchorJson({'correct_answer': 2, 'chat': 'private text'}),
      );
      expect(r.isOk, isTrue);
      final out = r.anchor!.toJson();
      expect(out.containsKey('correct_answer'), isFalse);
      expect(out.containsKey('chat'), isFalse);
    });

    test('refuses a newer version instead of downgrading', () {
      final r = ReturnAnchor.decode(anchorJson({'return_anchor_version': 2}));
      expect(r.issue, ReturnAnchorIssue.unsupportedVersion);
    });

    test('reports missing and invalid fields', () {
      expect(
        ReturnAnchor.decode(anchorJson({'return_anchor_version': null})).issue,
        ReturnAnchorIssue.missingField,
      );
      expect(ReturnAnchor.decode('nope').issue, ReturnAnchorIssue.notAnObject);
      final cases = <String, Object?>{
        'return_anchor_version': '1',
        'root_type': 'planet',
        'origin_activity_state_revision': -1,
        'created_at': 'yesterday',
        'origin_route': '/lesson?x=1',
        'block_id': 7,
        'lesson_id': 'two words',
        'intra_block_anchor': 'the learner typed this',
      };
      cases.forEach((field, value) {
        final r = ReturnAnchor.decode(anchorJson({field: value}));
        expect(r.issue, ReturnAnchorIssue.invalidField, reason: field);
        expect(r.field, field, reason: field);
      });
      for (final f in ['learning_context_id', 'rescue_session_id']) {
        final m = anchorJson()..remove(f);
        final r = ReturnAnchor.decode(m);
        expect(r.issue, ReturnAnchorIssue.missingField);
        expect(r.field, f);
      }
    });

    test('an unknown strategy is invalid, never silently Standard', () {
      final r = ReturnAnchor.decode(
        anchorJson({'active_learning_strategy': 'overview'}),
      );
      expect(r.issue, ReturnAnchorIssue.invalidField);
      expect(r.field, 'active_learning_strategy');
    });

    test('constructor rejects unsafe values', () {
      expect(() => anchor(route: 'https://x.test'), throwsArgumentError);
      expect(() => anchor(session: 'a b'), throwsArgumentError);
    });

    test('stores created_at in UTC', () {
      final a = ReturnAnchor.decode(
        anchorJson({'created_at': '2026-11-12T04:00:00-05:00'}),
      );
      expect(a.anchor!.createdAt, DateTime.utc(2026, 11, 12, 9));
    });
  });

  group('ReturnAnchorStack', () {
    ReturnAnchorStack empty({int depth = 3}) =>
        ReturnAnchorStack.empty(ownerScope: 'user-a', maxDepth: depth);

    test('nests Excel → percentages → fractions and unwinds in order', () {
      var s = empty();
      s = s.push(anchor(session: 'r1'), conceptId: 'pct-change').stack!;
      s = s.push(anchor(session: 'r2'), conceptId: 'percent').stack!;
      s = s.push(anchor(session: 'r3'), conceptId: 'fractions').stack!;
      expect(s.depth, 3);
      expect(s.root!.rescueSessionId, 'r1');
      expect(s.top!.rescueSessionId, 'r3');
      s = s.pop();
      expect(s.top!.rescueSessionId, 'r2');
      expect(s.unwindToRoot().depth, 1);
      expect(s.unwindToRoot().pop().pop().isEmpty, isTrue);
    });

    test('stops at the depth limit', () {
      var s = empty(depth: 2);
      s = s.push(anchor(session: 'r1'), conceptId: 'a').stack!;
      s = s.push(anchor(session: 'r2'), conceptId: 'b').stack!;
      final r = s.push(anchor(session: 'r3'), conceptId: 'c');
      expect(r.rejection, AnchorPushRejection.depthLimit);
      expect(s.depth, 2, reason: 'original stack is unchanged');
    });

    test('detects a repeated concept as a cycle', () {
      final s = empty().push(anchor(session: 'r1'), conceptId: 'fractions');
      final r = s.stack!.push(anchor(session: 'r2'), conceptId: 'fractions');
      expect(r.rejection, AnchorPushRejection.cycle);
    });

    test('rejects other contexts and duplicate sessions', () {
      final s = empty().push(anchor(session: 'r1')).stack!;
      expect(
        s.push(anchor(session: 'r2', context: 'ctx-2')).rejection,
        AnchorPushRejection.contextMismatch,
      );
      expect(
        s.push(anchor(session: 'r1')).rejection,
        AnchorPushRejection.duplicateSession,
      );
    });

    test('rejects invalid configuration', () {
      expect(
        () => ReturnAnchorStack.empty(ownerScope: 'u', maxDepth: 0),
        throwsArgumentError,
      );
      expect(
        () => ReturnAnchorStack.empty(ownerScope: 'u', maxDepth: 9),
        throwsArgumentError,
      );
      expect(
        () => ReturnAnchorStack.empty(ownerScope: 'not ok'),
        throwsArgumentError,
      );
    });

    group('decode', () {
      Map<String, Object?> stored() {
        var s = empty();
        s = s.push(anchor(session: 'r1'), conceptId: 'a').stack!;
        s = s.push(anchor(session: 'r2')).stack!;
        return jsonDecode(jsonEncode(s.toJson())) as Map<String, Object?>;
      }

      test('round-trips for the same owner', () {
        final r = ReturnAnchorStack.decode(
          stored(),
          expectedOwnerScope: 'user-a',
        );
        expect(r.isOk, isTrue);
        expect(r.stack!.depth, 2);
        expect(r.stack!.entries.first.conceptId, 'a');
        expect(r.stack!.entries.last.conceptId, isNull);
      });

      test('never restores another account\'s stack', () {
        final r = ReturnAnchorStack.decode(
          stored(),
          expectedOwnerScope: 'user-b',
        );
        expect(r.issue, AnchorStackDecodeIssue.otherOwner);
      });

      test('refuses future versions and oversize or cyclic data', () {
        expect(
          ReturnAnchorStack.decode({
            ...stored(),
            'anchor_stack_version': 2,
          }, expectedOwnerScope: 'user-a').issue,
          AnchorStackDecodeIssue.unsupportedVersion,
        );
        expect(
          ReturnAnchorStack.decode({
            ...stored(),
            'max_depth': 1,
          }, expectedOwnerScope: 'user-a').issue,
          AnchorStackDecodeIssue.tooManyEntries,
        );
        expect(
          ReturnAnchorStack.decode({
            ...stored(),
            'max_depth': 99,
          }, expectedOwnerScope: 'user-a').issue,
          AnchorStackDecodeIssue.invalidField,
        );
        final cyclic = stored();
        final entries = (cyclic['entries']! as List).cast<Map>();
        cyclic['entries'] = [
          entries[0],
          {...entries[1], 'concept_id': 'a'},
        ];
        final r = ReturnAnchorStack.decode(
          cyclic,
          expectedOwnerScope: 'user-a',
        );
        expect(r.issue, AnchorStackDecodeIssue.invalidAnchor);
        expect(r.index, 1);
      });

      test('reports which entry holds a bad anchor', () {
        final bad = stored();
        final entries = (bad['entries']! as List).cast<Map>();
        bad['entries'] = [
          entries[0],
          {
            'anchor': {...entries[1]['anchor'] as Map, 'origin_route': 'x'},
          },
        ];
        final r = ReturnAnchorStack.decode(bad, expectedOwnerScope: 'user-a');
        expect(r.issue, AnchorStackDecodeIssue.invalidAnchor);
        expect(r.index, 1);
        expect(
          ReturnAnchorStack.decode(42, expectedOwnerScope: 'user-a').issue,
          AnchorStackDecodeIssue.notAnObject,
        );
      });
    });
  });

  group('ReturnPositionResolver', () {
    late FakeView view;
    setUp(() => view = FakeView());

    test('1: exact version, block and cursor', () {
      final r = ReturnPositionResolver.resolve(anchor(), view);
      expect(r.precision, ReturnPrecision.exactPosition);
      expect(r.blockId, 'blk-7');
      expect(r.intraBlockAnchor, 'step:2');
      expect(r.needsExplanation, isFalse);
    });

    test('2: block exists but cursor is gone → start of block', () {
      view.cursors.clear();
      final r = ReturnPositionResolver.resolve(anchor(), view);
      expect(r.precision, ReturnPrecision.blockStart);
      expect(r.intraBlockAnchor, isNull);
      expect(r.needsExplanation, isFalse);
    });

    test('uses the assessment item id when there is no block id', () {
      view.blocks = {'av-3/item-4'};
      final r = ReturnPositionResolver.resolve(
        anchor(blockId: null, itemId: 'item-4', intra: null),
        view,
      );
      expect(r.precision, ReturnPrecision.blockStart);
      expect(r.blockId, 'item-4');
    });

    test('3: mapped block in an approved replacement version', () {
      view.blocks.clear();
      view.mapped['av-3/blk-7'] = const MappedBlock(
        assetVersionId: 'av-4',
        blockId: 'blk-9',
        route: '/lesson/excel-101-v4',
      );
      view.routes.add('/lesson/excel-101-v4');
      final r = ReturnPositionResolver.resolve(anchor(), view);
      expect(r.precision, ReturnPrecision.mappedReplacement);
      expect(r.assetVersionId, 'av-4');
      expect(r.route, '/lesson/excel-101-v4');
      expect(r.needsExplanation, isTrue);
    });

    test('4/5: route only, with or without a scroll hint', () {
      view.blocks.clear();
      expect(
        ReturnPositionResolver.resolve(anchor(), view).precision,
        ReturnPrecision.section,
      );
      final r = ReturnPositionResolver.resolve(anchor(scroll: 'p:40'), view);
      expect(r.precision, ReturnPrecision.approximateScroll);
      expect(r.scrollHint, 'p:40');
      expect(r.needsExplanation, isTrue, reason: 'never a false exact resume');
    });

    test('6: goal fallback when nothing can be opened', () {
      view.blocks.clear();
      view.routes.clear();
      final r = ReturnPositionResolver.resolve(anchor(), view);
      expect(r.precision, ReturnPrecision.goalFallback);
      expect(r.route, '/learn');
    });

    test('revoked permission goes straight to the goal fallback', () {
      view.open = false;
      final r = ReturnPositionResolver.resolve(anchor(), view);
      expect(r.precision, ReturnPrecision.goalFallback);
      expect(r.blockId, isNull);
    });

    test('a mapped block whose route is gone is not used', () {
      view.blocks.clear();
      view.mapped['av-3/blk-7'] = const MappedBlock(
        assetVersionId: 'av-4',
        blockId: 'blk-9',
        route: '/lesson/gone',
      );
      expect(
        ReturnPositionResolver.resolve(anchor(), view).precision,
        ReturnPrecision.section,
      );
    });

    test('never changes the learning strategy', () {
      view.open = false;
      for (final s in PersistedLearningStrategy.values) {
        expect(
          ReturnPositionResolver.resolve(anchor(strategy: s), view).strategy,
          s,
        );
      }
    });
  });

  group('LearningSupportOrigin', () {
    test('fromAnchor copies identifiers and the anchor id', () {
      final a = anchor(itemId: 'item-4');
      final o = LearningSupportOrigin.fromAnchor(a, conceptId: 'percent');
      expect(o.returnAnchorId, a.rescueSessionId);
      expect(o.learningContextId, 'ctx-1');
      expect(o.lessonId, 'excel-101');
      expect(o.blockId, 'blk-7');
      expect(o.itemId, 'item-4');
      expect(o.conceptId, 'percent');
    });

    test('rejects content in identifier fields', () {
      expect(
        () => LearningSupportOrigin(
          learningContextId: 'ctx',
          returnAnchorId: 'rs',
          itemId: 'What is 2+2? Answer: 4',
        ),
        throwsArgumentError,
      );
    });
  });

  group('ContentNeed', () {
    ContentNeed need({
      List<String> kinds = const ['explanation', 'mcq', 'explanation'],
      NeedEvidenceClass evidence = NeedEvidenceClass.tentative,
      String privacy = 'private',
    }) => ContentNeed(
      needId: 'n-1',
      objectiveId: 'obj-1',
      missingAssetKinds: kinds,
      reason: GapKind.missingPrerequisite,
      evidenceClass: evidence,
      privacyClass: privacy,
    );

    test('deduplicates asset kinds in order and is unmodifiable', () {
      final n = need();
      expect(n.missingAssetKinds, ['explanation', 'mcq']);
      expect(() => n.missingAssetKinds.add('x'), throwsUnsupportedError);
      expect(n.isTentative, isTrue);
      expect(
        need(evidence: NeedEvidenceClass.userRequest).isTentative,
        isFalse,
      );
    });

    test('requires at least one kind and safe values', () {
      expect(() => need(kinds: const []), throwsArgumentError);
      expect(() => need(kinds: const ['two words']), throwsArgumentError);
      expect(() => need(privacy: ''), throwsArgumentError);
    });
  });

  group('kinds', () {
    test('wire values are unique and round-trip', () {
      void check<T extends Enum>(
        List<T> values,
        String Function(T) wire,
        T? Function(Object?) from,
      ) {
        expect(values.map(wire).toSet().length, values.length);
        for (final v in values) {
          expect(from(wire(v)), v);
        }
        expect(from('nope'), isNull);
        expect(from(null), isNull);
      }

      check(
        ContentSourceKind.values,
        (e) => e.wire,
        ContentSourceKind.fromWire,
      );
      check(GapKind.values, (e) => e.wire, GapKind.fromWire);
      check(SupportKind.values, (e) => e.wire, SupportKind.fromWire);
      check(
        GenerationExecutionKind.values,
        (e) => e.wire,
        GenerationExecutionKind.fromWire,
      );
      check(
        NeedEvidenceClass.values,
        (e) => e.wire,
        NeedEvidenceClass.fromWire,
      );
    });

    test('only provider-calling routes are flagged as automatic', () {
      expect(
        GenerationExecutionKind.values
            .where((k) => k.callsProviderAutomatically)
            .toSet(),
        {
          GenerationExecutionKind.userAuthorizedPlan,
          GenerationExecutionKind.userApi,
          GenerationExecutionKind.managedAi,
        },
      );
    });
  });
}

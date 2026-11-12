import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_support/external_companion.dart';
import 'package:learning_pwa/services/learning_support/bridge_library.dart';
import 'package:learning_pwa/services/learning_support/external_companion_library.dart';

Map<String, Object?> load(String name) =>
    jsonDecode(File('content/companions/$name').readAsStringSync())
        as Map<String, Object?>;

Map<String, Object?> copy(Map<String, Object?> m) =>
    jsonDecode(jsonEncode(m)) as Map<String, Object?>;

String issues(Map<String, Object?> j) =>
    ExternalCompanion.decode(j).issues.join('\n');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BridgeLibrary bridges;

  setUpAll(() async => bridges = await BridgeLibrary.load(rootBundle));

  test('every bundled companion loads and matches its Bridge', () async {
    final lib = await ExternalCompanionLibrary.load(rootBundle, bridges);
    expect(lib.length, ExternalCompanionLibrary.assetPaths.length);
    for (final b in bridges.bridges) {
      final c = lib.forBridge(b.bridgeId)!;
      expect(c.objectiveId, b.objectiveId);
      expect(c.validateAgainst(b), isEmpty);
      expect(c.humanReviewed, isFalse);
      expect(c.checks.length, greaterThanOrEqualTo(2));
      expect(Uri.parse(c.resource.url).scheme, 'https');
    }
  });

  test('every file on disk is listed as a bundled asset', () {
    final onDisk = Directory('content/companions')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.companion.json'))
        .map((f) => 'content/companions/${f.uri.pathSegments.last}')
        .toSet();
    expect(onDisk, ExternalCompanionLibrary.assetPaths.toSet());
  });

  group('rejects', () {
    final base = load('percent_change.companion.json');

    test('anything but link-only rights, and non-https links', () {
      final r = copy(base);
      (r['resource']! as Map)['rights_posture'] = 'may_adapt';
      expect(issues(r), contains('link-only'));
      final u = copy(base);
      (u['resource']! as Map)['url'] = 'http://example.test';
      expect(issues(u), contains('https'));
    });

    test('AI dependence and unnamed reviews', () {
      expect(issues(copy(base)..['uses_ai'] = true), contains('without AI'));
      final r = copy(base);
      (r['evidence']! as Map)['human_reviewed'] = true;
      expect(issues(r), contains('name who reviewed'));
    });

    test('wrong answers, through the shared Bridge check rules', () {
      final j = copy(base);
      ((j['checks']! as List)[0] as Map)['answer'] = 25;
      expect(issues(j), contains('template gives -25'));
    });

    test('a different objective or reused Bridge numbers', () {
      final bridge = bridges['bridge-percent-change']!;
      final obj = copy(base)..['objective_id'] = 'other.objective';
      expect(
        ExternalCompanion.decode(obj).companion!.validateAgainst(bridge).join(),
        contains('objective_id'),
      );
      final reused = copy(base);
      ((reused['checks']! as List)[0] as Map)
        ..['inputs'] = {'original': 20, 'new': 23}
        ..['answer'] = 15;
      expect(
        ExternalCompanion.decode(
          reused,
        ).companion!.validateAgainst(bridge).join(),
        contains('already shows'),
      );
    });
  });
}

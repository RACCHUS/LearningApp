import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import '../../tool/ingest_curriculum.dart';

/// Ingestion plan D-14 (option B): only approved held-out items are sent.
void main() {
  Map<String, dynamic> load() {
    dynamic toDart(dynamic n) => n is YamlMap
        ? n.map((k, v) => MapEntry(k.toString(), toDart(v)))
        : n is YamlList
            ? n.map(toDart).toList()
            : n;
    final raw = File('content/held_out/open_openstax_college_algebra_1e_ch1.yaml').readAsStringSync();
    return (toDart(loadYaml(raw)) as Map).cast<String, dynamic>();
  }

  const slug = 'open-openstax-college-algebra-1e';

  test('unreviewed items are never sent', () {
    final payload = buildHeldOutPayload(load(), targetSlug: slug);
    expect(payload.items, isEmpty);
    expect(payload.skipped, 36);
  });

  test('an approved item is sent with its concepts and the file author', () {
    final file = load();
    final items = (file['items'] as List).cast<Map<String, dynamic>>();
    items.first['review'] = {
      'reviewer_ref': 'ai-review:claude-sonnet-5-5',
      'reviewer_kind': 'ai',
      'reviewer_model': 'claude-sonnet-5-5',
      'reviewer_qualification': 'AI review checklist v1 + independent SymPy check',
      'reviewed_on': '2026-11-20',
      'review_status': 'approved',
      'rights_review_status': 'approved',
    };
    items[1]['review'] = {'review_status': 'pending'};
    final payload = buildHeldOutPayload(file, targetSlug: slug);
    expect(payload.items, hasLength(1));
    expect(payload.skipped, 35);
    final sent = payload.items.single;
    expect(sent['key'], 'ca1e-ho-1-1-a');
    expect(sent['concept_slugs'], ['open-openstax-college-algebra-1e-1-1']);
    expect((sent['review'] as Map)['author_ref'], 'ai-drafted-by-claude');
    expect((sent['review'] as Map)['ai_drafted'], isTrue);
    expect((sent['review'] as Map)['reviewer_kind'], 'ai');
    expect((sent['review'] as Map)['reviewer_model'], 'claude-sonnet-5-5');
    expect(sent.containsKey('verify'), isFalse, reason: 'the sympy block stays in the repository');
  });

  test('a file for another target is refused', () {
    expect(() => buildHeldOutPayload(load(), targetSlug: 'software-excel-fundamentals'),
        throwsA(isA<Exception>()));
  });
}

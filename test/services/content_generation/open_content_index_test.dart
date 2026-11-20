import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/content_generation/content_resolution_decision.dart';
import 'package:learning_pwa/services/content_generation/open_content_index.dart';
import 'package:learning_pwa/services/content_generation/reuse_gate.dart';

void main() {
  final sources = OpenContentIndex.parse(
    jsonDecode(File('assets/open_content/index.json').readAsStringSync()),
  );

  ReuseGateResult ask(String subject, List<String> ideas) =>
      ReuseGate.evaluate(subject: subject, ideas: ideas, sources: sources);

  test('the bundled index loads every section with a link and credit', () {
    expect(sources.length, greaterThan(150));
    for (final s in sources) {
      expect(s.kind, ReuseSourceKind.openSection);
      expect(s.url, startsWith('https://openstax.org/books/'));
      expect(s.credit, contains('CC BY 4.0'));
    }
  });

  test('an algebra request finds the matching College Algebra section', () {
    final r = ask('College Algebra', ['Scientific notation']);
    expect(r.decision.kind, ContentResolutionKind.externalLink);
    expect(r.candidates.first.source.title, contains('Exponents and Scientific'));
    expect(r.decision.eligibleAssetRef, startsWith('open:https://openstax.org'));
  });

  test('a percent request finds Prealgebra percent sections', () {
    final r = ask('Percentages', ['Understand percent']);
    expect(r.suggestsReuse, isTrue);
    expect(
      r.candidates.map((c) => c.source.title).join(' | '),
      contains('Percent'),
    );
  });

  test('a psychology request finds the psychology section', () {
    final r = ask('Psychology', ['Classical conditioning']);
    expect(r.decision.kind, ContentResolutionKind.externalLink);
    expect(r.candidates.first.source.credit, contains('Psychology'));
  });

  test('topics outside the open books still go to generation', () {
    final r = ask('Excel', ['Pivot tables', 'VLOOKUP formulas']);
    expect(r.decision.kind, ContentResolutionKind.generate);
    expect(r.candidates, isEmpty);
  });

  test('our own lesson outranks an open section that covers the same', () {
    final r = ReuseGate.evaluate(
      subject: 'College Algebra',
      ideas: ['Scientific notation'],
      sources: [
        ...sources,
        const ReuseSource(
          kind: ReuseSourceKind.lesson,
          id: 'l1',
          title: 'Scientific notation basics',
        ),
      ],
    );
    expect(r.decision.kind, ContentResolutionKind.exactReuse);
    expect(r.candidates.first.source.id, 'l1');
  });

  test('malformed entries are skipped', () {
    final parsed = OpenContentIndex.parse({
      'sections': [
        {'title': 'No link', 'url': 'http://insecure'},
        {'url': 'https://openstax.org/books/x/pages/y'},
        'not a map',
      ],
    });
    expect(parsed, isEmpty);
    expect(OpenContentIndex.parse(null), isEmpty);
  });
}

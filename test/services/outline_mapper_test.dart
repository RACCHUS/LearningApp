import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/companion/learner_resource.dart';
import 'package:learning_pwa/services/companion/outline_mapper.dart';

const outline = ResourceOutline([
  ResourceOutlineGroup(
    title: 'Algebraic operations',
    items: [
      ResourceOutlineItem(
        key: '1.1',
        code: '1.1',
        label: '1.1 Exponents and radicals',
      ),
      ResourceOutlineItem(
        key: '1.2',
        code: '1.2',
        label: '1.2 Factoring polynomials',
      ),
    ],
  ),
  ResourceOutlineGroup(
    title: 'Functions',
    items: [
      ResourceOutlineItem(
        key: '2.1',
        code: '2.1',
        label: '2.1 Domain and range',
      ),
      ResourceOutlineItem(
        key: '2.2',
        code: '2.2',
        label: '2.2 Graphs of linear equations',
      ),
      ResourceOutlineItem(key: 'Logarithms', label: 'Logarithms'),
    ],
  ),
]);

void main() {
  group('parse', () {
    test('one part per line, without bullets, timestamps or page numbers', () {
      final parsed = OutlineMapper.parse(
        '  - Chapter 1: Exponents ........ 12\n'
        '\n'
        '• Chapter 2: Factoring\t45\n'
        '0:00 Welcome\n'
        '1:02:33 - Domain and range\n'
        'Graphs (12:30)\n'
        '12\n'
        '---\n'
        'chapter 2: factoring\n',
      );
      expect(parsed.titles, [
        'Chapter 1: Exponents',
        'Chapter 2: Factoring',
        'Welcome',
        'Domain and range',
        'Graphs',
      ]);
      expect(parsed.truncated, isFalse);
    });

    test('a ratio in a title is not mistaken for a timestamp', () {
      expect(OutlineMapper.parse('Mixing at 3:2').titles, ['Mixing at 3:2']);
    });

    test('long input is capped and says so', () {
      final many = OutlineMapper.parse(
        [for (var i = 0; i < 300; i++) 'Part $i about topic'].join('\n'),
      );
      expect(many.titles.length, ResourceSection.maxSections);
      expect(many.truncated, isTrue);
      final longLine = OutlineMapper.parse('x' * 500);
      expect(longLine.titles.single.length, ResourceSection.maxTitleLength);
      expect(OutlineMapper.parse('a b\n' * 10000).truncated, isTrue);
    });
  });

  group('propose', () {
    List<Set<String>> propose(List<String> titles) =>
        OutlineMapper.propose(titles, outline);

    test('a title that names an objective proposes that objective', () {
      expect(propose(['Chapter 3: Factoring polynomials']), [
        {'1.2'},
      ]);
      expect(propose(['Logarithms']).single, {'Logarithms'});
    });

    test('a title that names an area proposes every objective of the area', () {
      expect(propose(['Unit 2 - Functions']).single, {
        '2.1',
        '2.2',
        'Logarithms',
      });
    });

    test('part words and numbers alone match nothing', () {
      expect(
        propose(['Chapter 12', 'Week 2 review', 'Final exam practice test']),
        [<String>{}, <String>{}, <String>{}],
      );
    });

    test('an unrelated title matches nothing', () {
      expect(propose(['Photosynthesis in plants']).single, isEmpty);
    });

    test('a broad word proposes at most the cap of single objectives', () {
      final wide = ResourceOutline([
        ResourceOutlineGroup(
          title: 'Area',
          items: [
            for (var i = 0; i < 20; i++)
              ResourceOutlineItem(key: 'k$i', label: 'Equations type $i'),
          ],
        ),
      ]);
      expect(
        OutlineMapper.propose(['Equations'], wide).single.length,
        OutlineMapper.maxProposalsPerSection,
      );
    });
  });

  group('own AI round trip', () {
    final prompt = OutlineMapper.buildPrompt(
      resourceTitle: 'My course',
      sectionTitles: ['Unit 1', 'Unit 2'],
      outline: outline,
    );

    test(
      'the prompt lists numbered objectives and parts and forbids copying',
      () {
        expect(prompt, contains('O1: 1.1 Exponents and radicals'));
        expect(prompt, contains('O5: Logarithms'));
        expect(prompt, contains('2: Unit 2'));
        expect(prompt, contains(OutlineMapper.format));
        expect(
          prompt,
          contains('Do not quote or reproduce any content from the resource.'),
        );
        expect(prompt, isNot(contains('http')));
      },
    );

    AiMapResult parse(String s) =>
        OutlineMapper.parseResponse(s, sectionCount: 2, outline: outline);

    test(
      'a well-formed answer maps ids back to objective keys, even inside a code fence',
      () {
        final r = parse(
          'Here you go:\n```json\n'
          '{"format":"la-resource-map/1","sections":[{"n":1,"objectives":["O1","O5"]},{"n":2,"objectives":[]}]}\n```',
        );
        expect(r.error, isNull);
        expect(r.bySection, {
          0: {'1.1', 'Logarithms'},
          1: <String>{},
        });
        expect(r.dropped, 0);
      },
    );

    test(
      'unknown parts and objectives are dropped and counted, never invented',
      () {
        final r = parse(
          jsonEncode({
            'format': 'la-resource-map/1',
            'sections': [
              {
                'n': 1,
                'objectives': ['O2', 'O99', '1.1', 7, '<b>O1</b>'],
              },
              {
                'n': 3,
                'objectives': ['O1'],
              },
              'junk',
            ],
          }),
        );
        expect(r.bySection, {
          0: {'1.2'},
        });
        expect(r.dropped, 6);
      },
    );

    test('anything else is refused with a plain message', () {
      expect(parse('').error, 'Paste the answer first.');
      expect(parse('I think unit 1 covers exponents.').error, isNotNull);
      expect(parse('{"format":"other","sections":[]}').error, isNotNull);
      expect(
        parse(
          '{"format":"la-resource-map/1","sections":[{"n":9,"objectives":["O1"]}]}',
        ).error,
        isNotNull,
      );
      expect(parse('{not json}').error, isNotNull);
      expect(parse('{${'x' * 70000}}').error, 'That answer is too long.');
    });
  });
}

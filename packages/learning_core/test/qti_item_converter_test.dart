import 'package:learning_core/learning_core.dart';
import 'package:test/test.dart';

void main() {
  group('QtiItemConverter (1EdTech QTI 3.0)', () {
    const sampleItem = AssessmentItemCore(
      id: 'item-us-civics-001',
      stem: 'What is the supreme law of the land in the United States?',
      options: [
        AssessmentOptionCore(text: 'The Declaration of Independence', isCorrect: false),
        AssessmentOptionCore(text: 'The Constitution', isCorrect: true, rationale: 'The Constitution is the supreme law.'),
        AssessmentOptionCore(text: 'The Federalist Papers', isCorrect: false),
        AssessmentOptionCore(text: 'The Emancipation Proclamation', isCorrect: false),
      ],
      explanation: 'The US Constitution establishes the foundational framework of national government and is the supreme law of the land.',
      conceptSlug: 'us-constitution-supremacy',
      sourceRef: 'USCIS Civics 100 Q1',
    );

    test('exports AssessmentItemCore to compliant 1EdTech QTI 3.0 XML', () {
      final xml = QtiItemConverter.exportItem(sampleItem, title: 'Civics Question 1');

      expect(xml, contains('<qti-assessment-item'));
      expect(xml, contains('identifier="item-us-civics-001"'));
      expect(xml, contains('xmlns="http://www.imsglobal.org/xsd/imsqtiasi_v3p0"'));
      expect(xml, contains('<qti-correct-response>'));
      expect(xml, contains('<qti-value>Choice_2</qti-value>'));
      expect(xml, contains('What is the supreme law of the land in the United States?'));
      expect(xml, contains('<qti-simple-choice identifier="Choice_2">The Constitution</qti-simple-choice>'));
      expect(xml, contains('<qti-modal-feedback identifier="FEEDBACK"'));
      expect(xml, contains('The US Constitution establishes the foundational framework'));
    });

    test('imports QTI 3.0 XML into AssessmentItemCore with full fidelity', () {
      final xml = QtiItemConverter.exportItem(sampleItem);
      final imported = QtiItemConverter.importItem(xml);

      expect(imported.id, equals('item-us-civics-001'));
      expect(imported.stem, equals(sampleItem.stem));
      expect(imported.options.length, equals(4));

      // Assert correctness mapping
      expect(imported.options[0].text, equals('The Declaration of Independence'));
      expect(imported.options[0].isCorrect, isFalse);

      expect(imported.options[1].text, equals('The Constitution'));
      expect(imported.options[1].isCorrect, isTrue);

      expect(imported.options[2].isCorrect, isFalse);
      expect(imported.options[3].isCorrect, isFalse);

      expect(imported.explanation, contains('The US Constitution establishes the foundational framework'));
    });

    test('handles QTI items without optional modal feedback or explanations', () {
      const minimalItem = AssessmentItemCore(
        id: 'item-minimal-42',
        stem: 'What is 2 + 2?',
        options: [
          AssessmentOptionCore(text: '3', isCorrect: false),
          AssessmentOptionCore(text: '4', isCorrect: true),
        ],
      );

      final xml = QtiItemConverter.exportItem(minimalItem);
      expect(xml, isNot(contains('<qti-modal-feedback')));

      final imported = QtiItemConverter.importItem(xml);
      expect(imported.id, equals('item-minimal-42'));
      expect(imported.stem, equals('What is 2 + 2?'));
      expect(imported.options.length, equals(2));
      expect(imported.options[1].isCorrect, isTrue);
      expect(imported.explanation, isNull);
    });
  });
}


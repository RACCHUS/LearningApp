import 'package:xml/xml.dart';
import '../models/assessment_item.dart';

/// Importer and Exporter conforming to 1EdTech (IMS Global) Question and Test
/// Interoperability (QTI) 3.0 specification.
class QtiItemConverter {
  static const String qtiNamespace =
      'http://www.imsglobal.org/xsd/imsqtiasi_v3p0';
  static const String xsiNamespace =
      'http://www.w3.org/2001/XMLSchema-instance';

  /// Serializes an [AssessmentItemCore] into a standard 1EdTech QTI 3.0 XML string.
  static String exportItem(
    AssessmentItemCore item, {
    String title = 'Assessment Item',
  }) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');

    builder.element('qti-assessment-item', attributes: {
      'xmlns': qtiNamespace,
      'xmlns:xsi': xsiNamespace,
      'xsi:schemaLocation':
          '$qtiNamespace https://purl.imsglobal.org/spec/qti/v3p0/schema/xsd/imsqti_asiv3p0_v1p0.xsd',
      'identifier': item.id,
      'title': title,
      'adaptive': 'false',
      'time-dependent': 'false',
    }, nest: () {
      // Find correct option index
      final correctIndex = item.options.indexWhere((o) => o.isCorrect);
      final correctIdentifier =
          correctIndex >= 0 ? 'Choice_${correctIndex + 1}' : 'Choice_1';

      // 1. Response Declaration
      builder.element('qti-response-declaration', attributes: {
        'identifier': 'RESPONSE',
        'cardinality': 'single',
        'base-type': 'identifier',
      }, nest: () {
        builder.element('qti-correct-response', nest: () {
          builder.element('qti-value', nest: () {
            builder.text(correctIdentifier);
          });
        });
      });

      // 2. Outcome Declaration (Score)
      builder.element('qti-outcome-declaration', attributes: {
        'identifier': 'SCORE',
        'cardinality': 'single',
        'base-type': 'float',
      }, nest: () {
        builder.element('qti-default-value', nest: () {
          builder.element('qti-value', nest: () {
            builder.text('0.0');
          });
        });
      });

      // 3. Item Body
      builder.element('qti-item-body', nest: () {
        builder.element('div', attributes: {'class': 'qti-stem'}, nest: () {
          builder.text(item.stem);
        });

        builder.element('qti-choice-interaction', attributes: {
          'response-identifier': 'RESPONSE',
          'shuffle': 'true',
          'max-choices': '1',
        }, nest: () {
          for (var i = 0; i < item.options.length; i++) {
            final option = item.options[i];
            final choiceId = 'Choice_${i + 1}';
            builder.element('qti-simple-choice', attributes: {
              'identifier': choiceId,
            }, nest: () {
              builder.text(option.text);
            });
          }
        });
      });

      // 4. Response Processing Template (match_correct)
      builder.element('qti-response-processing', attributes: {
        'template':
            'https://purl.imsglobal.org/spec/qti/v3p0/rptemplates/match_correct.xml',
      });

      // 5. Modal Feedback (Rationale / Explanation)
      if (item.explanation != null && item.explanation!.isNotEmpty) {
        builder.element('qti-modal-feedback', attributes: {
          'identifier': 'FEEDBACK',
          'outcome-identifier': 'SCORE',
          'show-hide': 'show',
        }, nest: () {
          builder.text(item.explanation!);
        });
      }
    });

    final doc = builder.buildDocument();
    return doc.toXmlString(pretty: true, indent: '  ');
  }

  /// Deserializes a QTI 3.0 (or QTI 2.x) XML string into an [AssessmentItemCore].
  static AssessmentItemCore importItem(String xmlString) {
    final doc = XmlDocument.parse(xmlString);

    // Locate root assessment item (handling both with/without qti- prefix)
    final root = doc.findAllElements('qti-assessment-item').firstOrNull ??
        doc.findAllElements('assessmentItem').firstOrNull ??
        doc.rootElement;

    final id = root.getAttribute('identifier') ??
        root.getAttribute('id') ??
        'imported_item';

    // Locate correct response identifier
    String? correctChoiceId;
    final correctResponseElement = doc.findAllElements('qti-correct-response').firstOrNull ??
        doc.findAllElements('correctResponse').firstOrNull;
    if (correctResponseElement != null) {
      final valueElem = correctResponseElement.findAllElements('qti-value').firstOrNull ??
          correctResponseElement.findAllElements('value').firstOrNull;
      correctChoiceId = valueElem?.innerText.trim();
    }

    // Locate stem
    String stem = '';
    final stemDiv = doc.findAllElements('div')
        .where((e) => e.getAttribute('class') == 'qti-stem')
        .firstOrNull;
    if (stemDiv != null) {
      stem = stemDiv.innerText.trim();
    } else {
      // Fallback: extract text directly from item-body prior to interaction
      final itemBody = doc.findAllElements('qti-item-body').firstOrNull ??
          doc.findAllElements('itemBody').firstOrNull;
      if (itemBody != null) {
        final p = itemBody.findAllElements('p').firstOrNull;
        if (p != null) {
          stem = p.innerText.trim();
        } else {
          stem = itemBody.children
              .whereType<XmlText>()
              .map((t) => t.value.trim())
              .where((t) => t.isNotEmpty)
              .join(' ');
        }
      }
    }

    // Locate simple-choice options
    final choiceElements = [
      ...doc.findAllElements('qti-simple-choice'),
      ...doc.findAllElements('simpleChoice'),
    ];

    final options = <AssessmentOptionCore>[];
    for (final choice in choiceElements) {
      final choiceId = choice.getAttribute('identifier') ?? '';
      final text = choice.innerText.trim();
      final isCorrect =
          correctChoiceId != null && choiceId == correctChoiceId;

      options.add(AssessmentOptionCore(
        text: text,
        isCorrect: isCorrect,
      ));
    }

    // Locate explanation from modal feedback
    String? explanation;
    final feedback = doc.findAllElements('qti-modal-feedback').firstOrNull ??
        doc.findAllElements('modalFeedback').firstOrNull;
    if (feedback != null) {
      explanation = feedback.innerText.trim();
    }

    return AssessmentItemCore(
      id: id,
      stem: stem.isNotEmpty ? stem : 'Imported Question',
      options: options,
      explanation: explanation,
    );
  }
}


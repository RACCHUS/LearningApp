import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:learning_core/learning_core.dart';
import 'package:learning_pwa/models/assessment_item.dart';
import 'package:learning_pwa/models/learning_event.dart';
import 'package:learning_pwa/services/interop/open_standards_service.dart';

void main() {
  group('OpenStandardsService', () {
    final sampleAssessmentItem = AssessmentItem(
      id: 'asmt-item-001',
      interactionType: AssessmentInteractionType.singleChoice,
      prompt: 'What is the speed of light in vacuum?',
      responseSpec: const {
        'options': [
          {'id': 'opt_1', 'text': '300,000 km/s', 'is_correct': true, 'rationale': 'Exact definition is 299,792,458 m/s'},
          {'id': 'opt_2', 'text': '150,000 km/s', 'is_correct': false},
          {'id': 'opt_3', 'text': '3,000 km/s', 'is_correct': false},
        ],
      },
      scoringSpec: const {
        'correct_option_id': 'opt_1',
      },
      explanation: 'Light travels at approximately 300,000 km per second in a vacuum.',
      metadata: const {
        'source_ref': 'NIST Physical Constants',
      },
      createdAt: DateTime.parse('2026-11-06T00:00:00Z'),
      updatedAt: DateTime.parse('2026-11-06T00:00:00Z'),
    );

    final sampleLearningEvent = LearningEvent(
      id: 'evt-test-101',
      sessionId: 'sess-pilot-01',
      itemId: 'asmt-item-001',
      itemType: 'assessment_item',
      userId: 'learner-alice',
      eventType: 'review_completed',
      score: 1.0,
      latencyMs: 5400,
      occurredAt: DateTime.parse('2026-11-06T10:00:00Z'),
      metadata: const {
        'idempotency_key': 'idem-test-101',
        'client_seq': 3,
        'fsrs_stability': 3.8,
        'fsrs_difficulty': 4.1,
      },
    );

    test('exports AssessmentItem to 1EdTech QTI 3.0 XML and imports back with full parity', () {
      final service = OpenStandardsService();
      final xml = service.exportAssessmentItemToQti(sampleAssessmentItem);

      expect(xml, contains('<qti-assessment-item'));
      expect(xml, contains('identifier="asmt-item-001"'));
      expect(xml, contains('What is the speed of light in vacuum?'));
      expect(xml, contains('<qti-value>Choice_1</qti-value>'));

      final imported = service.importAssessmentItemFromQti(xml);
      expect(imported.id, equals('asmt-item-001'));
      expect(imported.stem, equals(sampleAssessmentItem.prompt));
      expect(imported.options.length, equals(3));
      expect(imported.options[0].isCorrect, isTrue);
      expect(imported.options[1].isCorrect, isFalse);
      expect(imported.explanation, contains('Light travels at approximately'));
    });

    test('generates valid xAPI 1.0.3 statement from LearningEvent', () {
      final service = OpenStandardsService();
      final statement = service.generateXApiStatement(sampleLearningEvent);

      expect(statement['id'], equals('evt-test-101'));
      expect(statement['actor']['account']['name'], equals('learner-alice'));
      expect(statement['verb']['id'], equals('http://adlnet.gov/expapi/verbs/answered'));
      expect(statement['object']['id'], contains('/activities/items/asmt-item-001'));
      expect(statement['result']['success'], isTrue);
      expect(statement['result']['duration'], equals('PT5S'));

      final extensions = statement['context']['extensions'] as Map<String, dynamic>;
      expect(extensions['https://learningapp.org/xapi/ext/session-id'], equals('sess-pilot-01'));
      expect(extensions['https://learningapp.org/xapi/ext/fsrs-stability'], equals(3.8));
    });

    test('emits xAPI statement to LRS successfully with Bearer authentication', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), equals('https://lrs.example.org/xapi/statements'));
        expect(request.headers['Authorization'], equals('Bearer secret-token'));
        expect(request.headers['X-Experience-API-Version'], equals('1.0.3'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['id'], equals('evt-test-101'));

        return http.Response(jsonEncode(['evt-test-101']), 200);
      });

      final service = OpenStandardsService(httpClient: mockClient);
      final statement = service.generateXApiStatement(sampleLearningEvent);

      final result = await service.emitStatementToLrs(
        statement: statement,
        lrsEndpoint: Uri.parse('https://lrs.example.org/xapi/statements'),
        bearerToken: 'secret-token',
      );

      expect(result.success, isTrue);
      expect(result.statusCode, equals(200));
      expect(result.statementIds, contains('evt-test-101'));
    });

    test('handles LRS rejection error cleanly', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Invalid statement schema', 400);
      });

      final service = OpenStandardsService(httpClient: mockClient);
      final statement = service.generateXApiStatement(sampleLearningEvent);

      final result = await service.emitStatementToLrs(
        statement: statement,
        lrsEndpoint: Uri.parse('https://lrs.example.org/xapi/statements'),
        bearerToken: 'invalid-token',
      );

      expect(result.success, isFalse);
      expect(result.statusCode, equals(400));
      expect(result.message, contains('LRS rejected statement'));
    });

    test('supports AssessmentItemCore direct roundtrip', () {
      final service = OpenStandardsService();
      const coreItem = AssessmentItemCore(
        id: 'direct-core-item',
        stem: 'Select the primary colors in additive color mixing.',
        options: [
          AssessmentOptionCore(text: 'Red, Green, Blue', isCorrect: true),
          AssessmentOptionCore(text: 'Red, Yellow, Blue', isCorrect: false),
        ],
        explanation: 'RGB is the additive model for digital displays.',
      );

      final xml = service.exportCoreItemToQti(coreItem);
      expect(xml, contains('<qti-value>Choice_1</qti-value>'));

      final imported = service.importAssessmentItemFromQti(xml);
      expect(imported.id, equals('direct-core-item'));
      expect(imported.stem, equals(coreItem.stem));
      expect(imported.options.first.isCorrect, isTrue);
    });
  });
}

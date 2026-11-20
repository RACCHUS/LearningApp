import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:learning_pwa/models/spaced_repetition.dart';
import 'package:learning_pwa/services/concept_evidence_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late List<Uri> requests;
  late ConceptEvidenceService service;

  setUp(() {
    requests = [];
    final client = SupabaseClient(
      'http://localhost:9',
      'anon-key',
      httpClient: MockClient((req) async {
        requests.add(req.url);
        return http.Response('[]', 200);
      }),
    );
    service = ConceptEvidenceService(supabase: client);
  });

  group('signed-out learners never reach the server', () {
    for (final id in ['local-user', '']) {
      test('id "$id"', () async {
        expect(await service.getUserConceptStates(id), isEmpty);
        await service.recordEvidence(
          userId: id,
          contentId: 'c1',
          contentType: ReviewableContentType.term,
          evidenceValue: 1,
        );
        expect(
          await service.recordAssessmentItemEvidence(
            userId: id,
            assessmentItemId: 'a1',
            evidenceValue: 1,
          ),
          isFalse,
        );
        expect(requests, isEmpty);
      });
    }
  });

  test('a signed-in learner still loads concept states', () async {
    await service.getUserConceptStates('7c9e6679-7425-40de-944b-e07fc1f90ae7');
    expect(requests, hasLength(1));
    expect(requests.single.path, '/rest/v1/user_concept_state');
  });
}

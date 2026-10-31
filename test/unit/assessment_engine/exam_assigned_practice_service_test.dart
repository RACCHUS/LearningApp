import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/assessment/exam_assigned_practice_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('ExamAssignedPracticeService & Envelope Parsing', () {
    const validOwnerId = 'd3180000-0000-4000-8000-000000000001';
    const validSessionId = 'd3210000-0000-4000-8000-000000000001';
    const validTargetVersionId = 'd3160000-0000-4000-8000-000000000001';
    const validPartKey = 'part_a';
    const validAdminDate = '2027-04-15';
    final validUser = User(
      id: validOwnerId,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-10-31T00:00:00Z',
      isAnonymous: false,
    );

    Map<String, dynamic> sampleValidPayload() => {
      'assignment_id': 'd3200000-0000-4000-8000-000000000001',
      'target_version_id': validTargetVersionId,
      'exam_part_key': validPartKey,
      'administration_date': validAdminDate,
      'expires_at': DateTime.now().add(const Duration(minutes: 90)).toIso8601String(),
      'practice_only': true,
      'question_count': 6,
      'questions': List.generate(6, (i) => {
        'id': 'd3150000-0000-4000-8000-00000000000$i',
        'interaction_type': 'single_choice',
        'prompt': 'Question $i prompt',
        'response_spec': {
          'options': ['Option A', 'Option B', 'Option C', 'Option D'],
        },
      }),
    };

    test('parse correctly extracts administrationDate and validated questions', () {
      final parsed = IssuedExamPractice.parse(
        sampleValidPayload(),
        expectedOwnerId: validOwnerId,
        expectedSessionId: validSessionId,
        expectedTargetVersionId: validTargetVersionId,
        expectedExamPartKey: validPartKey,
        expectedAdministrationDate: validAdminDate,
      );

      expect(parsed.assignmentId, 'd3200000-0000-4000-8000-000000000001');
      expect(parsed.administrationDate, validAdminDate);
      expect(parsed.questions.length, 6);
      expect(parsed.questions.first.prompt, 'Question 0 prompt');
      expect(parsed.questions.first.options.length, 4);
    });

    test('parse rejects payload missing administration_date', () {
      final payload = sampleValidPayload()..remove('administration_date');
      expect(
        () => IssuedExamPractice.parse(
          payload,
          expectedOwnerId: validOwnerId,
          expectedSessionId: validSessionId,
          expectedTargetVersionId: validTargetVersionId,
          expectedExamPartKey: validPartKey,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('parse rejects payload with mismatched administration_date', () {
      expect(
        () => IssuedExamPractice.parse(
          sampleValidPayload(),
          expectedOwnerId: validOwnerId,
          expectedSessionId: validSessionId,
          expectedTargetVersionId: validTargetVersionId,
          expectedExamPartKey: validPartKey,
          expectedAdministrationDate: '2026-06-01',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('issue passes administrationDate to RPC and returns parsed envelope', () async {
      String? capturedVersion;
      String? capturedPart;
      String? capturedDate;

      final service = ExamAssignedPracticeService(
        testCurrentUser: () => validUser,
        testSessionId: () => validSessionId,
        testIssue: (versionId, partKey, dateStr) async {
          capturedVersion = versionId;
          capturedPart = partKey;
          capturedDate = dateStr;
          return sampleValidPayload();
        },
      );

      // Construct a mock user simulation
      final issued = await service.issue(
        expectedOwnerId: validOwnerId,
        targetVersionId: validTargetVersionId,
        examPartKey: validPartKey,
        administrationDate: DateTime.utc(2027, 4, 15),
      );

      expect(capturedVersion, validTargetVersionId);
      expect(capturedPart, validPartKey);
      expect(capturedDate, '2027-04-15');
      expect(issued.administrationDate, '2027-04-15');
    });
  });
}


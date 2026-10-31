import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/screens/assessment/secure_exam_part_practice_screen.dart';
import 'package:learning_pwa/services/assessment/exam_assigned_practice_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

class _TestAuthController extends StateNotifier<AuthState> implements AuthNotifier {
  _TestAuthController(super.initial);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('SecureExamPartPracticeScreen', () {
    const testOwnerId = 'd3180000-0000-4000-8000-000000000001';
    const testSessionId = 'd3210000-0000-4000-8000-000000000001';
    const testTargetVersionId = 'd3160000-0000-4000-8000-000000000001';
    const testPartKey = 'part_a';
    final testUser = User(
      id: testOwnerId,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-10-31T00:00:00Z',
      isAnonymous: false,
    );

    Map<String, dynamic> sampleValidPayload(String adminDate) => {
      'assignment_id': 'd3200000-0000-4000-8000-000000000001',
      'target_version_id': testTargetVersionId,
      'exam_part_key': testPartKey,
      'administration_date': adminDate,
      'expires_at': DateTime.now().add(const Duration(minutes: 90)).toIso8601String(),
      'practice_only': true,
      'question_count': 6,
      'questions': List.generate(6, (i) => {
        'id': 'd3150000-0000-4000-8000-00000000000$i',
        'interaction_type': 'single_choice',
        'prompt': 'Question ${i + 1}: Select the controlling provision',
        'response_spec': {
          'options': ['Section 101.1', 'Section 102.2', 'Section 103.3', 'Section 104.4'],
        },
      }),
    };

    testWidgets('shows sign-in prompt when learner is anonymous or unauthenticated', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _TestAuthController(AuthInitial())),
          ],
          child: const MaterialApp(
            home: SecureExamPartPracticeScreen(
              targetVersionId: testTargetVersionId,
              examPartKey: testPartKey,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Sign in with a permanent account for reviewed exam-part practice.'),
        findsOneWidget,
      );
    });

    testWidgets('prompts for administration date when none is provided', (tester) async {
      final service = ExamAssignedPracticeService(
        testCurrentUser: () => testUser,
        testSessionId: () => testSessionId,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _TestAuthController(AuthSuccess(testUser))),
          ],
          child: MaterialApp(
            home: SecureExamPartPracticeScreen(
              targetVersionId: testTargetVersionId,
              examPartKey: testPartKey,
              service: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('secure-exm-part-date-button')), findsOneWidget);
      expect(
        find.text('An actual exam administration date is required to resolve approved reference materials for this part:'),
        findsOneWidget,
      );
    });

    testWidgets('loads and renders verified practice questions when administration date is provided', (tester) async {
      final service = ExamAssignedPracticeService(
        testCurrentUser: () => testUser,
        testSessionId: () => testSessionId,
        testIssue: (versionId, partKey, dateStr) async {
          return sampleValidPayload(dateStr);
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _TestAuthController(AuthSuccess(testUser))),
          ],
          child: MaterialApp(
            home: SecureExamPartPracticeScreen(
              targetVersionId: testTargetVersionId,
              examPartKey: testPartKey,
              administrationDate: DateTime.utc(2027, 4, 15),
              service: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('secure-exm-part-admin-date')), findsOneWidget);
      expect(find.text('Administration date: 2027-04-15'), findsOneWidget);
      expect(find.byKey(const Key('secure-exm-part-count')), findsOneWidget);
      expect(find.text('Question 1 of 6'), findsOneWidget);
      expect(find.text('Question 1: Select the controlling provision'), findsOneWidget);
      expect(find.text('Section 101.1'), findsOneWidget);
    });

    testWidgets('fails closed with explicit message when date is outside active manifest window', (tester) async {
      final service = ExamAssignedPracticeService(
        testCurrentUser: () => testUser,
        testSessionId: () => testSessionId,
        testIssue: (versionId, partKey, dateStr) async {
          throw Exception('No effective approved reference manifest for part on requested administration date');
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _TestAuthController(AuthSuccess(testUser))),
          ],
          child: MaterialApp(
            home: SecureExamPartPracticeScreen(
              targetVersionId: testTargetVersionId,
              examPartKey: testPartKey,
              administrationDate: DateTime.utc(2026, 3, 1),
              service: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('secure-exm-part-error')), findsOneWidget);
      expect(
        find.text(
          'Reviewed practice is unavailable for this exact exam part and administration date. '
          'No questions or scores have been fabricated.',
        ),
        findsOneWidget,
      );
    });
  });
}

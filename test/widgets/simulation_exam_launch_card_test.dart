import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:learning_pwa/models/learning_target.dart';
import 'package:learning_pwa/providers/assessment_engine_provider.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/providers/learning_target_provider.dart';
import 'package:learning_pwa/screens/assessment/mock_exam_screen.dart';
import 'package:learning_pwa/screens/targets/target_simulation_screen.dart';
import 'package:learning_pwa/services/assessment/clep_simulation_service.dart';
import 'package:learning_pwa/widgets/targets/simulation_exam_launch_card.dart';

class _MockAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  _MockAuthNotifier(super.initial);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('SimulationExamLaunchCard & TargetSimulationScreen Widget Tests', () {
    final now = DateTime.now();

    final testCollegeAlgebraVersion = TargetVersion(
      id: 'tv-clep-alg-2026',
      targetId: 'target-clep-alg',
      versionCode: '2026',
      title: 'CLEP College Algebra (2026 Official Blueprint Edition)',
      status: TargetVersionStatus.published,
      metadata: const {
        'role': 'blueprint_authority',
        'exam_code': 'CLEP-ALG',
        'total_domains': 4,
        'passing_score': 50,
        'scale': '20-80',
        'time_limit_minutes': 90,
        'question_count_approx': 60,
        'default_question_count': 60,
        'allowed_tools': ['calculator'],
        'bank': 'simulation_exam',
      },
      createdAt: now,
      updatedAt: now,
    );

    final mockAuthenticatedUser = User(
      id: 'learner-user-1234',
      appMetadata: const {},
      userMetadata: const {'display_name': 'College Student'},
      aud: 'authenticated',
      createdAt: now.toIso8601String(),
    );

    testWidgets('SimulationExamLaunchCard renders exam specifications, tools, and single-attempt security policy', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _MockAuthNotifier(GuestMode())),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SimulationExamLaunchCard(
                targetVersion: testCollegeAlgebraVersion,
                targetId: 'target-clep-alg',
                targetTitle: 'CLEP College Algebra',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify card and header
      expect(find.byKey(const Key('simulation-exam-launch-card')), findsOneWidget);
      expect(find.text('Official Simulation Exam'), findsOneWidget);
      expect(find.text('CLEP-ALG'), findsOneWidget);

      // 2. Verify specifications chips
      expect(find.text('60 Questions'), findsOneWidget);
      expect(find.text('90 Minutes'), findsOneWidget);
      expect(find.text('Scientific Calculator Permitted'), findsOneWidget);
      expect(find.text('ACE Passing: 50 / 80'), findsOneWidget);

      // 3. Verify single-attempt security warning
      expect(find.textContaining('Single Attempt Security: Exactly one official timed simulation attempt is permitted'), findsOneWidget);

      // 4. Verify start simulation action button
      expect(find.byKey(const Key('start-simulation-exam-button')), findsOneWidget);
      expect(find.text('Take Official Simulation (90 min)'), findsOneWidget);
    });

    testWidgets('Unauthenticated learner tapping start simulation sees authentication required dialog', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _MockAuthNotifier(GuestMode())),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SimulationExamLaunchCard(
                targetVersion: testCollegeAlgebraVersion,
                targetId: 'target-clep-alg',
                targetTitle: 'CLEP College Algebra',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('start-simulation-exam-button')));
      await tester.pumpAndSettle();

      // Verify authentication dialog pops up
      expect(find.text('Sign In Required'), findsOneWidget);
      expect(find.byKey(const Key('simulation-auth-sign-in-button')), findsOneWidget);
      expect(find.textContaining('Official timed CLEP simulation exams enforce a single-attempt security policy'), findsOneWidget);
    });

    testWidgets('SimulationExamLaunchCard detects active attempt and renders resume button with remaining time', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Future<dynamic> mockTransport(String rpcName, Map<String, dynamic> params) async {
        if (rpcName == 'clep_get_active_simulation_attempt') {
          return {
            'has_active_attempt': true,
            'attempt_id': 'att-active-42',
            'seconds_remaining': 3450, // 3450 / 60 = 57.5 -> 58 min
            'total_questions': 60,
            'issued_at': now.toIso8601String(),
            'expires_at': now.add(const Duration(minutes: 57, seconds: 30)).toIso8601String(),
          };
        }
        throw UnimplementedError('Unexpected RPC $rpcName');
      }

      final mockClepService = ClepSimulationService(transport: mockTransport);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _MockAuthNotifier(AuthSuccess(mockAuthenticatedUser))),
            clepSimulationServiceProvider.overrideWithValue(mockClepService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SimulationExamLaunchCard(
                targetVersion: testCollegeAlgebraVersion,
                targetId: 'target-clep-alg',
                targetTitle: 'CLEP College Algebra',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify active attempt indicator and resume button
      expect(find.text('Active Simulation in Progress'), findsOneWidget);
      expect(find.byKey(const Key('resume-simulation-exam-button')), findsOneWidget);
      expect(find.textContaining('Resume Official Simulation (58 min remaining)'), findsOneWidget);
    });

    testWidgets('SimulationExamLaunchCard renders SizedBox.shrink if target version is not simulation exam eligible', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final nonEligibleVersion = TargetVersion(
        id: 'tv-generic',
        targetId: 'target-generic',
        versionCode: '2026',
        title: 'Generic Exam',
        status: TargetVersionStatus.published,
        metadata: const {
          'role': 'blueprint_authority',
          'exam_code': 'GEN-101',
          // Missing bank: 'simulation_exam'
        },
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _MockAuthNotifier(AuthSuccess(mockAuthenticatedUser))),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SimulationExamLaunchCard(
                targetVersion: nonEligibleVersion,
                targetId: 'target-generic',
                targetTitle: 'Generic Exam',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('simulation-exam-launch-card')), findsNothing);
    });

    testWidgets('TargetSimulationScreen provides full briefing and launches into 60-question MockExamScreen with calculator tool', (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Future<dynamic> mockTransport(String rpcName, Map<String, dynamic> params) async {
        if (rpcName == 'clep_issue_simulation_exam') {
          return {
            'attempt_id': 'att-sim-101',
            'target_version_id': 'tv-clep-alg-2026',
            'total_questions': 60,
            'time_limit_minutes': 90,
            'issued_at': now.toIso8601String(),
            'expires_at': now.add(const Duration(minutes: 95)).toIso8601String(),
            'domains': [
              {'id': 'd1', 'code': '1.0', 'title': 'Algebraic operations', 'weight': 0.25},
              {'id': 'd2', 'code': '2.0', 'title': 'Equations and inequalities', 'weight': 0.25},
              {'id': 'd3', 'code': '3.0', 'title': 'Functions and their properties', 'weight': 0.30},
              {'id': 'd4', 'code': '4.0', 'title': 'Number systems and operations', 'weight': 0.20},
            ],
            'questions': [
              {
                'id': 'alg-sim-item-1',
                'interaction_type': 'single_choice',
                'prompt': 'Solve the linear inequality 3x - 5 > 7.',
                'domain_code': '2.0',
                'response_spec': {
                  'options': ['x > 4', 'x < 4', 'x > 2/3', 'x < 2/3'],
                },
                'metadata': {
                  'bank': 'simulation_exam',
                  'item_role': 'summative_simulation',
                  'domain_code': '2.0',
                },
                'concept_ids': ['alg-linear-inequalities'],
              },
            ],
          };
        }
        throw UnimplementedError('Unexpected RPC $rpcName');
      }

      final mockClepService = ClepSimulationService(transport: mockTransport);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _MockAuthNotifier(AuthSuccess(mockAuthenticatedUser))),
            clepSimulationServiceProvider.overrideWithValue(mockClepService),
            targetDetailProvider('target-clep-alg').overrideWith(
              (ref) async => LearningTarget(
                id: 'target-clep-alg',
                slug: 'clep-college-algebra',
                title: 'CLEP College Algebra',
                targetType: TargetType.certification,
                status: TargetStatus.published,
                isPublic: true,
                createdAt: now,
                updatedAt: now,
              ),
            ),
            targetVersionProvider('target-clep-alg').overrideWith(
              (ref) async => testCollegeAlgebraVersion,
            ),
          ],
          child: const MaterialApp(
            home: TargetSimulationScreen(
              targetId: 'target-clep-alg',
              targetVersionId: 'tv-clep-alg-2026',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify Briefing Screen Details
      expect(find.text('Official Simulation Exam Briefing'), findsOneWidget);
      expect(find.text('Examination Blueprint Specifications'), findsOneWidget);
      expect(find.textContaining('1.0 Operations (25%) · 2.0 Equations (25%) · 3.0 Functions (30%) · 4.0 Number Systems (20%)'), findsOneWidget);
      expect(find.textContaining('Built-in Scientific Calculator available in the exam navigation bar'), findsOneWidget);

      // 2. Start Simulation Exam
      expect(find.byKey(const Key('confirm-start-simulation-button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-start-simulation-button')));
      await tester.pumpAndSettle();

      // 3. Verify MockExamScreen loaded with calculator button and issued item
      expect(find.byType(MockExamScreen), findsOneWidget);
      expect(find.byKey(const Key('exam_calculator_button')), findsOneWidget);
      expect(find.text('Solve the linear inequality 3x - 5 > 7.'), findsOneWidget);
      expect(find.text('x > 4'), findsOneWidget);
    });
  });
}

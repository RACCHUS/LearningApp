import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/course_models.dart';
import 'package:learning_pwa/models/knowledge_concept.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/models/learning_target.dart';
import 'package:learning_pwa/models/scope.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/learning_target_provider.dart';
import 'package:learning_pwa/providers/next_action_provider.dart';
import 'package:learning_pwa/providers/router_provider.dart';
import 'package:learning_pwa/providers/scope_resolver_provider.dart';
import 'package:learning_pwa/screens/home/home_courses_list.dart';
import 'package:learning_pwa/screens/library/library_screen.dart';
import 'package:learning_pwa/services/next_action_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LearningTarget Disambiguation Tags Tests', () {
    test('produces correct disambiguation tags per spec §11.1', () {
      final exam = LearningTarget(
        id: '1',
        targetType: TargetType.licensureExam,
        title: 'Florida Air Conditioning Contractor Class A',
        slug: 'florida-ac-a',
        jurisdiction: 'Florida',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(exam.disambiguationTag, 'Licensure Exam (Florida)');

      final degree = LearningTarget(
        id: '2',
        targetType: TargetType.academicProgram,
        title: 'Computer Science BS',
        slug: 'cs-bs',
        institutionName: 'FIU',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(degree.disambiguationTag, 'Academic Program (FIU)');

      final cert = LearningTarget(
        id: '3',
        targetType: TargetType.certification,
        title: 'Cisco CCNA',
        slug: 'cisco-ccna',
        providerName: 'Cisco',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(cert.disambiguationTag, 'Certification (Cisco)');

      final career = LearningTarget(
        id: '4',
        targetType: TargetType.career,
        title: 'Cloud Architect',
        slug: 'cloud-architect',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(career.disambiguationTag, 'Career');

      final std = LearningTarget(
        id: '5',
        targetType: TargetType.standardizedExam,
        title: 'MCAT',
        slug: 'mcat',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(std.disambiguationTag, 'Standardized Exam');
    });
  });

  group('LibraryScreen Contextual Scope & Multi-Entity Search Tests', () {
    final activeContext = LearningContext(
      id: 'ctx-hvac',
      userId: 'user-1',
      label: 'Florida AC Class A',
      rootType: ContextRootType.target,
      rootId: 'target-hvac',
      emoji: '❄️',
      lastActiveAt: DateTime(2026, 9, 25),
    );

    final resolvedScope = ResolvedScope(
      contextId: 'ctx-hvac',
      coreConceptIds: {'c1'},
      supportingConceptIds: {'c2'},
      relatedConceptIds: {},
      curriculumNodeIds: {'node-1'},
      orderedActivities: const [
        ScopedLearningActivity(
          activityId: 'lesson-superheat',
          kind: ScopedActivityKind.lesson,
          title: 'Superheat Basics',
        ),
      ],
      questionIds: {'q1'},
      termIds: {'t1'},
      flashcardIds: {'fc1'},
      resolvedAt: DateTime(2026, 9, 25),
    );

    final targetHvac = LearningTarget(
      id: 'target-hvac',
      targetType: TargetType.licensureExam,
      title: 'Florida Air Conditioning Contractor Class A',
      slug: 'florida-ac-a',
      jurisdiction: 'Florida',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    final conceptSuperheat = KnowledgeConcept(
      id: 'c1',
      name: 'Superheat',
      slug: 'superheat',
      description: 'Refrigerant temperature measurement',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    final courseHvac = Course(
      id: 'course-hvac',
      title: 'Thermodynamics of Cooling',
      description: 'Principles of heat pump systems',
      category: 'HVAC',
      difficulty: 'Intermediate',
      author: 'Prof. HVAC',
      estimatedHours: 10,
      tags: const ['hvac'],
      skillsAcquired: const ['thermo'],
      status: CourseStatus.published,
      isPublic: true,
      isFeatured: false,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    testWidgets('renders contextual scope chip and toggles scope', (tester) async {
      final contextsState = LearningContextsState(
        contexts: [activeContext],
        activeId: activeContext.id,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _FakeAuthNotifier(GuestMode())),
            learningContextsProvider.overrideWith(
              (ref) => LearningContextsNotifier.stub(contextsState),
            ),
            activeResolvedScopeProvider.overrideWith(
              (ref) => Future.value(resolvedScope),
            ),
            targetsListProvider((type: null, types: null, search: null)).overrideWith(
              (ref) => Future.value([targetHvac]),
            ),
          ],
          child: const MaterialApp(
            home: LibraryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Scoped chip is initially visible
      expect(find.byKey(const Key('library-scope-chip')), findsOneWidget);
      expect(find.text('In: Florida AC Class A'), findsOneWidget);
      expect(find.byKey(const Key('library-search-all-chip')), findsOneWidget);

      // Tap ✕ on the chip to clear scope
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Now un-scoped mode is active
      expect(find.text('Scope to: Florida AC Class A'), findsOneWidget);
      expect(find.byKey(const Key('library-search-all-chip')), findsNothing);

      // Tap to re-enable scope
      await tester.tap(find.byKey(const Key('library-scope-chip')));
      await tester.pumpAndSettle();

      expect(find.text('In: Florida AC Class A'), findsOneWidget);
    });

    testWidgets('shows multi-entity search results with disambiguation tags', (tester) async {
      final contextsState = LearningContextsState(
        contexts: [activeContext],
        activeId: activeContext.id,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _FakeAuthNotifier(GuestMode())),
            learningContextsProvider.overrideWith(
              (ref) => LearningContextsNotifier.stub(contextsState),
            ),
            activeResolvedScopeProvider.overrideWith(
              (ref) => Future.value(null), // Unscoped/global search
            ),
            targetsListProvider((type: null, types: null, search: 'heat')).overrideWith(
              (ref) => Future.value([targetHvac]),
            ),
            searchCoursesProvider('heat').overrideWith(
              (ref) => Future.value([courseHvac]),
            ),
            searchConceptsProvider('heat').overrideWith(
              (ref) => Future.value([conceptSuperheat]),
            ),
          ],
          child: const MaterialApp(
            home: LibraryScreen(initialQuery: 'heat'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Search Results'), findsOneWidget);
      expect(find.text('Florida Air Conditioning Contractor Class A'), findsOneWidget);
      expect(find.text('Licensure Exam (Florida)'), findsOneWidget);

      expect(find.text('Thermodynamics of Cooling'), findsOneWidget);
      expect(find.text('Course'), findsOneWidget);

      expect(find.text('Superheat'), findsOneWidget);
      expect(find.text('Concept · Refrigerant temperature measurement'), findsOneWidget);
    });
  });

  group('Legacy Career Routes Redirects Tests', () {
    testWidgets('/careers/:id redirects to /target/:id', (tester) async {
      late GoRouter testRouter;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _FakeAuthNotifier(GuestMode())),
            learningBootstrapProvider.overrideWith((ref) async {}),
            learningContextsProvider.overrideWith(
              (ref) => LearningContextsNotifier.stub(
                const LearningContextsState(),
              ),
            ),
            nextActionProvider.overrideWith(
              (ref) async => const ChooseSomething(),
            ),
            activeDueCountProvider.overrideWith((ref) async => 0),
            targetDetailProvider('career-hvac-123').overrideWith(
              (ref) => Future.value(
                LearningTarget(
                  id: 'career-hvac-123',
                  targetType: TargetType.career,
                  title: 'HVAC Specialist',
                  slug: 'hvac-specialist',
                  createdAt: DateTime(2026),
                  updatedAt: DateTime(2026),
                ),
              ),
            ),
            targetVersionProvider('career-hvac-123').overrideWith(
              (ref) => Future.value(null),
            ),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              testRouter = ref.watch(routerProvider);
              return MaterialApp.router(
                routerConfig: testRouter,
              );
            },
          ),
        ),
      );

      // Navigate to legacy /careers/:id route
      testRouter.go('/careers/career-hvac-123');

      await tester.pumpAndSettle();

      // Verifies redirected to TargetDetailScreen showing target info
      expect(find.text('HVAC Specialist'), findsOneWidget);
      expect(find.text('Career'), findsOneWidget);
    });
  });
}

class _FakeAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  _FakeAuthNotifier([AuthState? initial]) : super(initial ?? GuestMode());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

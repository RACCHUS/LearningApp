import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/models/learning_target.dart';
import 'package:learning_pwa/models/curriculum_node.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/providers/learning_target_provider.dart';
import 'package:learning_pwa/screens/learn/start_learning_screen.dart';
import 'package:learning_pwa/screens/targets/target_detail_screen.dart';
import 'package:learning_pwa/screens/targets/target_outline_screen.dart';
import 'package:learning_pwa/models/user_curriculum_resource.dart';
import 'package:learning_pwa/providers/user_curriculum_resource_provider.dart';
import 'package:learning_pwa/services/user_curriculum_resource_service.dart';
import 'package:learning_pwa/widgets/targets/topic_lesson_sections.dart';
import '../test_helpers/fake_supabase_client.dart';

void main() {
  testWidgets(
    'official published outline offers personal study, not curriculum editing',
    (tester) async {
      final target = LearningTarget(
        id: 'official-target',
        targetType: TargetType.certification,
        title: 'Security+',
        slug: 'security-plus',
        isOfficial: true,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final version = TargetVersion(
        id: 'official-version',
        targetId: target.id,
        versionCode: 'v1',
        status: TargetVersionStatus.published,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _GuestAuthNotifier()),
            targetDetailProvider(
              target.id,
            ).overrideWith((ref) => Future.value(target)),
            targetVersionProvider(
              target.id,
            ).overrideWith((ref) => Future.value(version)),
            targetCurriculumNodesProvider(
              version.id,
            ).overrideWith((ref) => Future.value(<CurriculumNode>[])),
          ],
          child: MaterialApp(home: TargetOutlineScreen(targetId: target.id)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create Personal Lesson'), findsOneWidget);
      expect(find.text('Add Topic'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  group('TargetDetailScreen Widget Tests', () {
    testWidgets('renders target title, badge, and action buttons', (
      tester,
    ) async {
      final sampleTarget = LearningTarget(
        id: 'target-hvac',
        targetType: TargetType.licensureExam,
        title: 'Florida Air Conditioning Contractor Class A',
        slug: 'florida-ac-class-a',
        providerName: 'Florida DBPR',
        jurisdiction: 'Florida',
        emoji: '❄️',
        description: 'Comprehensive licensure exam preparation',
        isOfficial: true,
        createdAt: DateTime(2026, 9, 25),
        updatedAt: DateTime(2026, 9, 25),
      );

      final sampleVersion = TargetVersion(
        id: 'ver-2026',
        targetId: 'target-hvac',
        versionCode: '2026-v1',
        title: '2026 Official Exam Specification',
        status: TargetVersionStatus.published,
        createdAt: DateTime(2026, 9, 25),
        updatedAt: DateTime(2026, 9, 25),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            targetDetailProvider(
              'target-hvac',
            ).overrideWith((ref) => Future.value(sampleTarget)),
            targetVersionProvider(
              'target-hvac',
            ).overrideWith((ref) => Future.value(sampleVersion)),
          ],
          child: const MaterialApp(
            home: TargetDetailScreen(targetId: 'target-hvac'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Florida Air Conditioning Contractor Class A'),
        findsOneWidget,
      );
      expect(find.text('Licensure Exam'), findsOneWidget);
      expect(find.text('Florida DBPR'), findsOneWidget);
      expect(find.text('Florida'), findsOneWidget);
      expect(
        find.byKey(const Key('target-start-learning-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('target-view-outline-button')),
        findsOneWidget,
      );
      expect(find.text('About this Target'), findsOneWidget);
      expect(find.text('Curriculum Version 2026-v1'), findsOneWidget);
    });
  });

  group('StartLearningScreen Widget Tests', () {
    testWidgets('renders scope mode options and handles confirmation', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: StartLearningScreen(
              title: 'Cisco CCNA',
              rootType: ContextRootType.target,
              rootId: 'target-ccna',
              emoji: '🌐',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Configure Cisco CCNA'), findsOneWidget);
      expect(find.text('Customize Learning Scope'), findsOneWidget);
      expect(find.text('Core + Prerequisites (Recommended)'), findsOneWidget);
      expect(find.text('Core Requirements Only'), findsOneWidget);
      expect(find.text('Custom Configuration'), findsOneWidget);
      expect(
        find.byKey(const Key('start-learning-confirm-button')),
        findsOneWidget,
      );
    });
  });

  group('TopicLessonSections Widget Tests', () {
    final sampleNode = CurriculumNode(
      id: 'node-sec-1',
      targetVersionId: 'ver-1',
      title: 'Network Security Principles',
      sortOrder: 1,
      nodeType: 'topic',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    testWidgets('lists official and personal material sections separately',
        (tester) async {
      final fakeResourceService = _FakeUnlinkResourceService();
      final officialLessons = [
        const CurriculumNodeLesson(
          curriculumNodeId: 'node-sec-1',
          lessonId: 'official-1',
          lessonTitle: 'Firewalls & DMZ',
        ),
        const CurriculumNodeLesson(
          curriculumNodeId: 'node-sec-1',
          lessonId: 'official-2',
          lessonTitle: 'Intrusion Detection',
        ),
      ];
      final personalResources = [
        UserCurriculumResource(
          id: 'res-1',
          userId: 'user-1',
          curriculumNodeId: 'node-sec-1',
          lessonId: 'personal-1',
          lessonTitle: 'My Custom Subnet Notes',
          relationship: 'personal_study',
          sortOrder: 0,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userCurriculumResourceServiceProvider
                .overrideWith((ref) => fakeResourceService),
            nodeLessonsProvider('node-sec-1')
                .overrideWith((ref) => Future.value(officialLessons)),
            userCurriculumResourcesForNodeProvider('node-sec-1')
                .overrideWith((ref) => Future.value(personalResources)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: TopicLessonSections(node: sampleNode),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Official material'), findsOneWidget);
      expect(find.text('Firewalls & DMZ'), findsOneWidget);
      expect(find.text('Intrusion Detection'), findsOneWidget);

      expect(find.text('Your study material'), findsOneWidget);
      expect(find.text('My Custom Subnet Notes'), findsOneWidget);
      expect(find.text('Create personal study lesson'), findsOneWidget);
    });

    testWidgets('empty official lessons shows explicit message and offers creation',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nodeLessonsProvider('node-sec-1')
                .overrideWith((ref) => Future.value([])),
            userCurriculumResourcesForNodeProvider('node-sec-1')
                .overrideWith((ref) => Future.value([])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: TopicLessonSections(node: sampleNode),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No official lessons for this topic'), findsOneWidget);
      expect(find.text('No personal study lessons yet'), findsOneWidget);
      expect(find.text('Create personal study lesson'), findsOneWidget);
    });

    testWidgets('remove from topic unlinks personal lesson and failed unlink shows error',
        (tester) async {
      final fakeResourceService = _FakeUnlinkResourceService()..shouldFail = true;
      final personalResources = [
        UserCurriculumResource(
          id: 'res-1',
          userId: 'user-1',
          curriculumNodeId: 'node-sec-1',
          lessonId: 'personal-1',
          lessonTitle: 'My Custom Subnet Notes',
          relationship: 'personal_study',
          sortOrder: 0,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userCurriculumResourceServiceProvider
                .overrideWith((ref) => fakeResourceService),
            nodeLessonsProvider('node-sec-1')
                .overrideWith((ref) => Future.value([])),
            userCurriculumResourcesForNodeProvider('node-sec-1')
                .overrideWith((ref) => Future.value(personalResources)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: TopicLessonSections(node: sampleNode),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open popup menu on personal lesson
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('Remove from topic'), findsOneWidget);
      await tester.tap(find.text('Remove from topic'));
      await tester.pumpAndSettle();

      expect(fakeResourceService.removeCallCount, 1);
      expect(fakeResourceService.removedNodeId, 'node-sec-1');
      expect(fakeResourceService.removedLessonId, 'personal-1');
      // Failed unlink leaves item visible with error
      expect(find.text('My Custom Subnet Notes'), findsOneWidget);
      expect(find.textContaining('Failed to remove from topic'), findsOneWidget);
    });

    testWidgets('tapping topic node in outline opens topic sheet without auto-jumping',
        (tester) async {
      final target = LearningTarget(
        id: 'target-outline-test',
        targetType: TargetType.certification,
        title: 'Security+',
        slug: 'security-plus',
        isOfficial: true,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final version = TargetVersion(
        id: 'ver-outline-test',
        targetId: target.id,
        versionCode: 'v1',
        status: TargetVersionStatus.published,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final node = CurriculumNode(
        id: 'node-outline-1',
        targetVersionId: version.id,
        title: 'Access Control Systems',
        sortOrder: 1,
        nodeType: 'topic',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final officialLessons = [
        const CurriculumNodeLesson(
          curriculumNodeId: 'node-outline-1',
          lessonId: 'official-jump-1',
          lessonTitle: 'Discretionary Access Control',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _GuestAuthNotifier()),
            targetDetailProvider(target.id)
                .overrideWith((ref) => Future.value(target)),
            targetVersionProvider(target.id)
                .overrideWith((ref) => Future.value(version)),
            targetCurriculumNodesProvider(version.id)
                .overrideWith((ref) => Future.value([node])),
            nodeLessonsProvider('node-outline-1')
                .overrideWith((ref) => Future.value(officialLessons)),
            userCurriculumResourcesForNodeProvider('node-outline-1')
                .overrideWith((ref) => Future.value([])),
          ],
          child: MaterialApp(home: TargetOutlineScreen(targetId: target.id)),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'Open' button on node card
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Bottom sheet with TopicLessonSections opened, showing both sections
      expect(find.text('Official material'), findsOneWidget);
      expect(find.text('Discretionary Access Control'), findsOneWidget);
      expect(find.text('Your study material'), findsOneWidget);
      expect(find.text('Create personal study lesson'), findsOneWidget);
    });
  });
}

class _FakeUnlinkResourceService extends UserCurriculumResourceService {
  _FakeUnlinkResourceService() : super(supabase: FakeSupabaseClient());
  bool shouldFail = false;
  int removeCallCount = 0;
  String? removedNodeId;
  String? removedLessonId;

  @override
  Future<void> removePersonalLesson({
    required String curriculumNodeId,
    required String lessonId,
  }) async {
    removeCallCount++;
    removedNodeId = curriculumNodeId;
    removedLessonId = lessonId;
    if (shouldFail) {
      throw Exception('Database delete failed');
    }
  }
}

class _GuestAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _GuestAuthNotifier() : super(GuestMode());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

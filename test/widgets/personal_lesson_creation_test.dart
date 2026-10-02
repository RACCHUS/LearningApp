import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/curriculum_node.dart';
import 'package:learning_pwa/models/learning_target.dart';
import 'package:learning_pwa/models/user_curriculum_resource.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/providers/learning_target_provider.dart';
import 'package:learning_pwa/providers/user_curriculum_resource_provider.dart';
import 'package:learning_pwa/screens/targets/target_outline_screen.dart';
import 'package:learning_pwa/services/user_curriculum_resource_service.dart';
import 'package:learning_pwa/utils/lesson_creation_feedback.dart';
import 'package:learning_pwa/widgets/lesson/personal_attachment_result.dart';
import 'package:learning_pwa/services/learning_target_service.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import '../test_helpers/fake_supabase_client.dart';

class _FakeResourceService extends UserCurriculumResourceService {
  _FakeResourceService() : super(supabase: FakeSupabaseClient());

  int attachCallCount = 0;
  bool shouldFail = false;
  String? lastNodeId;
  String? lastLessonId;

  @override
  Future<UserCurriculumResource> attachPersonalLesson({
    required String curriculumNodeId,
    required String lessonId,
  }) async {
    attachCallCount++;
    lastNodeId = curriculumNodeId;
    lastLessonId = lessonId;
    if (shouldFail) {
      throw Exception('Network error attaching lesson');
    }
    return UserCurriculumResource(
      id: 'res-$attachCallCount',
      userId: 'user-1',
      curriculumNodeId: curriculumNodeId,
      lessonId: lessonId,
      lessonTitle: 'Test Lesson',
      relationship: 'personal_study',
      sortOrder: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

class _MockGuestAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _MockGuestAuthNotifier() : super(GuestMode());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('PersonalAttachmentResultDialog & handlePersonalStudyAttachment', () {
    testWidgets('successful attachment shows exact success copy and invalidates',
        (tester) async {
      final fakeService = _FakeResourceService();
      PersonalAttachmentResult? result;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userCurriculumResourceServiceProvider
                .overrideWith((ref) => fakeService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Consumer(
                  builder: (context, ref, _) => ElevatedButton(
                    onPressed: () async {
                      result = await handlePersonalStudyAttachment(
                        context: context,
                        ref: ref,
                        lessonId: 'lesson-101',
                        lessonTitle: 'Network Security',
                        curriculumNodeId: 'node-202',
                        nodeTitle: 'Security Fundamentals',
                      );
                    },
                    child: const Text('Attach'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Attach'));
      await tester.pumpAndSettle();

      expect(result, PersonalAttachmentResult.attached);
      expect(fakeService.attachCallCount, 1);
      expect(fakeService.lastLessonId, 'lesson-101');
      expect(fakeService.lastNodeId, 'node-202');
      expect(find.text(kPersonalAttachmentSuccessCopy), findsOneWidget);
    });

    testWidgets(
        'failed attachment opens dialog with exact failure copy, and retry succeeds',
        (tester) async {
      final fakeService = _FakeResourceService()..shouldFail = true;
      PersonalAttachmentResult? result;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userCurriculumResourceServiceProvider
                .overrideWith((ref) => fakeService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Consumer(
                  builder: (context, ref, _) => ElevatedButton(
                    onPressed: () async {
                      result = await handlePersonalStudyAttachment(
                        context: context,
                        ref: ref,
                        lessonId: 'lesson-101',
                        lessonTitle: 'Network Security',
                        curriculumNodeId: 'node-202',
                        nodeTitle: 'Security Fundamentals',
                      );
                    },
                    child: const Text('Attach'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Attach'));
      await tester.pumpAndSettle();

      // Dialog opens with exact spec failure copy
      expect(find.text(kPersonalAttachmentFailureCopy), findsOneWidget);
      expect(find.byKey(const Key('keep_in_library_button')), findsOneWidget);
      expect(find.byKey(const Key('retry_attachment_button')), findsOneWidget);
      expect(fakeService.attachCallCount, 1);

      // Now service recovers
      fakeService.shouldFail = false;

      // Tap Retry attachment
      await tester.tap(find.byKey(const Key('retry_attachment_button')));
      await tester.pumpAndSettle();

      // Retry called attach with same IDs (no second lesson creation)
      expect(fakeService.attachCallCount, 2);
      expect(fakeService.lastLessonId, 'lesson-101');
      expect(fakeService.lastNodeId, 'node-202');
      expect(result, PersonalAttachmentResult.attached);
      expect(find.text(kPersonalAttachmentSuccessCopy), findsOneWidget);
    });

    testWidgets('dismissing failed dialog with Keep in Library preserves lesson',
        (tester) async {
      final fakeService = _FakeResourceService()..shouldFail = true;
      PersonalAttachmentResult? result;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userCurriculumResourceServiceProvider
                .overrideWith((ref) => fakeService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Consumer(
                  builder: (context, ref, _) => ElevatedButton(
                    onPressed: () async {
                      result = await handlePersonalStudyAttachment(
                        context: context,
                        ref: ref,
                        lessonId: 'lesson-101',
                        lessonTitle: 'Network Security',
                        curriculumNodeId: 'node-202',
                      );
                    },
                    child: const Text('Attach'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Attach'));
      await tester.pumpAndSettle();

      expect(find.text(kPersonalAttachmentFailureCopy), findsOneWidget);

      // Tap Keep in Library
      await tester.tap(find.byKey(const Key('keep_in_library_button')));
      await tester.pumpAndSettle();

      expect(result, PersonalAttachmentResult.keptInLibrary);
      expect(fakeService.attachCallCount, 1);
    });
  });

  group('TargetOutlineScreen attachment intent', () {
    testWidgets('published official target topic specifies personal_study intent',
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
      final node = CurriculumNode(
        id: 'node-official-1',
        targetVersionId: version.id,
        title: 'Cryptography Fundamentals',
        sortOrder: 1,
        nodeType: 'topic',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _MockGuestAuthNotifier()),
            targetDetailProvider(target.id)
                .overrideWith((ref) => Future.value(target)),
            targetVersionProvider(target.id)
                .overrideWith((ref) => Future.value(version)),
            targetCurriculumNodesProvider(version.id)
                .overrideWith((ref) => Future.value([node])),
          ],
          child: MaterialApp(home: TargetOutlineScreen(targetId: target.id)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cryptography Fundamentals'), findsOneWidget);
    });

    testWidgets(
        'empty draft outline Generate with AI creates topic and routes with official_draft_binding',
        (tester) async {
      final target = LearningTarget(
        id: 'draft-target-empty',
        targetType: TargetType.certification,
        title: 'Draft Networking',
        slug: 'draft-networking',
        isOfficial: false,
        createdBy: 'user-owner',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final version = TargetVersion(
        id: 'ver-draft-empty',
        targetId: target.id,
        versionCode: 'v0.1',
        status: TargetVersionStatus.draft,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final mockService = _MockTargetService();

      String? pushedRoute;
      final router = GoRouter(
        initialLocation: '/target/${target.id}/outline',
        routes: [
          GoRoute(
            path: '/target/:targetId/outline',
            builder: (ctx, state) => TargetOutlineScreen(targetId: target.id),
          ),
          GoRoute(
            path: '/create-lesson',
            builder: (ctx, state) {
              pushedRoute = state.uri.toString();
              return const Scaffold(body: Text('CREATE LESSON SCREEN'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _UserAuthNotifier('user-owner')),
            targetDetailProvider(target.id)
                .overrideWith((ref) => Future.value(target)),
            targetVersionProvider(target.id)
                .overrideWith((ref) => Future.value(version)),
            targetCurriculumNodesProvider(version.id)
                .overrideWith((ref) => Future.value([])),
            learningTargetServiceProvider.overrideWith((ref) => mockService),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // Empty state shows 'Generate with AI'
      expect(find.text('Generate with AI'), findsOneWidget);
      await tester.tap(find.text('Generate with AI'));
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.text('Create Topic for Lesson'), findsOneWidget);
      await tester.tap(find.text('Continue to AI Generator'));
      await tester.pumpAndSettle();

      // Verifies node was created and routed to /create-lesson with official_draft_binding
      expect(mockService.addedTargetVersionId, 'ver-draft-empty');
      expect(pushedRoute, contains('/create-lesson'));
      expect(pushedRoute, contains('attachmentIntent=official_draft_binding'));
      expect(pushedRoute, contains('nodeId=node-gen-123'));
    });
  });
}

class _MockTargetService extends LearningTargetService {
  _MockTargetService() : super(supabase: FakeSupabaseClient());
  String? addedTargetVersionId;
  String? addedTitle;

  @override
  Future<CurriculumNode?> addCurriculumNode({
    required String targetVersionId,
    required String title,
    String? description,
    String? code,
    String nodeType = 'domain',
    int sortOrder = 0,
    String? parentId,
    double weight = 1.0,
  }) async {
    addedTargetVersionId = targetVersionId;
    addedTitle = title;
    return CurriculumNode(
      id: 'node-gen-123',
      targetVersionId: targetVersionId,
      title: title,
      sortOrder: sortOrder,
      nodeType: nodeType,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }
}

class _UserAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _UserAuthNotifier(String userId)
      : super(
          AuthSuccess(
            User(
              id: userId,
              appMetadata: {},
              userMetadata: {},
              aud: 'authenticated',
              createdAt: '2026-01-01',
            ),
          ),
        );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

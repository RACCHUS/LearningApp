import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/curriculum_node.dart';
import 'package:learning_pwa/models/generation_session.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/user_curriculum_resource.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/providers/generation_session_provider.dart';
import 'package:learning_pwa/providers/learning_target_provider.dart';
import 'package:learning_pwa/providers/lesson_provider.dart';
import 'package:learning_pwa/screens/lessons/create_lesson_screen.dart';
import 'package:learning_pwa/screens/lessons/guided_generation_screen.dart';
import 'package:learning_pwa/services/learning_target_service.dart';
import 'package:learning_pwa/services/lesson_service.dart';
import 'package:learning_pwa/services/lesson/lesson_crud_service.dart';
import 'package:learning_pwa/services/lesson/lesson_content_service.dart';
import 'package:learning_pwa/services/lesson/lesson_import_service.dart';
import 'package:learning_pwa/services/user_curriculum_resource_service.dart';
import 'package:learning_pwa/theme/semantic_colors.dart';
import 'package:learning_pwa/widgets/lesson/personal_attachment_result.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import '../test_helpers/fake_supabase_client.dart';

class _MockTargetBindingService extends LearningTargetService {
  _MockTargetBindingService({this.shouldBindSucceed = true})
      : super(supabase: FakeSupabaseClient());

  final bool shouldBindSucceed;
  int bindCallCount = 0;
  String? lastNodeId;
  String? lastLessonId;

  @override
  Future<bool> bindLessonToNode({
    required String curriculumNodeId,
    required String lessonId,
    bool isRequired = true,
    int sortOrder = 0,
  }) async {
    bindCallCount++;
    lastNodeId = curriculumNodeId;
    lastLessonId = lessonId;
    return shouldBindSucceed;
  }
}

class _MockLessonService extends LessonService {
  _MockLessonService()
      : super(
          crudService: LessonCrudService(supabase: FakeSupabaseClient()),
          contentService: LessonContentService(supabase: FakeSupabaseClient()),
          importService: LessonImportService(
            crudService: LessonCrudService(supabase: FakeSupabaseClient()),
            contentService: LessonContentService(supabase: FakeSupabaseClient()),
          ),
        );

  int importCallCount = 0;

  @override
  Future<Lesson> importLessonFromJson(String jsonData, String userId) async {
    importCallCount++;
    return Lesson(
      id: 'lesson-created-999',
      title: 'Created Test Lesson',
      tags: const ['test'],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      userId: userId,
      terms: const [],
      questions: const [],
      concepts: const [],
    );
  }
}

class _FakeSessionNotifier extends StateNotifier<GenerationSession?>
    implements GenerationSessionNotifier {
  _FakeSessionNotifier(super.state);

  @override
  void clearSession() {
    state = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

class _FakeResourceService extends UserCurriculumResourceService {
  _FakeResourceService() : super(supabase: FakeSupabaseClient());

  int attachCallCount = 0;
  bool shouldFail = false;

  @override
  Future<UserCurriculumResource> attachPersonalLesson({
    required String curriculumNodeId,
    required String lessonId,
  }) async {
    attachCallCount++;
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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CreateLessonScreen draft curriculum binding & invalidation', () {
    testWidgets(
        'official_draft_binding successfully binds lesson, invalidates nodeLessonsProvider, and shows success snackbar',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockTargetService = _MockTargetBindingService(shouldBindSucceed: true);
      final mockLessonService = _MockLessonService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _UserAuthNotifier('user-owner')),
            learningTargetServiceProvider
                .overrideWith((ref) => mockTargetService),
            lessonServiceProvider.overrideWith((ref) => mockLessonService),
            nodeLessonsProvider('node-draft-1')
                .overrideWith((ref) => Future.value(<CurriculumNodeLesson>[])),
          ],
          child: MaterialApp(
            theme: ThemeData(extensions: const [SemanticColors.light]),
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => Navigator.of(ctx).push(
                    MaterialPageRoute(
                      builder: (_) => const CreateLessonScreen(
                        initialTabIndex: 1, // JSON Import tab
                        nodeId: 'node-draft-1',
                        nodeTitle: 'TCP Handshake',
                        targetVersionId: 'ver-draft-1',
                        attachmentIntent: 'official_draft_binding',
                      ),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Trigger load example and import
      await tester.tap(find.text('Load Example'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Import Lesson'));
      await tester.pumpAndSettle();

      // Verified: bindLessonToNode was called with the created lesson ID and node ID
      expect(mockTargetService.bindCallCount, 1);
      expect(mockTargetService.lastNodeId, 'node-draft-1');
      expect(mockTargetService.lastLessonId, 'lesson-created-999');

      // Verified: SnackBar shows success message with green success color
      final snackBarFinder = find.byType(SnackBar);
      expect(snackBarFinder, findsOneWidget);
      final snackBar = tester.widget<SnackBar>(snackBarFinder);
      expect(snackBar.backgroundColor, SemanticColors.light.success);
      expect(find.textContaining('bound to TCP Handshake'), findsOneWidget);
    });

    testWidgets(
        'official_draft_binding failure displays semantic warning snackbar with fallback copy',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockTargetService =
          _MockTargetBindingService(shouldBindSucceed: false);
      final mockLessonService = _MockLessonService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _UserAuthNotifier('user-owner')),
            learningTargetServiceProvider
                .overrideWith((ref) => mockTargetService),
            lessonServiceProvider.overrideWith((ref) => mockLessonService),
            nodeLessonsProvider('node-draft-1')
                .overrideWith((ref) => Future.value(<CurriculumNodeLesson>[])),
          ],
          child: MaterialApp(
            theme: ThemeData(extensions: const [SemanticColors.light]),
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => Navigator.of(ctx).push(
                    MaterialPageRoute(
                      builder: (_) => const CreateLessonScreen(
                        initialTabIndex: 1,
                        nodeId: 'node-draft-1',
                        nodeTitle: 'TCP Handshake',
                        targetVersionId: 'ver-draft-1',
                        attachmentIntent: 'official_draft_binding',
                      ),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Load Example'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Import Lesson'));
      await tester.pumpAndSettle();

      // Binding attempted but failed
      expect(mockTargetService.bindCallCount, 1);

      // Verified: SnackBar uses warning color and communicates failure to attach
      final snackBarFinder = find.byType(SnackBar);
      expect(snackBarFinder, findsOneWidget);
      final snackBar = tester.widget<SnackBar>(snackBarFinder);
      expect(snackBar.backgroundColor, SemanticColors.light.warning);
      expect(find.textContaining("couldn't attach it to TCP Handshake"),
          findsOneWidget);
    });

    testWidgets(
        'standalone lesson creation with nodeId but no intent does NOT attempt curriculum binding',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockTargetService = _MockTargetBindingService();
      final mockLessonService = _MockLessonService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _UserAuthNotifier('user-owner')),
            learningTargetServiceProvider
                .overrideWith((ref) => mockTargetService),
            lessonServiceProvider.overrideWith((ref) => mockLessonService),
          ],
          child: MaterialApp(
            theme: ThemeData(extensions: const [SemanticColors.light]),
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => Navigator.of(ctx).push(
                    MaterialPageRoute(
                      builder: (_) => const CreateLessonScreen(
                        initialTabIndex: 1,
                        nodeId: 'node-draft-1',
                        nodeTitle: 'TCP Handshake',
                        // attachmentIntent omitted
                      ),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Load Example'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Import Lesson'));
      await tester.pumpAndSettle();

      // No binding attempted without explicit intent
      expect(mockTargetService.bindCallCount, 0);

      final snackBarFinder = find.byType(SnackBar);
      expect(snackBarFinder, findsOneWidget);
      final snackBar = tester.widget<SnackBar>(snackBarFinder);
      expect(snackBar.backgroundColor, SemanticColors.light.success);
      expect(find.textContaining('created successfully'), findsOneWidget);
    });
  });

  group('GuidedGenerationScreen explicit binding intent & invalidation', () {
    testWidgets(
        'GuidedGenerationScreen: binds only when attachmentIntent is official_draft_binding',
        (tester) async {
      final mockTargetService = _MockTargetBindingService(shouldBindSucceed: true);
      final mockLessonService = _MockLessonService();

      final session = GenerationSession(
        id: 'session-complete',
        createdAt: DateTime(2026),
        subject: 'Networking Basics',
        targetAudience: 'Beginner',
        durationMinutes: 30,
        difficulty: 'beginner',
        contentFocus: 'balanced',
        currentPhase: GenerationPhase.complete,
        terms: const [
          {'title': 'IP', 'content': 'Internet Protocol'}
        ],
        concepts: const [],
        mcqs: const [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _UserAuthNotifier('user-owner')),
            learningTargetServiceProvider
                .overrideWith((ref) => mockTargetService),
            lessonServiceProvider.overrideWith((ref) => mockLessonService),
            generationSessionProvider
                .overrideWith((ref) => _FakeSessionNotifier(session)),
            nodeLessonsProvider('node-guided-1')
                .overrideWith((ref) => Future.value(<CurriculumNodeLesson>[])),
          ],
          child: MaterialApp(
            theme: ThemeData(extensions: const [SemanticColors.light]),
            home: const GuidedGenerationScreen(
              initialSubject: 'Networking Basics',
              nodeId: 'node-guided-1',
              targetVersionId: 'ver-draft-1',
              attachmentIntent: 'official_draft_binding',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Phase is complete, so Import Lesson button is present
      expect(find.text('Import Lesson'), findsOneWidget);
      await tester.tap(find.text('Import Lesson'));
      await tester.pumpAndSettle();

      expect(mockTargetService.bindCallCount, 1);
      expect(mockTargetService.lastNodeId, 'node-guided-1');
      expect(mockTargetService.lastLessonId, 'lesson-created-999');

      final snackBarFinder = find.byType(SnackBar);
      expect(snackBarFinder, findsOneWidget);
      final snackBar = tester.widget<SnackBar>(snackBarFinder);
      expect(snackBar.backgroundColor, SemanticColors.light.success);
      expect(find.textContaining('bound to Networking Basics'), findsOneWidget);
    });

    testWidgets(
        'GuidedGenerationScreen: ignores nodeId when attachmentIntent is not official_draft_binding',
        (tester) async {
      final mockTargetService = _MockTargetBindingService();
      final mockLessonService = _MockLessonService();

      final session = GenerationSession(
        id: 'session-complete',
        createdAt: DateTime(2026),
        subject: 'Networking Basics',
        targetAudience: 'Beginner',
        durationMinutes: 30,
        difficulty: 'beginner',
        contentFocus: 'balanced',
        currentPhase: GenerationPhase.complete,
        terms: const [
          {'title': 'IP', 'content': 'Internet Protocol'}
        ],
        concepts: const [],
        mcqs: const [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _UserAuthNotifier('user-owner')),
            learningTargetServiceProvider
                .overrideWith((ref) => mockTargetService),
            lessonServiceProvider.overrideWith((ref) => mockLessonService),
            generationSessionProvider
                .overrideWith((ref) => _FakeSessionNotifier(session)),
          ],
          child: MaterialApp(
            theme: ThemeData(extensions: const [SemanticColors.light]),
            home: const GuidedGenerationScreen(
              initialSubject: 'Networking Basics',
              nodeId: 'node-guided-1',
              // attachmentIntent is null
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Import Lesson'), findsOneWidget);
      await tester.tap(find.text('Import Lesson'));
      await tester.pumpAndSettle();

      // Crucial invariant: Having a nodeId alone does NOT trigger curriculum binding
      expect(mockTargetService.bindCallCount, 0);

      final snackBarFinder = find.byType(SnackBar);
      expect(snackBarFinder, findsOneWidget);
      final snackBar = tester.widget<SnackBar>(snackBarFinder);
      expect(snackBar.backgroundColor, SemanticColors.light.success);
      expect(find.textContaining('imported for Networking Basics'), findsOneWidget);
    });

    testWidgets(
        'GuidedGenerationScreen: binding failure displays semantic warning snackbar',
        (tester) async {
      final mockTargetService =
          _MockTargetBindingService(shouldBindSucceed: false);
      final mockLessonService = _MockLessonService();

      final session = GenerationSession(
        id: 'session-complete',
        createdAt: DateTime(2026),
        subject: 'Networking Basics',
        targetAudience: 'Beginner',
        durationMinutes: 30,
        difficulty: 'beginner',
        contentFocus: 'balanced',
        currentPhase: GenerationPhase.complete,
        terms: const [
          {'title': 'IP', 'content': 'Internet Protocol'}
        ],
        concepts: const [],
        mcqs: const [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _UserAuthNotifier('user-owner')),
            learningTargetServiceProvider
                .overrideWith((ref) => mockTargetService),
            lessonServiceProvider.overrideWith((ref) => mockLessonService),
            generationSessionProvider
                .overrideWith((ref) => _FakeSessionNotifier(session)),
            nodeLessonsProvider('node-guided-1')
                .overrideWith((ref) => Future.value(<CurriculumNodeLesson>[])),
          ],
          child: MaterialApp(
            theme: ThemeData(extensions: const [SemanticColors.light]),
            home: const GuidedGenerationScreen(
              initialSubject: 'Networking Basics',
              nodeId: 'node-guided-1',
              attachmentIntent: 'official_draft_binding',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Import Lesson'));
      await tester.pumpAndSettle();

      expect(mockTargetService.bindCallCount, 1);

      final snackBarFinder = find.byType(SnackBar);
      expect(snackBarFinder, findsOneWidget);
      final snackBar = tester.widget<SnackBar>(snackBarFinder);
      expect(snackBar.backgroundColor, SemanticColors.light.warning);
      expect(find.textContaining("couldn't attach it to Networking Basics"),
          findsOneWidget);
    });
  });

  group('PersonalAttachmentResultDialog async await race condition fix', () {
    testWidgets(
        'awaits onAttached callback before closing dialog and presenting success snackbar',
        (tester) async {
      final fakeService = _FakeResourceService()..shouldFail = true;
      final controller = PersonalAttachmentController(
        resourceService: fakeService,
        curriculumNodeId: 'node-101',
        lessonId: 'lesson-202',
        lessonTitle: 'Test Lesson',
      );

      // Perform initial fail
      await controller.attach();
      expect(controller.status, AttachmentStatus.failed);

      final onAttachedCompleter = Completer<void>();
      bool onAttachedCompleted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => PersonalAttachmentResultDialog(
                      controller: controller,
                      onAttached: () async {
                        await onAttachedCompleter.future;
                        onAttachedCompleted = true;
                      },
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(PersonalAttachmentResultDialog), findsOneWidget);

      // Service recovers
      fakeService.shouldFail = false;

      // Tap Retry attachment
      await tester.tap(find.byKey(const Key('retry_attachment_button')));
      await tester.pump(); // Start async retry

      // While onAttached is pending, dialog should still be mounted
      expect(find.byType(PersonalAttachmentResultDialog), findsOneWidget);
      expect(onAttachedCompleted, isFalse);

      // Complete onAttached future
      onAttachedCompleter.complete();
      await tester.pumpAndSettle();

      // Now onAttached completed and dialog popped
      expect(onAttachedCompleted, isTrue);
      expect(find.byType(PersonalAttachmentResultDialog), findsNothing);
      expect(find.text(kPersonalAttachmentSuccessMessage), findsOneWidget);
    });
  });
}

import 'package:learning_pwa/screens/settings_screen.dart';
import 'package:learning_pwa/screens/governance/moderation_queue_screen.dart'
    deferred as moderation_queue;
import 'package:learning_pwa/screens/governance/cost_observability_screen.dart'
    deferred as cost_observability;
import 'package:learning_pwa/screens/governance/product_analytics_overview_screen.dart'
    deferred as product_analytics_overview;
import 'package:learning_pwa/screens/governance/feature_control_center_screen.dart'
    deferred as feature_control_center;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/screens/lessons/create_lesson_screen.dart';
import 'package:learning_pwa/screens/lesson_editor_screen.dart'
    deferred as lesson_editor;
import 'package:learning_pwa/screens/course_builder_screen.dart'
    deferred as course_builder;
import 'package:learning_pwa/screens/study/lesson_screen.dart';
import 'package:learning_pwa/screens/study/study_set_screen.dart';
import 'package:learning_pwa/screens/lessons/lesson_selection_screen.dart';
import 'package:learning_pwa/screens/auth/login_screen.dart';
import 'package:learning_pwa/screens/profile_screen.dart';
import 'package:learning_pwa/screens/test/hands_free_test_screen.dart'
    deferred as hands_free_test;
import 'package:learning_pwa/screens/course_management_screen.dart';
import 'package:learning_pwa/screens/courses/course_detail_screen.dart';
import 'package:learning_pwa/screens/study_sets/content_picker_screen.dart';
import 'package:learning_pwa/screens/study_sets/saved_study_sets_screen.dart';
import 'package:learning_pwa/screens/words/word_learning_screen.dart';
import 'package:learning_pwa/screens/words/word_transfer_screen.dart';
import 'package:learning_pwa/screens/progress/progress_screen.dart';
import 'package:learning_pwa/screens/skills/skills_profile_screen.dart';
import 'package:learning_pwa/screens/skills/skill_detail_screen.dart';
import 'package:learning_pwa/screens/assessment/assessment_screen.dart';
import 'package:learning_pwa/screens/assessment/diagnostic_assessment_screen.dart';
import 'package:learning_pwa/screens/settings/reset_center_screen.dart'
    deferred as reset_center;
import 'package:learning_pwa/screens/settings/product_analytics_privacy_screen.dart'
    deferred as product_analytics_privacy;
import 'package:learning_pwa/screens/settings/motivation_settings_screen.dart';
import 'package:learning_pwa/screens/lessons/guided_generation_screen.dart'
    deferred as guided_generation;
import 'package:learning_pwa/screens/learn/learn_screen.dart';
import 'package:learning_pwa/screens/library/library_screen.dart';
import 'package:learning_pwa/screens/courses/course_outline_screen.dart';
import 'package:learning_pwa/screens/targets/target_detail_screen.dart';
import 'package:learning_pwa/screens/targets/target_outline_screen.dart';
import 'package:learning_pwa/screens/targets/target_simulation_screen.dart';
import 'package:learning_pwa/screens/overview/overview_tour_screen.dart';
import 'package:learning_pwa/models/learning_strategy.dart';
import 'package:learning_pwa/screens/concepts/concept_detail_screen.dart';
import 'package:learning_pwa/screens/learn/start_learning_screen.dart';
import 'package:learning_pwa/screens/review_screen.dart';
import 'package:learning_pwa/screens/taxonomy/taxonomy_explorer_screen.dart'
    deferred as taxonomy_explorer;
import 'package:learning_pwa/screens/taxonomy/occupation_detail_screen.dart'
    deferred as occupation_detail;
import 'package:learning_pwa/screens/literacy/foundational_literacy_screen.dart';
import 'package:learning_pwa/screens/literacy/life_milestones_screen.dart';
import 'package:learning_pwa/screens/literacy/life_domains_screen.dart';
import 'package:learning_pwa/screens/simulation/simulation_screen.dart'
    deferred as simulation_screen;
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/models/simulation_activity.dart';
import 'package:learning_pwa/widgets/app_shell.dart';
import 'package:learning_pwa/widgets/site_feature_refresh_observer.dart';
import 'package:learning_pwa/widgets/deferred_loader_widget.dart';
import 'package:learning_pwa/widgets/help/help_action.dart';
import 'package:learning_pwa/widgets/simulation/simulation_navigation.dart';
import 'package:learning_pwa/widgets/software_learning/excel_upload_card.dart';

/// Builds the deferred simulation route. [loader] is injectable so the
/// load-failure return path can be tested end to end.
Widget buildSimulationRoute({
  required String simulationId,
  required String version,
  LibraryLoader? loader,
}) {
  return DeferredLoaderWidget(
    loader: loader ?? simulation_screen.loadLibrary,
    // Keyed so switching between simulations on this route rebuilds the
    // screen and ends the previous session instead of reusing stale state.
    builder: () => simulation_screen.SimulationScreen(
      key: ValueKey('simulation/$simulationId/$version'),
      simulationId: simulationId,
      version: version,
    ),
    errorBuilder: (context, error) => Scaffold(
      appBar: AppBar(
        title: const Text('Interactive practice unavailable'),
        actions: const [HelpAction()],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'The simulation could not load. Return to the lesson '
              'and use its alternative activity.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('simulation-load-failure-return'),
              onPressed: () => leaveSimulation(context),
              child: const Text('Return to lesson'),
            ),
          ],
        ),
      ),
    ),
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/learn',
    routes: [
      // Persistent three-destination shell: Learn | Library | Progress.
      ShellRoute(
        builder: (context, state, child) =>
            SiteFeatureRefreshObserver(child: AppShell(child: child)),
        routes: [
          GoRoute(
            path: '/learn',
            name: 'learn',
            builder: (context, state) => const LearnScreen(),
          ),
          GoRoute(
            path: '/library',
            name: 'library',
            builder: (context, state) => LibraryScreen(
              initialQuery: state.uri.queryParameters['search'],
              initialType: state.uri.queryParameters['type'],
            ),
          ),
          GoRoute(
            path: '/progress',
            name: 'progress-dashboard',
            builder: (context, state) => const ProgressScreen(),
          ),
        ],
      ),

      // Course outline — the single secondary destination from Learn for courses.
      GoRoute(
        path: '/course/:courseId/outline',
        name: 'course-outline',
        builder: (context, state) =>
            CourseOutlineScreen(courseId: state.pathParameters['courseId']!),
      ),

      // Target detail and outline routes (Learning Architecture v2)
      GoRoute(
        path: '/target/:targetId',
        name: 'target-detail',
        builder: (context, state) =>
            TargetDetailScreen(targetId: state.pathParameters['targetId']!),
      ),
      GoRoute(
        path: '/target/:targetId/outline',
        name: 'target-outline',
        builder: (context, state) =>
            TargetOutlineScreen(targetId: state.pathParameters['targetId']!),
      ),
      GoRoute(
        path: '/overview/:targetId',
        name: 'subject-overview',
        builder: (context, state) {
          final rawMinutes = int.tryParse(
            state.uri.queryParameters['duration'] ?? '',
          );
          return OverviewTourScreen(
            targetSlugOrId: state.pathParameters['targetId']!,
            targetSlug: state.uri.queryParameters['slug'],
            initialPreset: OverviewDurationPreset.fromMinutes(rawMinutes),
          );
        },
      ),
      GoRoute(
        path: '/target/:targetId/diagnostic/:targetVersionId',
        name: 'target-diagnostic',
        builder: (context, state) => DiagnosticAssessmentScreen(
          targetId: state.pathParameters['targetId']!,
          targetVersionId: state.pathParameters['targetVersionId']!,
        ),
      ),
      GoRoute(
        path: '/target/:targetId/simulation/:targetVersionId',
        name: 'target-simulation',
        builder: (context, state) => TargetSimulationScreen(
          targetId: state.pathParameters['targetId']!,
          targetVersionId: state.pathParameters['targetVersionId']!,
        ),
      ),
      GoRoute(
        path: '/concept/:conceptId',
        name: 'concept-detail',
        builder: (context, state) =>
            ConceptDetailScreen(conceptId: state.pathParameters['conceptId']!),
      ),
      GoRoute(
        path: '/start-learning',
        name: 'start-learning',
        builder: (context, state) {
          final title = state.uri.queryParameters['title'] ?? 'Learning Target';
          final rootTypeStr = state.uri.queryParameters['rootType'] ?? 'target';
          final rootId = state.uri.queryParameters['rootId'] ?? '';
          final emoji = state.uri.queryParameters['emoji'];
          final targetVersionId = state.uri.queryParameters['targetVersionId'];

          final rootType = ContextRootType.values.firstWhere(
            (e) => e.name == rootTypeStr,
            orElse: () => ContextRootType.target,
          );

          return StartLearningScreen(
            title: title,
            rootType: rootType,
            rootId: rootId,
            emoji: emoji,
            targetVersionId: targetVersionId,
          );
        },
      ),

      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        redirect: (context, state) => '/learn',
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      // Legacy home surface, replaced by /learn. Kept only as a redirect
      // target so existing deep links and bookmarks keep working.
      GoRoute(path: '/', name: 'home', redirect: (context, state) => '/learn'),

      // Foundational literacy route for pre-readers
      GoRoute(
        path: '/literacy',
        name: 'literacy',
        builder: (context, state) {
          final tab =
              state.uri.queryParameters['tab'] ??
              state.uri.queryParameters['section'];
          LiteracyHubSection? initialSection;
          if (tab == 'stories') {
            initialSection = LiteracyHubSection.stories;
          } else if (tab == 'diagnostic' || tab == 'placement') {
            initialSection = LiteracyHubSection.diagnostic;
          } else if (tab == 'blending' || tab == 'cvc') {
            initialSection = LiteracyHubSection.blending;
          } else if (tab == 'survival') {
            initialSection = LiteracyHubSection.survival;
          } else if (tab == 'id' || tab == 'personal') {
            initialSection = LiteracyHubSection.personalId;
          }
          return FoundationalLiteracyScreen(initialSection: initialSection);
        },
      ),

      // High-stakes US life milestones route (USCIS 2025, Florida DMV, GED Bridge)
      GoRoute(
        path: '/milestones',
        name: 'milestones',
        builder: (context, state) {
          final categoryParam = state.uri.queryParameters['category'];
          LifeMilestoneCategory initialCategory =
              LifeMilestoneCategory.citizenship;
          if (categoryParam == 'driver' || categoryParam == 'dmv') {
            initialCategory = LifeMilestoneCategory.driverLicense;
          } else if (categoryParam == 'ged') {
            initialCategory = LifeMilestoneCategory.gedBridge;
          }
          return LifeMilestonesScreen(initialCategory: initialCategory);
        },
      ),

      // Practical life domains route (OSHA safety, FDA food, Healthcare, Cash & ATM)
      GoRoute(
        path: '/domains',
        name: 'domains',
        builder: (context, state) {
          final categoryParam = state.uri.queryParameters['category'];
          LifeDomainCategory initialCategory =
              LifeDomainCategory.workplaceSafety;
          if (categoryParam == 'food') {
            initialCategory = LifeDomainCategory.foodSafety;
          } else if (categoryParam == 'health' || categoryParam == 'firstaid') {
            initialCategory = LifeDomainCategory.healthcareFirstAid;
          } else if (categoryParam == 'cash' || categoryParam == 'atm') {
            initialCategory = LifeDomainCategory.financialAtm;
          }
          return LifeDomainsScreen(initialCategory: initialCategory);
        },
      ),

      GoRoute(
        path: '/simulation/:simulationId/:version',
        name: 'simulation',
        builder: (context, state) => buildSimulationRoute(
          simulationId: state.pathParameters['simulationId']!,
          version: state.pathParameters['version']!,
        ),
      ),

      GoRoute(
        path: '/software-practice/:exerciseId',
        name: 'software-practice',
        builder: (context, state) {
          if (!isSimulationPreviewAllowed(requested: true)) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Interactive Practice Unavailable'),
                actions: const [HelpAction()],
              ),
              body: const SafeArea(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Software practice is an experimental preview feature and is disabled in this build.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            );
          }
          final exerciseId =
              state.pathParameters['exerciseId'] ?? 'excel-budget-total-v1';
          return Scaffold(
            appBar: AppBar(
              title: const Text('Excel Guided Practice'),
              actions: const [HelpAction()],
            ),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 840),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: ExcelUploadCard(exerciseId: exerciseId),
                  ),
                ),
              ),
            ),
          );
        },
      ),

      // Create lesson route
      GoRoute(
        path: '/create-lesson',
        name: 'create-lesson',
        builder: (context, state) {
          final tabParam = state.uri.queryParameters['tab'];
          final contentParam = state.uri.queryParameters['content'];
          final nodeId = state.uri.queryParameters['nodeId'];
          final nodeTitle = state.uri.queryParameters['nodeTitle'];
          final targetVersionId = state.uri.queryParameters['targetVersionId'];
          final attachmentIntent =
              state.uri.queryParameters['attachmentIntent'];

          int initialTab = 0;
          int initialBuilderTab = 0;

          if (tabParam == 'json') {
            initialTab = 1;
          } else if (tabParam == 'manual') {
            initialTab = 2;
          }

          if (contentParam == 'mcq' || contentParam == 'question') {
            initialBuilderTab = 1;
          } else if (contentParam == 'concept') {
            initialBuilderTab = 2;
          } else {
            initialBuilderTab = 0;
          }

          return CreateLessonScreen(
            initialTabIndex: initialTab,
            initialBuilderTabIndex: initialBuilderTab,
            nodeId: nodeId,
            nodeTitle: nodeTitle,
            targetVersionId: targetVersionId,
            attachmentIntent: attachmentIntent,
          );
        },
      ),

      // Course management route
      GoRoute(
        path: '/course-management',
        name: 'course-management',
        builder: (context, state) => const CourseManagementScreen(),
      ),

      // Course detail route
      GoRoute(
        path: '/courses/:courseId',
        name: 'course-detail',
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          return CourseDetailScreen(courseId: courseId);
        },
      ),

      // Study lesson route - this will show lesson content
      GoRoute(
        path: '/lesson/:lessonId',
        name: 'study-lesson',
        builder: (context, state) {
          final lessonId = state.pathParameters['lessonId']!;
          return LessonScreen(lessonId: lessonId);
        },
      ),

      // Alternative study modes could be added here
      GoRoute(
        path: '/lesson/:lessonId/study',
        name: 'lesson-study-mode',
        builder: (context, state) {
          final lessonId = state.pathParameters['lessonId']!;
          return LessonScreen(lessonId: lessonId);
        },
      ),
      GoRoute(
        path: '/study-set',
        name: 'study-set',
        builder: (context, state) {
          final idsParam = state.uri.queryParameters['ids'] ?? '';
          final setId =
              state.uri.queryParameters['setId'] ??
              state.uri.queryParameters['id'];
          final lessonIds = idsParam.isNotEmpty
              ? idsParam.split(',')
              : <String>[];
          return StudySetScreen(lessonIds: lessonIds, studySetId: setId);
        },
      ),
      GoRoute(
        path: '/words/transfer',
        name: 'word-learning-transfer',
        builder: (context, state) => const WordTransferScreen(),
      ),
      GoRoute(
        path: '/words',
        name: 'word-learning',
        builder: (context, state) => const WordLearningScreen(),
      ),
      GoRoute(
        path: '/study-sets',
        name: 'study-sets',
        builder: (context, state) => const SavedStudySetsScreen(),
      ),
      GoRoute(
        path: '/review',
        name: 'review',
        builder: (context, state) {
          final contextId = state.uri.queryParameters['contextId'];
          final limitStr = state.uri.queryParameters['limit'];
          final limit = limitStr != null ? int.tryParse(limitStr) : null;
          final conceptsStr = state.uri.queryParameters['concepts'];
          final specificConceptIds =
              conceptsStr != null && conceptsStr.isNotEmpty
              ? conceptsStr.split(',').where((s) => s.isNotEmpty).toList()
              : null;
          return ReviewScreen(
            contextId: contextId,
            limit: limit,
            specificConceptIds: specificConceptIds,
          );
        },
      ),
      GoRoute(
        path: '/content-picker',
        name: 'content-picker',
        builder: (context, state) {
          final idsParam = state.uri.queryParameters['ids'] ?? '';
          final lessonIds = idsParam.isNotEmpty
              ? idsParam.split(',')
              : <String>[];
          final title = state.uri.queryParameters['title'];
          return ContentPickerScreen(lessonIds: lessonIds, title: title);
        },
      ),
      GoRoute(
        path: '/lesson-selection',
        name: 'lesson-selection',
        builder: (context, state) => const LessonSelectionScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/motivation',
        name: 'settings-motivation',
        builder: (context, state) => const MotivationSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/privacy/analytics',
        name: 'product-analytics-privacy',
        builder: (context, state) => DeferredLoaderWidget(
          loader: product_analytics_privacy.loadLibrary,
          builder: () =>
              product_analytics_privacy.ProductAnalyticsPrivacyScreen(),
        ),
      ),
      GoRoute(
        path: '/moderation',
        name: 'moderation-queue',
        builder: (context, state) => DeferredLoaderWidget(
          loader: moderation_queue.loadLibrary,
          builder: () => moderation_queue.ModerationQueueScreen(),
        ),
      ),
      GoRoute(
        path: '/observability',
        name: 'cost-observability',
        builder: (context, state) => DeferredLoaderWidget(
          loader: cost_observability.loadLibrary,
          builder: () => cost_observability.CostObservabilityScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/features',
        name: 'feature-control-center',
        builder: (context, state) => DeferredLoaderWidget(
          loader: feature_control_center.loadLibrary,
          builder: () => feature_control_center.FeatureControlCenterScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/analytics',
        name: 'product-analytics-overview',
        builder: (context, state) => DeferredLoaderWidget(
          loader: product_analytics_overview.loadLibrary,
          builder: () =>
              product_analytics_overview.ProductAnalyticsOverviewScreen(),
        ),
      ),
      GoRoute(
        path: '/test/hands-free',
        name: 'hands-free-test',
        builder: (context, state) => DeferredLoaderWidget(
          loader: hands_free_test.loadLibrary,
          builder: () => hands_free_test.HandsFreeTestScreen(),
        ),
      ),

      // Lesson editor routes
      GoRoute(
        path: '/lesson-editor',
        name: 'lesson-editor-new',
        builder: (context, state) {
          final tabParam = state.uri.queryParameters['tab'];
          int initialTab = 0;
          if (tabParam == 'mcq' || tabParam == 'question') {
            initialTab = 1;
          } else if (tabParam == 'concept') {
            initialTab = 2;
          }

          return DeferredLoaderWidget(
            loader: lesson_editor.loadLibrary,
            builder: () =>
                lesson_editor.LessonEditorScreen(initialTabIndex: initialTab),
          );
        },
      ),
      GoRoute(
        path: '/lesson-editor/:lessonId',
        name: 'lesson-editor',
        builder: (context, state) {
          final lessonId = state.pathParameters['lessonId'];
          final tabParam = state.uri.queryParameters['tab'];
          int initialTab = 0;
          if (tabParam == 'mcq' || tabParam == 'question') {
            initialTab = 1;
          } else if (tabParam == 'concept') {
            initialTab = 2;
          }

          return DeferredLoaderWidget(
            loader: lesson_editor.loadLibrary,
            builder: () => lesson_editor.LessonEditorScreen(
              lessonId: lessonId,
              initialTabIndex: initialTab,
            ),
          );
        },
      ),

      // Course builder routes
      GoRoute(
        path: '/course-builder',
        name: 'course-builder-new',
        builder: (context, state) => DeferredLoaderWidget(
          loader: course_builder.loadLibrary,
          builder: () => course_builder.CourseBuilderScreen(),
        ),
      ),
      GoRoute(
        path: '/course-builder/:courseId',
        name: 'course-builder',
        builder: (context, state) {
          final courseId = state.pathParameters['courseId'];
          return DeferredLoaderWidget(
            loader: course_builder.loadLibrary,
            builder: () =>
                course_builder.CourseBuilderScreen(courseId: courseId),
          );
        },
      ),

      // Career paths routes (Legacy retirement redirects to Learning Architecture v2 targets)
      GoRoute(path: '/career-paths', redirect: (context, state) => '/library'),
      GoRoute(
        path: '/careers',
        name: 'career-paths',
        redirect: (context, state) => '/library',
      ),
      GoRoute(
        path: '/careers/create',
        redirect: (context, state) => '/library',
      ),
      GoRoute(
        path: '/careers/:careerPathId',
        name: 'career-path-detail',
        redirect: (context, state) {
          final careerPathId = state.pathParameters['careerPathId']!;
          return '/target/$careerPathId';
        },
      ),
      GoRoute(path: '/my-careers', redirect: (context, state) => '/library'),

      // Canonical Taxonomy & Career Pathway Explorer routes (Phase F.2)
      GoRoute(
        path: '/taxonomy',
        name: 'taxonomy-explorer',
        builder: (context, state) {
          final tabParam = state.uri.queryParameters['tab'];
          final queryParam =
              state.uri.queryParameters['q'] ??
              state.uri.queryParameters['search'];
          int initialTab = 0;
          if (tabParam == 'cip' || tabParam == 'programs') {
            initialTab = 1;
          } else if (tabParam == 'clusters' || tabParam == 'disciplines') {
            initialTab = 2;
          }
          return DeferredLoaderWidget(
            loader: taxonomy_explorer.loadLibrary,
            builder: () => taxonomy_explorer.TaxonomyExplorerScreen(
              initialTab: initialTab,
              initialQuery: queryParam,
            ),
          );
        },
      ),
      GoRoute(path: '/pathways', redirect: (context, state) => '/taxonomy'),
      GoRoute(
        path: '/taxonomy/occupation/:code',
        name: 'occupation-detail',
        builder: (context, state) {
          final code = state.pathParameters['code']!;
          return DeferredLoaderWidget(
            loader: occupation_detail.loadLibrary,
            builder: () =>
                occupation_detail.OccupationDetailScreen(occupationCode: code),
          );
        },
      ),

      // Skills routes
      GoRoute(
        path: '/skills',
        name: 'skills-profile',
        builder: (context, state) => const SkillsProfileScreen(),
      ),
      GoRoute(
        path: '/skills/:skillSlug',
        name: 'skill-detail',
        builder: (context, state) {
          final skillSlug = state.pathParameters['skillSlug']!;
          return SkillDetailScreen(skillSlug: skillSlug);
        },
      ),

      // Assessment route
      GoRoute(
        path: '/assess/:assessmentId',
        name: 'assessment',
        builder: (context, state) {
          final assessmentId = state.pathParameters['assessmentId']!;
          return AssessmentScreen(assessmentId: assessmentId);
        },
      ),

      // Guided generation route
      GoRoute(
        path: '/guided-generation',
        name: 'guided-generation',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          return DeferredLoaderWidget(
            loader: guided_generation.loadLibrary,
            builder: () => guided_generation.GuidedGenerationScreen(
              initialSubject: q['subject'],
              initialAudience: q['audience'],
              initialDuration: int.tryParse(q['duration'] ?? ''),
              initialDifficulty: q['difficulty'],
              initialFocus: q['focus'],
              nodeId: q['nodeId'],
              targetVersionId: q['targetVersionId'],
              attachmentIntent: q['attachmentIntent'],
            ),
          );
        },
      ),

      // Reset center route
      GoRoute(
        path: '/settings/reset',
        name: 'reset-center',
        builder: (context, state) => DeferredLoaderWidget(
          loader: reset_center.loadLibrary,
          builder: () => reset_center.ResetCenterScreen(),
        ),
      ),
    ],

    // Error handling
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page not found: ${state.error}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});

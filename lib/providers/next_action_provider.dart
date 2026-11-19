import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/fast_plan_result.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/models/learning_strategy.dart';
import 'package:learning_pwa/models/overview_outline.dart';
import 'package:learning_pwa/models/scope.dart';
import 'package:learning_pwa/models/spaced_repetition.dart';
import 'package:learning_pwa/providers/daily_plan_provider.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/learning_strategy_provider.dart';
import 'package:learning_pwa/providers/scope_resolver_provider.dart';
import 'package:learning_pwa/providers/target_readiness_provider.dart';
import 'package:learning_pwa/services/concept_evidence_service.dart';
import 'package:learning_pwa/services/course_service.dart';
import 'package:learning_pwa/services/learning_context_service.dart';
import 'package:learning_pwa/services/learning_context_migration.dart';
import 'package:learning_pwa/services/next_action_engine.dart';
import 'package:learning_pwa/services/planning/content_coverage_service.dart';
import 'package:learning_pwa/services/planning/learning_strategy_planner.dart';
import 'package:learning_pwa/services/saved_study_set_service.dart';
import 'package:learning_pwa/services/scope_resolver.dart';
import 'package:learning_pwa/services/spaced_repetition_service.dart';
import 'package:learning_pwa/services/hive_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_pwa/utils/uuid_validator.dart';

final courseServiceProvider = Provider<CourseService>((ref) => CourseService());

final savedStudySetServiceProvider =
    Provider<SavedStudySetService>((ref) => SavedStudySetService());

final learningContextMigrationProvider =
    Provider<LearningContextMigration>((ref) {
  return LearningContextMigration(
    contexts: ref.watch(learningContextServiceProvider),
    courses: ref.watch(courseServiceProvider),
    studySets: ref.watch(savedStudySetServiceProvider),
  );
});

/// Runs the one-time backfill, then reports whether any context exists.
///
/// Idempotent, so a repeated run after a failure is harmless.
final learningBootstrapProvider = FutureProvider<void>((ref) async {
  final userId = ref.watch(learnerIdProvider);
  try {
    final report =
        await ref.watch(learningContextMigrationProvider).runOnce(userId);
    if (report != null && report.created > 0) {
      await ref.read(learningContextsProvider.notifier).load();
    }
  } catch (e) {
    // Startup must never be blocked by migration: the learner can still add
    // a context by hand from Library.
    debugPrint('\u26a0\ufe0f Learning bootstrap skipped: $e');
  }
});

/// Turns a [LearningContext] into the value object the pure engine consumes.
///
/// All I/O lives here so [NextActionEngine] stays testable without a network,
/// a database, or a widget tree.
class ContextSnapshotResolver {
  final CourseService _courses;
  final SavedStudySetService _studySets;
  final SpacedRepetitionService _reviews;
  final LearningContextService _contexts;
  final ScopeResolver? _scopeResolver;
  final ContentCoverageService _coverageService;
  final LearningStrategyPlanner _strategyPlanner;
  final TelFeatureFlags _telFlags;
  final FastPreference Function(String contextId)? _fastPreferenceLookup;
  final ConceptEvidenceService? _conceptEvidence;

  final Future<Set<String>> Function()? _completedLessonIdsFetcher;
  final Future<List<SnapshotNode>> Function(LearningContext context)?
      _curriculumNodesFetcher;
  final Future<Map<String, EvidenceSummary>> Function(
    LearningContext context,
    ResolvedScope scope,
    ScopeCoverageBundle coverage,
  )? _domainEvidenceFetcher;

  const ContextSnapshotResolver({
    required CourseService courses,
    required SavedStudySetService studySets,
    required SpacedRepetitionService reviews,
    required LearningContextService contexts,
    ScopeResolver? scopeResolver,
    ContentCoverageService coverageService = const ContentCoverageService(),
    LearningStrategyPlanner strategyPlanner = const LearningStrategyPlanner(),
    TelFeatureFlags telFlags = const TelFeatureFlags(),
    FastPreference Function(String contextId)? fastPreferenceLookup,
    ConceptEvidenceService? conceptEvidence,
    Future<Set<String>> Function()? completedLessonIdsFetcher,
    Future<List<SnapshotNode>> Function(LearningContext context)?
        curriculumNodesFetcher,
    Future<Map<String, EvidenceSummary>> Function(
      LearningContext context,
      ResolvedScope scope,
      ScopeCoverageBundle coverage,
    )? domainEvidenceFetcher,
  })  : _courses = courses,
        _studySets = studySets,
        _reviews = reviews,
        _contexts = contexts,
        _scopeResolver = scopeResolver,
        _coverageService = coverageService,
        _strategyPlanner = strategyPlanner,
        _telFlags = telFlags,
        _fastPreferenceLookup = fastPreferenceLookup,
        _conceptEvidence = conceptEvidence,
        _completedLessonIdsFetcher = completedLessonIdsFetcher,
        _curriculumNodesFetcher = curriculumNodesFetcher,
        _domainEvidenceFetcher = domainEvidenceFetcher;

  Future<Set<String>> _getCompletedLessonIds(LearningContext context) async {
    final fetcher = _completedLessonIdsFetcher;
    if (fetcher != null) {
      return await fetcher();
    }

    final completed = <String>{};
    String? effectiveUserId = context.userId.isNotEmpty ? context.userId : null;
    if (effectiveUserId == null) {
      try {
        effectiveUserId = Supabase.instance.client.auth.currentUser?.id;
      } catch (_) {}
    }

    // 1. Check local Hive progress first (instant & offline)
    try {
      final progressList = await hiveService.getProgress();
      for (final p in progressList) {
        if (p.lessonCompleted) {
          if (effectiveUserId != null && effectiveUserId.isNotEmpty) {
            // Strict isolation for signed-in / owned contexts
            if (p.userId == effectiveUserId) {
              completed.add(p.lessonId);
            }
          } else {
            // Guest mode: only match unowned / guest rows
            if (p.userId.isEmpty ||
                p.userId == 'anonymous' ||
                p.userId == 'guest') {
              completed.add(p.lessonId);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Could not load local completed lessons: $e');
    }

    // 2. Use the latest canonical completion state, including reversals.
    try {
      if (effectiveUserId != null && isValidUuid(effectiveUserId)) {
        final rows = await Supabase.instance.client
            .from('learner_activity_progress')
            .select(
              'content_kind,content_id,version_key,reporting_date_utc,completed',
            )
            .eq('user_id', effectiveUserId)
            .order('reporting_date_utc', ascending: false)
            .limit(500);

        final seen = <String>{};
        for (final row in rows) {
          final id = row['content_id'] as String?;
          final kind = row['content_kind'] as String?;
          final version = row['version_key'] as String?;
          if (id == null || kind == null || version == null) continue;
          final key = '${kind}_${id}_$version';
          if (!seen.add(key)) continue;
          if (row['completed'] == true) completed.add(id);
        }
      }
    } catch (error) {
      debugPrint('Remote completion state unavailable: $error');
    }

    return completed;
  }

  Future<List<SnapshotNode>> _resolveCurriculumNodes(
    LearningContext context,
  ) async {
    final fetcher = _curriculumNodesFetcher;
    if (fetcher != null) {
      return await fetcher(context);
    }
    if (_scopeResolver != null) {
      try {
        return await _scopeResolver.resolveCurriculumNodes(context);
      } catch (e) {
        debugPrint('⚠️ Could not resolve curriculum nodes: $e');
      }
    }
    return const <SnapshotNode>[];
  }

  /// Resolves real domain-level learner evidence (`user_concept_state` + FSRS
  /// review history) for [context], [scope], and [coverage] while enforcing
  /// `EVIDENCE-01` (FSRS history alone never produces `independentEvidenceAvailable`).
  Future<Map<String, EvidenceSummary>> _resolveDomainEvidence({
    required LearningContext context,
    required ResolvedScope scope,
    required ScopeCoverageBundle coverage,
    required List<SnapshotNode> curriculumNodes,
    required List<ReviewableItem> dueItems,
  }) async {
    final customFetcher = _domainEvidenceFetcher;
    if (customFetcher != null) {
      return await customFetcher(context, scope, coverage);
    }

    final domainStats = <String, _DomainEvidenceAccumulator>{};
    for (final domain in coverage.officialDomains) {
      domainStats[domain.domainId] = _DomainEvidenceAccumulator(domain.domainId);
    }

    // 1. Incorporate FSRS / spaced-repetition review items by lesson -> domain mapping
    //    Per EVIDENCE-01, flashcard/term FSRS review history records hasFsrsSchedulingHistory
    //    and limitedEvidence unless backed by independent scored concept evidence.
    for (final item in dueItems) {
      if (!_belongsToContext(item, context, scope)) continue;
      if (item.totalReviews <= 0) continue;
      final lessonId = item.lessonId;
      if (lessonId == null || lessonId.isEmpty) continue;
      final record = coverage.recordsByActivityId[lessonId];
      if (record == null) continue;
      for (final domainId in record.allDomainIds) {
        final acc = domainStats[domainId];
        if (acc == null) continue;
        final isIndependentItem =
            item.contentType == ReviewableContentType.question ||
            item.contentType == ReviewableContentType.multipleChoice ||
            item.contentType == ReviewableContentType.trueFalse ||
            item.contentType == ReviewableContentType.fillInBlank ||
            item.contentType == ReviewableContentType.matching;
        if (isIndependentItem) {
          acc.practiceAttemptCount += item.totalReviews;
        } else {
          acc.hasFsrsSchedulingHistory = true;
        }
      }
    }

    // 2. Query canonical `user_concept_state` for concepts in the resolved scope
    String? effectiveUserId = context.userId.isNotEmpty ? context.userId : null;
    if (effectiveUserId == null) {
      try {
        effectiveUserId = Supabase.instance.client.auth.currentUser?.id;
      } catch (_) {}
    }

    final activeConcepts = scope.activeConceptIds;
    if (effectiveUserId != null &&
        effectiveUserId.isNotEmpty &&
        activeConcepts.isNotEmpty &&
        _conceptEvidence != null) {
      try {
        final conceptStates = await _conceptEvidence.getUserConceptStates(
          effectiveUserId,
          conceptIds: activeConcepts.toList(),
        );

        if (conceptStates.isNotEmpty) {
          final conceptDomains = await _resolveConceptDomainMap(
            conceptIds: conceptStates.keys.toSet(),
            scope: scope,
            coverage: coverage,
            curriculumNodes: curriculumNodes,
          );

          for (final entry in conceptStates.entries) {
            final state = entry.value;
            if (state.evidenceCount <= 0) continue;
            final domains = conceptDomains[entry.key];
            if (domains == null || domains.isEmpty) continue;

            for (final domainId in domains) {
              final acc = domainStats[domainId];
              if (acc == null) continue;
              acc.independentAttemptCount += state.evidenceCount;
              acc.weightedCorrect += state.weightedCorrect;
              acc.weightedTotal += state.weightedTotal;
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ Could not resolve domain concept evidence: $e');
      }
    }

    final result = <String, EvidenceSummary>{};
    for (final entry in domainStats.entries) {
      final summary = entry.value.toSummary();
      if (summary.statusLabel != EvidenceStatusLabel.notAssessed ||
          summary.hasFsrsSchedulingHistory ||
          summary.independentAttemptCount > 0) {
        result[entry.key] = summary;
      }
    }
    return result;
  }

  Future<Map<String, Set<String>>> _resolveConceptDomainMap({
    required Set<String> conceptIds,
    required ResolvedScope scope,
    required ScopeCoverageBundle coverage,
    required List<SnapshotNode> curriculumNodes,
  }) async {
    final map = <String, Set<String>>{};

    // First try direct slug/key lookup
    for (final conceptId in conceptIds) {
      final direct = _coverageService.resolveDomainForConcept(
        conceptId,
        officialDomains: coverage.officialDomains,
      );
      if (direct.isNotEmpty) {
        map.putIfAbsent(conceptId, () => <String>{}).addAll(direct);
      }
    }

    final unmapped = conceptIds.where((id) => !map.containsKey(id)).toList();
    if (unmapped.isEmpty) return map;

    try {
      final client = Supabase.instance.client;

      // Map via curriculum_node_concepts -> curriculumNodeId -> domainId
      final cncRes = await client
          .from('curriculum_node_concepts')
          .select('concept_id, curriculum_node_id')
          .inFilter('concept_id', unmapped);
      for (final row in (cncRes as List)) {
        final cId = row['concept_id'] as String?;
        final nId = row['curriculum_node_id'] as String?;
        if (cId == null || nId == null) continue;
        final domainId = _coverageService.resolveDomainForNodeId(
          nId,
          curriculumNodes: curriculumNodes,
          officialDomains: coverage.officialDomains,
        );
        if (domainId != null) {
          map.putIfAbsent(cId, () => <String>{}).add(domainId);
        }
      }

      // Map via lesson_concepts -> lessonId -> coverage.recordsByActivityId[lessonId]
      final stillUnmapped =
          unmapped.where((id) => !map.containsKey(id)).toList();
      if (stillUnmapped.isNotEmpty) {
        final lcRes = await client
            .from('lesson_concepts')
            .select('concept_id, lesson_id')
            .inFilter('concept_id', stillUnmapped);
        for (final row in (lcRes as List)) {
          final cId = row['concept_id'] as String?;
          final lId = row['lesson_id'] as String?;
          if (cId == null || lId == null) continue;
          final record = coverage.recordsByActivityId[lId];
          if (record != null && record.allDomainIds.isNotEmpty) {
            map.putIfAbsent(cId, () => <String>{}).addAll(record.allDomainIds);
          }
        }
      }

      // Map via knowledge_concepts.slug / source_id -> clepPsychConceptDomains
      final remaining = unmapped.where((id) => !map.containsKey(id)).toList();
      if (remaining.isNotEmpty) {
        final kcRes = await client
            .from('knowledge_concepts')
            .select('id, slug, source_id')
            .inFilter('id', remaining);
        for (final row in (kcRes as List)) {
          final cId = row['id'] as String?;
          if (cId == null) continue;
          final slug = row['slug'] as String?;
          final sourceId = row['source_id'] as String?;
          final bySlug = _coverageService.resolveDomainForConcept(
            slug,
            officialDomains: coverage.officialDomains,
          );
          final bySource = _coverageService.resolveDomainForConcept(
            sourceId,
            officialDomains: coverage.officialDomains,
          );
          final combined = {...bySlug, ...bySource};
          if (combined.isNotEmpty) {
            map.putIfAbsent(cId, () => <String>{}).addAll(combined);
          }
        }
      }
    } catch (_) {
      // Offline or test environment without Supabase initialized
    }

    return map;
  }

  /// Resolves the deterministic [FastPlanResult] for [context] using real
  /// curriculum node hierarchy, per-lesson completion state, and domain-level
  /// learner evidence (`TEL-04A`).
  Future<FastPlanResult?> resolveFastPlan(
    LearningContext context, {
    PersistedLearningStrategy? strategyOverride,
    Set<String>? completedLessonsOverride,
    List<ReviewableItem>? dueItemsOverride,
    ResolvedScope? scopeOverride,
  }) async {
    if (context.rootType != ContextRootType.target ||
        !_telFlags.isFastEnabledForTarget(
          context.rootId,
          isExamTarget: true,
        )) {
      return null;
    }

    final resolvedScope =
        scopeOverride ?? await _scopeResolver?.resolveScope(context);
    if (resolvedScope == null) return null;

    final completedLessons =
        completedLessonsOverride ?? await _getCompletedLessonIds(context);
    final dueItems = dueItemsOverride ?? await _safeDueItems();
    final curriculumNodes = await _resolveCurriculumNodes(context);

    // Each exam uses its own reviewed blueprint; unreviewed targets get the
    // generic course-order fallback without official coverage claims.
    final coverage = _coverageService.buildCoverageForScope(
      scope: resolvedScope,
      officialDomains: officialDomainsForTarget(context.rootId),
      curriculumNodes: curriculumNodes,
    );

    final domainEvidence = await _resolveDomainEvidence(
      context: context,
      scope: resolvedScope,
      coverage: coverage,
      curriculumNodes: curriculumNodes,
      dueItems: dueItems,
    );

    final fastPref = _fastPreferenceLookup?.call(context.id);
    final activeStrategy =
        strategyOverride ??
        fastPref?.strategy ??
        PersistedLearningStrategy.standard;

    return _strategyPlanner.plan(
      scope: resolvedScope,
      coverage: coverage,
      asOf: resolvedScope.resolvedAt,
      activeStrategy: activeStrategy,
      completedActivityIds: completedLessons,
      manualSkippedActivityIds:
          fastPref?.manualSkippedActivityIds ?? const <String>{},
      domainEvidence: domainEvidence,
      optionalTotalMinutes: fastPref?.optionalTotalMinutes,
    );
  }

  Future<ContextSnapshot> resolve(LearningContext context) async {
    final due = await _safeDueItems();
    final completedLessons = await _getCompletedLessonIds(context);
    final resume = _contexts.resumeFor(context.id);

    ResolvedScope? resolvedScope;
    if (_scopeResolver != null) {
      try {
        resolvedScope = await _scopeResolver.resolveScope(context);
      } catch (e) {
        debugPrint('⚠️ Could not resolve scope for context ${context.id}: $e');
      }
    }

    LearningActivity? next;
    String? nextActivityRationale;
    LearningActivity? resumeActivity;
    var resumeItemCount = 0;

    switch (context.rootType) {
      case ContextRootType.target:
      case ContextRootType.concept:
      case ContextRootType.module:
        if (resolvedScope != null && resolvedScope.orderedActivities.isNotEmpty) {
          final fastPref = _fastPreferenceLookup?.call(context.id);
          final useFastPlanner =
              context.rootType == ContextRootType.target &&
              _telFlags.isFastEnabledForTarget(
                context.rootId,
                isExamTarget: true,
              ) &&
              fastPref?.strategy == PersistedLearningStrategy.fast;

          if (useFastPlanner && fastPref != null) {
            final fastPlan = await resolveFastPlan(
              context,
              strategyOverride: PersistedLearningStrategy.fast,
              completedLessonsOverride: completedLessons,
              dueItemsOverride: due,
              scopeOverride: resolvedScope,
            );
            final topCandidate = fastPlan?.topRecommendedActivity;
            if (topCandidate != null) {
              final matched = resolvedScope.orderedActivities
                  .where((a) => a.activityId == topCandidate.activityId)
                  .firstOrNull;
              final index = resolvedScope.orderedActivities.indexWhere(
                (a) => a.activityId == topCandidate.activityId,
              );
              next = LessonActivity(
                lessonId: topCandidate.activityId,
                title: topCandidate.title,
                estimate: Duration(minutes: topCandidate.estimatedMinutes),
                courseId: matched?.courseId,
                courseTitle: matched?.courseTitle,
                moduleTitle: matched?.moduleTitle,
                position: index >= 0 ? index + 1 : null,
                total: resolvedScope.orderedActivities.length,
              );
              nextActivityRationale = topCandidate.userFacingRationale;
            }
          } else {
            // Standard mode: Incomplete required official lessons outrank unfinished personal lessons
            final incompleteOfficial = resolvedScope.orderedActivities.where(
              (a) =>
                  a.source == ScopedActivitySource.official &&
                  a.isRequired &&
                  !completedLessons.contains(a.activityId),
            );

            final candidate = incompleteOfficial.isNotEmpty
                ? incompleteOfficial.first
                : resolvedScope.orderedActivities
                    .where((a) => !completedLessons.contains(a.activityId))
                    .firstOrNull;

            if (candidate != null) {
              final index = resolvedScope.orderedActivities
                  .indexWhere((a) => a.activityId == candidate.activityId);
              next = LessonActivity(
                lessonId: candidate.activityId,
                title: candidate.title,
                courseId: candidate.courseId,
                courseTitle: candidate.courseTitle,
                moduleTitle: candidate.moduleTitle,
                position: index >= 0 ? index + 1 : null,
                total: resolvedScope.orderedActivities.length,
              );
            } else {
              next = null;
            }
          }
          resumeActivity = _lessonFromPointer(resume);
          resumeItemCount = 0;
        } else {
          // If this is a course or path, fall through to course activity lookup;
          // for targets, concepts, or modules without orderedActivities, do not call course lookup.
          if (context.rootType == ContextRootType.course || context.rootType == ContextRootType.path) {
            final resolved = await _resolveCourseActivity(context, completedLessons);
            next = resolved.next;
            resumeActivity = resolved.resume ?? _lessonFromPointer(resume);
            resumeItemCount = resolved.resumeItemCount;
          } else {
            next = null;
            resumeActivity = _lessonFromPointer(resume);
            resumeItemCount = 0;
          }
        }
        break;

      case ContextRootType.path:
      case ContextRootType.course:
        final resolved = await _resolveCourseActivity(context, completedLessons);
        next = resolved.next;
        resumeActivity = resolved.resume ?? _lessonFromPointer(resume);
        resumeItemCount = resolved.resumeItemCount;
        break;

      case ContextRootType.lesson:
        final isCompleted = completedLessons.contains(context.rootId);
        next = isCompleted
            ? null
            : LessonActivity(lessonId: context.rootId, title: context.label);
        resumeActivity = _lessonFromPointer(resume);
        resumeItemCount = _itemCountForLesson(due, context.rootId);
        break;

      case ContextRootType.studySet:
        // Practice is repeatable, so a study set never runs out of material.
        next = await _resolveStudySetActivity(context, due);
        resumeActivity = resume?.kind == ResumableKind.studySet
            ? next
            : _lessonFromPointer(resume);
        resumeItemCount =
            next is StudySetActivity ? next.itemCount : 0;
        break;
    }

    final scopedDue = due
        .where((i) => _belongsToContext(i, context, resolvedScope))
        .toList();
    final dueIds = scopedDue.map((i) => i.contentId).toList();

    final totalActivityCount = resolvedScope?.orderedActivities.length ?? 0;
    final officialRequired = resolvedScope?.orderedActivities
            .where((a) => a.source == ScopedActivitySource.official && a.isRequired)
            .toList() ??
        const [];
    final officialRequiredCount = officialRequired.length;
    final completedOfficialRequiredCount = officialRequired
        .where((a) => completedLessons.contains(a.activityId))
        .length;

    return ContextSnapshot(
      context: context,
      resume: resume,
      resumeActivity: resumeActivity,
      resumeItemCount: resumeItemCount,
      nextActivity: next,
      nextActivityRationale: nextActivityRationale,
      dueConceptIds: dueIds,
      strugglingConceptIds: _struggling(scopedDue),
      forwardOffer: next == null ? ForwardOffer.browse : null,
      totalActivityCount: totalActivityCount,
      officialRequiredCount: officialRequiredCount,
      completedOfficialRequiredCount: completedOfficialRequiredCount,
    );
  }

  Future<({LearningActivity? next, LearningActivity? resume, int resumeItemCount})>
      _resolveCourseActivity(
    LearningContext context,
    Set<String> completedLessons,
  ) async {
    if (context.rootId == 'foundational-literacy' || !isValidUuid(context.rootId)) {
      return (
        next: LessonActivity(
          lessonId: 'literacy',
          title: context.label,
          courseId: context.rootId,
          courseTitle: context.label,
        ),
        resume: null,
        resumeItemCount: 0,
      );
    }

    try {
      final content = await _courses.getCourseWithContent(context.rootId);
      final lessons = content.orderedLessons;
      if (lessons.isEmpty) {
        return (next: null, resume: null, resumeItemCount: 0);
      }

      final nextLesson = lessons.where((l) => !completedLessons.contains(l.id));
      final index = lessons.indexWhere((l) => !completedLessons.contains(l.id));

      final next = nextLesson.isEmpty
          ? null
          : LessonActivity(
              lessonId: nextLesson.first.id,
              title: nextLesson.first.title,
              courseId: content.course.id,
              courseTitle: content.course.title,
              position: index + 1,
              total: lessons.length,
            );

      return (next: next, resume: null, resumeItemCount: 0);
    } catch (e) {
      // A course that will not load must not strand the learner on a blank
      // screen — fall through to the exhausted branch, which always offers
      // a way onward.
      debugPrint('⚠️ Could not resolve course ${context.rootId}: $e');
      return (next: null, resume: null, resumeItemCount: 0);
    }
  }

  Future<LearningActivity?> _resolveStudySetActivity(
    LearningContext context,
    List<ReviewableItem> due,
  ) async {
    try {
      final set = await _studySets.getStudySet(context.rootId);
      final dueInSet = due
          .where((i) => set.lessonIds.contains(i.lessonId))
          .length;
      return StudySetActivity(
        studySetId: set.id,
        title: set.title,
        itemCount: dueInSet > 0 ? dueInSet : set.totalItems,
        isDueSubset: dueInSet > 0,
      );
    } catch (e) {
      debugPrint('⚠️ Could not resolve study set ${context.rootId}: $e');
      // Still offer practice: the set exists even if its metadata failed.
      return StudySetActivity(
        studySetId: context.rootId,
        title: context.label,
        itemCount: 0,
      );
    }
  }

  LearningActivity? _lessonFromPointer(ResumePointer? resume) {
    if (resume == null || resume.kind != ResumableKind.lesson) return null;
    return LessonActivity(
      lessonId: resume.activityId,
      title: 'Continue',
    );
  }

  int _itemCountForLesson(List<ReviewableItem> items, String lessonId) {
    return items.where((i) => i.lessonId == lessonId).length;
  }

  bool _belongsToContext(
    ReviewableItem item,
    LearningContext context, [
    ResolvedScope? scope,
  ]) {
    if (scope != null) {
      return scope.includesItem(
        contentId: item.contentId,
        lessonId: item.lessonId,
      );
    }
    if (context.rootType == ContextRootType.lesson) {
      return item.lessonId == context.rootId;
    }
    // Fail closed: un-scoped items never leak into contextual review queues
    return false;
  }

  List<String> _struggling(List<ReviewableItem> items) {
    return items
        .where((i) => i.totalReviews >= 2 && i.accuracy < 0.6)
        .map((i) => i.contentId)
        .toList();
  }

  Future<List<ReviewableItem>> _safeDueItems() async {
    try {
      return await _reviews.getDueItems();
    } catch (e) {
      // Offline or signed out: an empty due list is correct-enough and lets
      // the engine keep resolving forward progress.
      debugPrint('⚠️ Could not load due items: $e');
      return const [];
    }
  }
}

final contextSnapshotResolverProvider = Provider<ContextSnapshotResolver>((ref) {
  final strategyState = ref.watch(learningStrategyProvider);
  final store = ref.watch(fastPreferenceStoreProvider);
  final userId = ref.watch(learnerIdProvider);
  return ContextSnapshotResolver(
    courses: ref.watch(courseServiceProvider),
    studySets: ref.watch(savedStudySetServiceProvider),
    reviews: ref.watch(spacedRepetitionServiceProvider),
    contexts: ref.watch(learningContextServiceProvider),
    scopeResolver: ref.watch(scopeResolverProvider),
    coverageService: ref.watch(contentCoverageServiceProvider),
    strategyPlanner: ref.watch(learningStrategyPlannerProvider),
    telFlags: ref.watch(telFeatureFlagsProvider),
    conceptEvidence: ref.watch(conceptEvidenceServiceProvider),
    fastPreferenceLookup: (contextId) =>
        strategyState.preferencesByContextId[contextId] ??
        store.getOrDefault(contextId: contextId, userId: userId),
  );
});

class _DomainEvidenceAccumulator {
  final String domainId;
  int independentAttemptCount = 0;
  int practiceAttemptCount = 0;
  double weightedCorrect = 0.0;
  double weightedTotal = 0.0;
  bool hasFsrsSchedulingHistory = false;

  _DomainEvidenceAccumulator(this.domainId);

  EvidenceSummary toSummary() {
    if (independentAttemptCount > 0 && weightedTotal > 0) {
      final score = (weightedCorrect / weightedTotal).clamp(0.0, 1.0);
      final status = (independentAttemptCount >= 2 || score < 0.75)
          ? EvidenceStatusLabel.independentEvidenceAvailable
          : EvidenceStatusLabel.practiceEvidenceAvailable;
      return EvidenceSummary(
        subjectKey: domainId,
        statusLabel: status,
        independentAttemptCount: independentAttemptCount,
        independentScore: score,
        hasFsrsSchedulingHistory: hasFsrsSchedulingHistory,
      );
    }

    if (practiceAttemptCount > 0) {
      return EvidenceSummary(
        subjectKey: domainId,
        statusLabel: EvidenceStatusLabel.practiceEvidenceAvailable,
        independentAttemptCount: 0,
        hasFsrsSchedulingHistory: hasFsrsSchedulingHistory,
      );
    }

    if (hasFsrsSchedulingHistory) {
      return EvidenceSummary(
        subjectKey: domainId,
        statusLabel: EvidenceStatusLabel.limitedEvidence,
        independentAttemptCount: 0,
        hasFsrsSchedulingHistory: true,
      );
    }

    return EvidenceSummary(subjectKey: domainId);
  }
}

/// The single primary action rendered by the Learn screen.
final nextActionProvider = FutureProvider<NextAction>((ref) async {
  final state = ref.watch(learningContextsProvider);
  final engine = ref.watch(nextActionEngineProvider);
  final active = state.active;

  if (active == null) {
    return const ChooseSomething();
  }

  try {
    final snapshot =
        await ref.watch(contextSnapshotResolverProvider).resolve(active);
    final emphasis = ref.watch(reviewEmphasisProvider);
    final dailyPlan = await ref.watch(dailyPlanProvider.future);
    return engine.resolve(
      contexts: state.contexts,
      active: snapshot,
      reviewEmphasis: emphasis,
      dailyPlan: dailyPlan,
    );
  } catch (e, stack) {
    debugPrint('❌ Next action resolution failed: $e\n$stack');
    // Never leave Learn without an action: browsing is always valid.
    return const ContextComplete(offer: ForwardOffer.browse);
  }
});

/// Due count for the active context, used by the secondary review prompt.
final activeDueCountProvider = FutureProvider<int>((ref) async {
  final active = ref.watch(activeLearningContextProvider);
  if (active == null) return 0;
  try {
    final snapshot =
        await ref.watch(contextSnapshotResolverProvider).resolve(active);
    return snapshot.dueCount;
  } catch (_) {
    return 0;
  }
});

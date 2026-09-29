import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/learning_context.dart';
import '../models/scope.dart';

/// Resolves the bounded learning scope and deterministic activity sequence
/// for any active [LearningContext] per Learning Architecture v2 §7.
class ScopeResolver {
  final SupabaseClient? _supabase;
  final Box<ResolvedScope>? _scopeBox;
  final Box<ContextCurriculumSnapshot>? _snapshotBox;

  ScopeResolver({
    SupabaseClient? supabase,
    Box<ResolvedScope>? scopeBox,
    Box<ContextCurriculumSnapshot>? snapshotBox,
  })  : _supabase = supabase,
        _scopeBox = scopeBox,
        _snapshotBox = snapshotBox;

  static const Duration defaultCacheTtl = Duration(hours: 4);

  static String computeConfigHash(LearningContext context) {
    return '${context.targetVersionId ?? ''}:${context.scopeMode.name}:${context.activeFocusId ?? ''}:${context.scopeConfig.toString()}';
  }

  /// Resolves the complete scope for the given context.
  /// Uses a stale-while-revalidate policy with TTL and context configuration hashing
  /// per Learning Architecture v2 §7.4:
  /// - If fresh cache exists and config matches: returns instantly.
  /// - If stale cache exists and config matches: returns immediately for instant UI
  ///   while initiating a background refresh.
  /// - If config changed or forceRefresh: fetches fresh remote scope.
  /// - Falls back to local Hive cache if offline or on network failure.
  Future<ResolvedScope> resolveScope(
    LearningContext context, {
    bool forceRefresh = false,
    Duration? cacheTtl,
  }) async {
    final configHash = computeConfigHash(context);
    final ttl = cacheTtl ?? defaultCacheTtl;

    // 1. Try local cache first if not forced
    if (!forceRefresh && _scopeBox != null && _scopeBox.containsKey(context.id)) {
      final cached = _scopeBox.get(context.id);
      if (cached != null) {
        final isConfigMatch =
            cached.configHash == null || cached.configHash == configHash;
        final isFresh = DateTime.now().difference(cached.resolvedAt) < ttl;

        if (isConfigMatch) {
          if (isFresh) {
            return cached;
          } else {
            // Stale-while-revalidate: return cached immediately, trigger remote check in background
            _revalidateInBackground(context, configHash);
            return cached;
          }
        }
      }
    }

    try {
      final resolved = await _resolveOnline(context, configHash: configHash);
      // Cache resolved scope
      if (_scopeBox != null) {
        await _scopeBox.put(context.id, resolved);
      }
      return resolved;
    } catch (e) {
      debugPrint('⚠️ ScopeResolver online resolution failed: $e');
      // If cached copy exists, return it despite error
      if (_scopeBox != null && _scopeBox.containsKey(context.id)) {
        final cached = _scopeBox.get(context.id);
        if (cached != null) return cached;
      }

      // Minimal safe fallback
      return ResolvedScope(
        contextId: context.id,
        resolvedAt: DateTime.now(),
        configHash: configHash,
      );
    }
  }

  void _revalidateInBackground(LearningContext context, String configHash) {
    _resolveOnline(context, configHash: configHash).then((fresh) async {
      if (_scopeBox != null) {
        await _scopeBox.put(context.id, fresh);
      }
    }).catchError((e) {
      debugPrint('⚠️ Background ScopeResolver revalidation failed: $e');
    });
  }

  Future<ResolvedScope> _resolveOnline(
    LearningContext context, {
    String? configHash,
  }) async {
    final client = _supabase;
    if (client == null) {
      return ResolvedScope(
        contextId: context.id,
        resolvedAt: DateTime.now(),
        configHash: configHash,
      );
    }

    final ResolvedScope raw;
    switch (context.rootType) {
      case ContextRootType.target:
        raw = await _resolveTargetScope(context, client);
        break;
      case ContextRootType.concept:
        raw = await _resolveConceptScope(context, client);
        break;
      case ContextRootType.course:
        raw = await _resolveCourseScope(context, client);
        break;
      case ContextRootType.module:
        raw = await _resolveModuleScope(context, client);
        break;
      case ContextRootType.lesson:
        raw = await _resolveLessonScope(context, client);
        break;
      case ContextRootType.studySet:
        raw = await _resolveStudySetScope(context, client);
        break;
      case ContextRootType.path:
        // Legacy path maps to course resolution
        raw = await _resolveCourseScope(context, client);
        break;
    }

    return ResolvedScope(
      contextId: raw.contextId,
      coreConceptIds: raw.coreConceptIds,
      supportingConceptIds: raw.supportingConceptIds,
      relatedConceptIds: raw.relatedConceptIds,
      curriculumNodeIds: raw.curriculumNodeIds,
      orderedActivities: raw.orderedActivities,
      questionIds: raw.questionIds,
      termIds: raw.termIds,
      flashcardIds: raw.flashcardIds,
      resolvedAt: DateTime.now(),
      configHash: configHash ?? computeConfigHash(context),
    );
  }

  // ==========================================================================
  // TARGET RESOLUTION (§7.3.1)
  // ==========================================================================
  Future<ResolvedScope> _resolveTargetScope(
    LearningContext context,
    SupabaseClient client,
  ) async {
    String? versionId = context.targetVersionId;

    // If no version specified, resolve latest published version for the target
    if (versionId == null) {
      final verRes = await client
          .from('target_versions')
          .select('id')
          .eq('target_id', context.rootId)
          .eq('status', 'published')
          .order('created_at', ascending: false)
          .limit(1);

      if ((verRes as List).isNotEmpty) {
        versionId = verRes.first['id'] as String;
      }
    }

    if (versionId == null) {
      return ResolvedScope(
        contextId: context.id,
        resolvedAt: DateTime.now(),
      );
    }

    // 1. Load curriculum nodes
    final nodesRes = await client
        .from('curriculum_nodes')
        .select('*')
        .eq('target_version_id', versionId)
        .order('sort_order');

    final nodesList = (nodesRes as List).cast<Map<String, dynamic>>();
    final nodeIds = nodesList.map((n) => n['id'] as String).toSet();

    // Cache snapshot for instant offline outline
    if (_snapshotBox != null) {
      final snapshotNodes = nodesList
          .map((n) => SnapshotNode(
                id: n['id'] as String,
                parentId: n['parent_id'] as String?,
                title: n['title'] as String? ?? '',
                code: n['code'] as String?,
                nodeType: n['node_type'] as String? ?? 'domain',
                sortOrder: (n['sort_order'] as num?)?.toInt() ?? 0,
              ))
          .toList();

      await _snapshotBox.put(
        context.id,
        ContextCurriculumSnapshot(
          contextId: context.id,
          targetVersionId: versionId,
          nodes: snapshotNodes,
          activeFocusId: context.activeFocusId,
          snapshotAt: DateTime.now(),
        ),
      );
    }

    // Filter nodes by active focus if set
    final activeNodeIds = <String>{};
    if (context.activeFocusId != null && nodeIds.contains(context.activeFocusId)) {
      _collectDescendantNodeIds(context.activeFocusId!, nodesList, activeNodeIds);
    } else {
      activeNodeIds.addAll(nodeIds);
    }

    // 2. Query core concepts mapped to active curriculum nodes
    final nodeConceptsRes = await client
        .from('curriculum_node_concepts')
        .select('concept_id, relevance')
        .inFilter('curriculum_node_id', activeNodeIds.toList());

    final coreConceptIds = <String>{};
    final relatedConceptIds = <String>{};

    for (final nc in (nodeConceptsRes as List)) {
      final cId = nc['concept_id'] as String;
      final rel = nc['relevance'] as String? ?? 'core';
      if (rel == 'core') {
        coreConceptIds.add(cId);
      } else if (rel == 'related') {
        relatedConceptIds.add(cId);
      } else {
        coreConceptIds.add(cId);
      }
    }

    // 3. Bounded prerequisite traversal (Loop termination + maxDepth)
    final supportingConceptIds = <String>{};
    if (context.scopeMode != ScopeMode.coreOnly && coreConceptIds.isNotEmpty) {
      final maxDepth = (context.scopeConfig['maxPrereqDepth'] as num?)?.toInt() ?? 1;
      await _traversePrerequisites(
        client,
        coreConceptIds,
        supportingConceptIds,
        maxDepth: maxDepth,
      );
    }

    // 4. Resolve teaching activities via explicit bindings
    final orderedActivities = await _resolveCurriculumActivities(
      client,
      activeNodeIds,
      nodesList,
    );

    // 5. Resolve practice items mapped to core and supporting concepts
    final allConceptIds = {...coreConceptIds, ...supportingConceptIds};
    final questionIds = <String>{};
    final termIds = <String>{};
    final flashcardIds = <String>{};

    if (allConceptIds.isNotEmpty) {
      final qRes = await client
          .from('question_concepts')
          .select('question_id')
          .inFilter('concept_id', allConceptIds.toList());
      for (final r in (qRes as List)) {
        questionIds.add(r['question_id'] as String);
      }

      final tRes = await client
          .from('term_concepts')
          .select('term_id')
          .inFilter('concept_id', allConceptIds.toList());
      for (final r in (tRes as List)) {
        termIds.add(r['term_id'] as String);
      }

      final fRes = await client
          .from('flashcard_concepts')
          .select('flashcard_id')
          .inFilter('concept_id', allConceptIds.toList());
      for (final r in (fRes as List)) {
        flashcardIds.add(r['flashcard_id'] as String);
      }
    }

    return ResolvedScope(
      contextId: context.id,
      coreConceptIds: coreConceptIds,
      supportingConceptIds: supportingConceptIds,
      relatedConceptIds: relatedConceptIds,
      curriculumNodeIds: activeNodeIds,
      orderedActivities: orderedActivities,
      questionIds: questionIds,
      termIds: termIds,
      flashcardIds: flashcardIds,
      resolvedAt: DateTime.now(),
    );
  }

  // ==========================================================================
  // CONCEPT RESOLUTION (§7.3.2)
  // ==========================================================================
  Future<ResolvedScope> _resolveConceptScope(
    LearningContext context,
    SupabaseClient client,
  ) async {
    final coreConceptIds = {context.rootId};
    final supportingConceptIds = <String>{};

    // Immediate required prerequisites (depth = 1)
    await _traversePrerequisites(
      client,
      coreConceptIds,
      supportingConceptIds,
      maxDepth: 1,
    );

    // Instructional sequence: check selectedLessonId in scopeConfig
    final selectedLessonId = context.scopeConfig['selectedLessonId'] as String?;
    final orderedActivities = <ScopedLearningActivity>[];

    if (selectedLessonId != null) {
      final lessonRes = await client
          .from('lessons')
          .select('id, title')
          .eq('id', selectedLessonId)
          .maybeSingle();

      if (lessonRes != null) {
        orderedActivities.add(
          ScopedLearningActivity(
            activityId: lessonRes['id'] as String,
            kind: ScopedActivityKind.lesson,
            title: lessonRes['title'] as String? ?? 'Lesson',
            role: ScopeRole.core,
          ),
        );
      }
    } else {
      // Find candidate lessons mapped to this concept
      final mappedRes = await client
          .from('lesson_concepts')
          .select('lesson_id, lessons(id, title)')
          .eq('concept_id', context.rootId)
          .eq('role', 'primary')
          .order('sort_order');

      for (final m in (mappedRes as List)) {
        final lesson = m['lessons'] as Map<String, dynamic>?;
        if (lesson != null) {
          orderedActivities.add(
            ScopedLearningActivity(
              activityId: lesson['id'] as String,
              kind: ScopedActivityKind.lesson,
              title: lesson['title'] as String? ?? 'Lesson',
              role: ScopeRole.core,
            ),
          );
        }
      }
    }

    // Resolve practice items
    final allConceptIds = {...coreConceptIds, ...supportingConceptIds};
    final questionIds = <String>{};
    final termIds = <String>{};
    final flashcardIds = <String>{};

    if (allConceptIds.isNotEmpty) {
      final qRes = await client
          .from('question_concepts')
          .select('question_id')
          .inFilter('concept_id', allConceptIds.toList());
      for (final r in (qRes as List)) {
        questionIds.add(r['question_id'] as String);
      }

      final tRes = await client
          .from('term_concepts')
          .select('term_id')
          .inFilter('concept_id', allConceptIds.toList());
      for (final r in (tRes as List)) {
        termIds.add(r['term_id'] as String);
      }

      final fRes = await client
          .from('flashcard_concepts')
          .select('flashcard_id')
          .inFilter('concept_id', allConceptIds.toList());
      for (final r in (fRes as List)) {
        flashcardIds.add(r['flashcard_id'] as String);
      }
    }

    return ResolvedScope(
      contextId: context.id,
      coreConceptIds: coreConceptIds,
      supportingConceptIds: supportingConceptIds,
      orderedActivities: orderedActivities,
      questionIds: questionIds,
      termIds: termIds,
      flashcardIds: flashcardIds,
      resolvedAt: DateTime.now(),
    );
  }

  // ==========================================================================
  // COURSE / MODULE / LESSON / STUDY SET RESOLUTION (§7.3.3 & §7.3.4)
  // ==========================================================================
  Future<ResolvedScope> _resolveCourseScope(
    LearningContext context,
    SupabaseClient client,
  ) async {
    final clRes = await client
        .from('course_lessons')
        .select('order_index, lessons(id, title)')
        .eq('course_id', context.rootId)
        .order('order_index');

    final orderedActivities = <ScopedLearningActivity>[];
    final lessonIds = <String>[];

    for (final cl in (clRes as List)) {
      final lesson = cl['lessons'] as Map<String, dynamic>?;
      if (lesson != null) {
        final lid = lesson['id'] as String;
        lessonIds.add(lid);
        orderedActivities.add(
          ScopedLearningActivity(
            activityId: lid,
            kind: ScopedActivityKind.lesson,
            title: lesson['title'] as String? ?? 'Lesson',
            activityOrder: (cl['order_index'] as num?)?.toInt() ?? 0,
            courseId: context.rootId,
            courseTitle: context.label,
          ),
        );
      }
    }

    return _buildScopeFromLessons(context.id, lessonIds, orderedActivities, client);
  }

  Future<ResolvedScope> _resolveModuleScope(
    LearningContext context,
    SupabaseClient client,
  ) async {
    final clRes = await client
        .from('course_lessons')
        .select('order_index, lessons(id, title)')
        .eq('module_id', context.rootId)
        .order('order_index');

    final orderedActivities = <ScopedLearningActivity>[];
    final lessonIds = <String>[];

    for (final cl in (clRes as List)) {
      final lesson = cl['lessons'] as Map<String, dynamic>?;
      if (lesson != null) {
        final lid = lesson['id'] as String;
        lessonIds.add(lid);
        orderedActivities.add(
          ScopedLearningActivity(
            activityId: lid,
            kind: ScopedActivityKind.lesson,
            title: lesson['title'] as String? ?? 'Lesson',
            activityOrder: (cl['order_index'] as num?)?.toInt() ?? 0,
            moduleId: context.rootId,
            moduleTitle: context.label,
          ),
        );
      }
    }

    return _buildScopeFromLessons(context.id, lessonIds, orderedActivities, client);
  }

  Future<ResolvedScope> _resolveLessonScope(
    LearningContext context,
    SupabaseClient client,
  ) async {
    final lessonIds = [context.rootId];
    final orderedActivities = [
      ScopedLearningActivity(
        activityId: context.rootId,
        kind: ScopedActivityKind.lesson,
        title: context.label,
      ),
    ];

    return _buildScopeFromLessons(context.id, lessonIds, orderedActivities, client);
  }

  Future<ResolvedScope> _resolveStudySetScope(
    LearningContext context,
    SupabaseClient client,
  ) async {
    final setRes = await client
        .from('study_sets')
        .select('id, title, question_ids, term_ids')
        .eq('id', context.rootId)
        .maybeSingle();

    final qIds = (setRes?['question_ids'] as List?)?.map((e) => e.toString()).toSet() ?? const {};
    final tIds = (setRes?['term_ids'] as List?)?.map((e) => e.toString()).toSet() ?? const {};

    // Also load any flashcards attached to study set
    final fcRes = await client
        .from('study_set_flashcards')
        .select('flashcard_id')
        .eq('study_set_id', context.rootId);

    final fIds = (fcRes as List).map((f) => f['flashcard_id'] as String).toSet();

    return ResolvedScope(
      contextId: context.id,
      orderedActivities: [
        ScopedLearningActivity(
          activityId: context.rootId,
          kind: ScopedActivityKind.studySet,
          title: context.label,
        ),
      ],
      questionIds: qIds,
      termIds: tIds,
      flashcardIds: fIds,
      resolvedAt: DateTime.now(),
    );
  }

  // ==========================================================================
  // HELPER METHODS: PREREQUISITES & CURRICULUM SEQUENCING
  // ==========================================================================
  Future<void> _traversePrerequisites(
    SupabaseClient client,
    Set<String> startConceptIds,
    Set<String> outSupporting, {
    required int maxDepth,
  }) async {
    final visited = <String>{...startConceptIds};
    var currentLevel = Set<String>.from(startConceptIds);

    for (int depth = 0; depth < maxDepth; depth++) {
      if (currentLevel.isEmpty) break;

      final relRes = await client
          .from('concept_relations')
          .select('from_concept_id')
          .inFilter('to_concept_id', currentLevel.toList())
          .eq('relation_type', 'prerequisite')
          .eq('auto_include', true);

      final nextLevel = <String>{};
      for (final r in (relRes as List)) {
        final prereqId = r['from_concept_id'] as String;
        if (!visited.contains(prereqId)) {
          visited.add(prereqId);
          outSupporting.add(prereqId);
          nextLevel.add(prereqId);
        }
      }
      currentLevel = nextLevel;
    }
  }

  Future<List<ScopedLearningActivity>> _resolveCurriculumActivities(
    SupabaseClient client,
    Set<String> activeNodeIds,
    List<Map<String, dynamic>> nodesList,
  ) async {
    final nodeOrderMap = {
      for (final n in nodesList) n['id'] as String: (n['sort_order'] as num?)?.toInt() ?? 0
    };

    final rawCandidates = <_ActivityCandidate>[];

    // 1. Direct Lesson Bindings (Precedence 1)
    final lessonBindingsRes = await client
        .from('curriculum_node_lessons')
        .select('curriculum_node_id, sort_order, lessons(id, title)')
        .inFilter('curriculum_node_id', activeNodeIds.toList());

    for (final lb in (lessonBindingsRes as List)) {
      final lesson = lb['lessons'] as Map<String, dynamic>?;
      if (lesson != null) {
        final nId = lb['curriculum_node_id'] as String;
        rawCandidates.add(
          _ActivityCandidate(
            lessonId: lesson['id'] as String,
            title: lesson['title'] as String? ?? 'Lesson',
            nodeId: nId,
            nodeOrder: nodeOrderMap[nId] ?? 0,
            bindingOrder: (lb['sort_order'] as num?)?.toInt() ?? 0,
            courseLessonOrder: 0,
            isDirectBinding: true,
          ),
        );
      }
    }

    // 2. Module Bindings
    final moduleBindingsRes = await client
        .from('curriculum_node_modules')
        .select('curriculum_node_id, sort_order, module_id')
        .inFilter('curriculum_node_id', activeNodeIds.toList());

    if ((moduleBindingsRes as List).isNotEmpty) {
      final moduleIds = moduleBindingsRes.map((m) => m['module_id'] as String).toList();
      final modLessonsRes = await client
          .from('course_lessons')
          .select('module_id, order_index, lessons(id, title)')
          .inFilter('module_id', moduleIds);

      for (final mb in moduleBindingsRes) {
        final mId = mb['module_id'] as String;
        final nId = mb['curriculum_node_id'] as String;
        final matching = (modLessonsRes as List).where((ml) => ml['module_id'] == mId);

        for (final ml in matching) {
          final lesson = ml['lessons'] as Map<String, dynamic>?;
          if (lesson != null) {
            rawCandidates.add(
              _ActivityCandidate(
                lessonId: lesson['id'] as String,
                title: lesson['title'] as String? ?? 'Lesson',
                nodeId: nId,
                nodeOrder: nodeOrderMap[nId] ?? 0,
                bindingOrder: (mb['sort_order'] as num?)?.toInt() ?? 0,
                courseLessonOrder: (ml['order_index'] as num?)?.toInt() ?? 0,
                isDirectBinding: false,
              ),
            );
          }
        }
      }
    }

    // 3. Course Bindings
    final courseBindingsRes = await client
        .from('curriculum_node_courses')
        .select('curriculum_node_id, sort_order, course_id')
        .inFilter('curriculum_node_id', activeNodeIds.toList());

    if ((courseBindingsRes as List).isNotEmpty) {
      final courseIds = courseBindingsRes.map((c) => c['course_id'] as String).toList();
      final courseLessonsRes = await client
          .from('course_lessons')
          .select('course_id, order_index, lessons(id, title)')
          .inFilter('course_id', courseIds);

      for (final cb in courseBindingsRes) {
        final cId = cb['course_id'] as String;
        final nId = cb['curriculum_node_id'] as String;
        final matching = (courseLessonsRes as List).where((cl) => cl['course_id'] == cId);

        for (final cl in matching) {
          final lesson = cl['lessons'] as Map<String, dynamic>?;
          if (lesson != null) {
            rawCandidates.add(
              _ActivityCandidate(
                lessonId: lesson['id'] as String,
                title: lesson['title'] as String? ?? 'Lesson',
                nodeId: nId,
                nodeOrder: nodeOrderMap[nId] ?? 0,
                bindingOrder: (cb['sort_order'] as num?)?.toInt() ?? 0,
                courseLessonOrder: (cl['order_index'] as num?)?.toInt() ?? 0,
                isDirectBinding: false,
              ),
            );
          }
        }
      }
    }

    // Sort candidates according to §7.2
    rawCandidates.sort((a, b) {
      // 1. Curriculum node order
      final nodeCmp = a.nodeOrder.compareTo(b.nodeOrder);
      if (nodeCmp != 0) return nodeCmp;

      // 2. Direct bindings take precedence over inherited course/module
      if (a.isDirectBinding && !b.isDirectBinding) return -1;
      if (!a.isDirectBinding && b.isDirectBinding) return 1;

      // 3. Binding sort order
      final bindingCmp = a.bindingOrder.compareTo(b.bindingOrder);
      if (bindingCmp != 0) return bindingCmp;

      // 4. course_lessons order index
      return a.courseLessonOrder.compareTo(b.courseLessonOrder);
    });

    // Deduplication rule (§7.2): First occurrence in explicitly ordered sequence wins
    final seenLessons = <String>{};
    final orderedActivities = <ScopedLearningActivity>[];

    for (final cand in rawCandidates) {
      if (!seenLessons.contains(cand.lessonId)) {
        seenLessons.add(cand.lessonId);
        orderedActivities.add(
          ScopedLearningActivity(
            activityId: cand.lessonId,
            kind: ScopedActivityKind.lesson,
            curriculumNodeId: cand.nodeId,
            curriculumOrder: cand.nodeOrder,
            activityOrder: cand.courseLessonOrder,
            role: ScopeRole.core,
            title: cand.title,
          ),
        );
      }
    }

    return orderedActivities;
  }

  Future<ResolvedScope> _buildScopeFromLessons(
    String contextId,
    List<String> lessonIds,
    List<ScopedLearningActivity> orderedActivities,
    SupabaseClient client,
  ) async {
    final coreConceptIds = <String>{};
    final questionIds = <String>{};
    final termIds = <String>{};

    if (lessonIds.isNotEmpty) {
      final lcRes = await client
          .from('lesson_concepts')
          .select('concept_id')
          .inFilter('lesson_id', lessonIds);

      for (final lc in (lcRes as List)) {
        coreConceptIds.add(lc['concept_id'] as String);
      }

      final qRes = await client
          .from('questions')
          .select('id')
          .inFilter('lesson_id', lessonIds);
      for (final q in (qRes as List)) {
        questionIds.add(q['id'] as String);
      }

      final tRes = await client
          .from('terms')
          .select('id')
          .inFilter('lesson_id', lessonIds);
      for (final t in (tRes as List)) {
        termIds.add(t['id'] as String);
      }
    }

    return ResolvedScope(
      contextId: contextId,
      coreConceptIds: coreConceptIds,
      orderedActivities: orderedActivities,
      questionIds: questionIds,
      termIds: termIds,
      resolvedAt: DateTime.now(),
    );
  }

  void _collectDescendantNodeIds(
    String parentId,
    List<Map<String, dynamic>> nodesList,
    Set<String> outIds,
  ) {
    outIds.add(parentId);
    for (final n in nodesList) {
      if (n['parent_id'] == parentId) {
        _collectDescendantNodeIds(n['id'] as String, nodesList, outIds);
      }
    }
  }
}

class _ActivityCandidate {
  final String lessonId;
  final String title;
  final String nodeId;
  final int nodeOrder;
  final int bindingOrder;
  final int courseLessonOrder;
  final bool isDirectBinding;

  _ActivityCandidate({
    required this.lessonId,
    required this.title,
    required this.nodeId,
    required this.nodeOrder,
    required this.bindingOrder,
    required this.courseLessonOrder,
    required this.isDirectBinding,
  });
}

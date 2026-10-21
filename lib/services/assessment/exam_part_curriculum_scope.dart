import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/assessment_engine/exam_reference_manifest.dart';

/// A validated subtree for a single configured exam part of ONE target version.
/// This is a curriculum scope, not a verified official exam rule.
class ExamPartCurriculumScope {
  final String targetVersionId;
  final String examPartKey;
  final String rootNodeId;
  final Set<String> nodeIds;
  final Set<String> outsideNodeIds;

  ExamPartCurriculumScope._({
    required this.targetVersionId,
    required this.examPartKey,
    required this.rootNodeId,
    required Set<String> nodeIds,
    required Set<String> outsideNodeIds,
  })  : nodeIds = Set.unmodifiable(nodeIds),
        outsideNodeIds = Set.unmodifiable(outsideNodeIds);

  /// Pure validator, separately testable without any hosted data.
  ///
  /// Never treats a missing or mismatched part as the whole target. A configured
  /// node must be present in the exact version's node query. Traversal rejects
  /// duplicate node IDs, missing parents and cycles.
  static ExamPartCurriculumScope fromRows({
    required String targetVersionId,
    required String examPartKey,
    required ExamPreparationProfile? profile,
    required List<Map<String, dynamic>> nodes,
  }) {
    if (profile == null || profile.targetVersionId != targetVersionId) {
      throw StateError('A matching exam-part profile is required.');
    }
    if (examPartKey.isEmpty || examPartKey.trim() != examPartKey) {
      throw StateError('A valid explicit exam-part key is required.');
    }
    final part = profile.findPart(examPartKey);
    if (part == null || !part.hasScopeRootCandidate) {
      throw StateError('This exam part has no configured curriculum root.');
    }
    final root = part.curriculumRootNodeId!;
    final parents = <String, String?>{};
    final children = <String, Set<String>>{};
    for (final node in nodes) {
      final id = node['id'];
      final parent = node['parent_id'];
      if (id is! String || id.isEmpty ||
          (parent != null && (parent is! String || parent.isEmpty)) ||
          parents.containsKey(id)) {
        throw const FormatException('Invalid or duplicate curriculum node.');
      }
      parents[id] = parent as String?;
      if (parent != null) {
        children.putIfAbsent(parent, () => <String>{}).add(id);
      }
    }
    if (!parents.containsKey(root)) {
      throw StateError('Exam-part root does not belong to this target version.');
    }
    for (final parent in parents.values) {
      if (parent != null && !parents.containsKey(parent)) {
        throw const FormatException('Curriculum node points outside its target version.');
      }
    }

    final included = <String>{};
    final active = <String>{};
    void visit(String id) {
      if (!active.add(id)) {
        throw const FormatException('Cyclic exam-part curriculum hierarchy.');
      }
      if (included.add(id)) {
        for (final child in children[id] ?? const <String>{}) {
          visit(child);
        }
      }
      active.remove(id);
    }

    visit(root);
    return ExamPartCurriculumScope._(
      targetVersionId: targetVersionId,
      examPartKey: examPartKey,
      rootNodeId: root,
      nodeIds: included,
      outsideNodeIds: parents.keys.toSet().difference(included),
    );
  }
}

/// Loads only version-owned nodes and typed existing EXM-01 metadata.
/// No target-wide fallback when a selected part cannot be resolved.
class ExamPartCurriculumScopeResolver {
  final SupabaseClient _client;

  ExamPartCurriculumScopeResolver({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<ExamPartCurriculumScope> resolve({
    required String targetVersionId,
    required String examPartKey,
  }) async {
    final version = await _client
        .from('target_versions')
        .select('id, metadata')
        .eq('id', targetVersionId)
        .maybeSingle();
    if (version == null || version['id'] != targetVersionId) {
      throw StateError('Exam-part target version not found.');
    }
    final rawMetadata = version['metadata'];
    if (rawMetadata is! Map) {
      throw const FormatException('Exam-part profile is missing.');
    }
    final profile = ExamPreparationProfile.fromTargetVersionMetadata(
      targetVersionId: targetVersionId,
      metadata: Map<String, dynamic>.from(rawMetadata),
    );
    final nodeRows = await _client
        .from('curriculum_nodes')
        .select('id, parent_id, node_type')
        .eq('target_version_id', targetVersionId);

    return ExamPartCurriculumScope.fromRows(
      targetVersionId: targetVersionId,
      examPartKey: examPartKey,
      profile: profile,
      nodes: (nodeRows as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(),
    );
  }
}

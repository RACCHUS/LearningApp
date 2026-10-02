import 'package:learning_pwa/core/errors/app_exceptions.dart';
import 'package:learning_pwa/models/user_curriculum_resource.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Personal supplement links; official curriculum bindings are handled by
/// [LearningTargetService] and are never written here.
class UserCurriculumResourceService {
  final SupabaseClient? _supabase;

  UserCurriculumResourceService({SupabaseClient? supabase})
      : _supabase = supabase;

  SupabaseClient get _client => _supabase ?? Supabase.instance.client;

  Future<List<UserCurriculumResource>> listForNodes(Set<String> nodeIds) async {
    if (nodeIds.isEmpty || _client.auth.currentUser == null) {
      return const [];
    }
    final rows = await _client
        .from('user_curriculum_resources')
        .select('*,lessons(title)')
        .inFilter('curriculum_node_id', nodeIds.toList());
    final resources = (rows as List)
        .map((row) => UserCurriculumResource.fromJson(
            Map<String, dynamic>.from(row as Map)))
        .toList();
    resources.sort((a, b) {
      final byNode = a.curriculumNodeId.compareTo(b.curriculumNodeId);
      if (byNode != 0) return byNode;
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.createdAt.compareTo(b.createdAt);
    });
    return resources;
  }

  Future<UserCurriculumResource> attachPersonalLesson({
    required String curriculumNodeId,
    required String lessonId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw AuthenticationException(
        'You must be signed in (or continue as guest) to attach a lesson.',
      );
    }
    // The unique constraint makes a retry safe after a timeout. RLS verifies
    // that the lesson is owned and the node is a published official topic.
    final row = await _client
        .from('user_curriculum_resources')
        .upsert(
          {
            'user_id': userId,
            'curriculum_node_id': curriculumNodeId,
            'lesson_id': lessonId,
            'relationship': 'personal_study',
          },
          onConflict:
              'user_id,curriculum_node_id,lesson_id,relationship',
        )
        .select('*,lessons(title)')
        .single();
    return UserCurriculumResource.fromJson(row);
  }

  Future<void> removePersonalLesson({
    required String curriculumNodeId,
    required String lessonId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw AuthenticationException(
        'You must be signed in (or continue as guest) to remove a lesson.',
      );
    }
    await _client
        .from('user_curriculum_resources')
        .delete()
        .eq('user_id', userId)
        .eq('curriculum_node_id', curriculumNodeId)
        .eq('lesson_id', lessonId)
        .eq('relationship', 'personal_study');
  }
}

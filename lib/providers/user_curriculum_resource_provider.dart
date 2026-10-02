import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/user_curriculum_resource.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/services/user_curriculum_resource_service.dart';

final userCurriculumResourceServiceProvider =
    Provider<UserCurriculumResourceService>((ref) {
  return UserCurriculumResourceService();
});

/// Riverpod family for personal curriculum resources attached to a given node.
///
/// Automatically refetches when the active learner auth identity changes.
final userCurriculumResourcesForNodeProvider = FutureProvider.family<
    List<UserCurriculumResource>, String>((ref, nodeId) async {
  ref.watch(learnerIdProvider);
  final service = ref.watch(userCurriculumResourceServiceProvider);
  return service.listForNodes({nodeId});
});

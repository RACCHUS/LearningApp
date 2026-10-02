import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/user_curriculum_resource.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/user_curriculum_resource_provider.dart';
import 'package:learning_pwa/services/user_curriculum_resource_service.dart';

class _CountingResourceService extends UserCurriculumResourceService {
  int fetches = 0;

  @override
  Future<List<UserCurriculumResource>> listForNodes(Set<String> nodeIds) async {
    fetches++;
    return const [];
  }
}

void main() {
  test('resource family refetches when auth identity changes', () async {
    final identity = StateProvider<String>((ref) => 'guest-a');
    final service = _CountingResourceService();
    final container = ProviderContainer(overrides: [
      learnerIdProvider.overrideWith((ref) => ref.watch(identity)),
      userCurriculumResourceServiceProvider.overrideWith((ref) => service),
    ]);
    addTearDown(container.dispose);

    await container.read(userCurriculumResourcesForNodeProvider('node-1').future);
    expect(service.fetches, 1);

    container.read(identity.notifier).state = 'guest-b';
    await container.read(userCurriculumResourcesForNodeProvider('node-1').future);
    expect(service.fetches, 2);
  });
}

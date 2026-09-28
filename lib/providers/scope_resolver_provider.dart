import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/scope.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/services/hive_service.dart';
import 'package:learning_pwa/services/scope_resolver.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final scopeResolverProvider = Provider<ScopeResolver>((ref) {
  final hive = ref.watch(hiveServiceProvider);
  return ScopeResolver(
    supabase: Supabase.instance.client,
    scopeBox: hive.resolvedScopeBox,
    snapshotBox: hive.contextSnapshotBox,
  );
});

/// The resolved scope for the currently active LearningContext.
final activeResolvedScopeProvider = FutureProvider<ResolvedScope?>((ref) async {
  final state = ref.watch(learningContextsProvider);
  final active = state.active;
  if (active == null) return null;

  final resolver = ref.watch(scopeResolverProvider);
  return await resolver.resolveScope(active);
});

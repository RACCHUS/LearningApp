import 'dart:convert';
import 'dart:math';

import 'package:learning_pwa/models/companion/learner_resource.dart';
import 'package:learning_pwa/models/learning_support/external_companion.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Where a learner's outside resources are kept (companion plan v1.0 §7.2):
/// the account for a signed-in learner, this device for a guest.
abstract class LearnerResourceStore {
  Future<List<LearnerResource>> list(String targetId);

  /// Creates ([id] null) or edits a resource. [url] must already be cleaned
  /// by `normalizeLearnerLink`.
  Future<String> save({
    String? id,
    required String targetId,
    required String title,
    required LearnerResourceKind kind,
    String? url,
    ExternalAccess? access,
  });

  /// Replaces the set of covered objectives; kept ones keep "studied".
  Future<void> setObjectives(String resourceId, Set<String> keys);

  Future<void> setStudied(String resourceId, String key, bool studied);

  /// Replaces the resource's outline. The objectives of the sections are
  /// also ticked as covered; nothing is unticked or marked studied.
  Future<void> setSections(String resourceId, List<ResourceSection> sections);

  Future<void> delete(String resourceId);
}

/// Account storage. Reads are owner-only by RLS; every write goes through a
/// server function that checks `content.learner_resources`.
class SupabaseLearnerResourceStore implements LearnerResourceStore {
  SupabaseLearnerResourceStore([SupabaseClient? client]) : _injected = client;
  final SupabaseClient? _injected;
  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  @override
  Future<List<LearnerResource>> list(String targetId) async {
    final rows = await _client
        .from('learner_external_resources')
        .select(
          'id,target_id,title,kind,url,access,learner_resource_objectives(objective_key,studied_at),'
          'learner_resource_sections(position,title,objective_keys,map_source)',
        )
        .eq('target_id', targetId)
        .order('created_at');
    return [
      for (final r in rows as List) LearnerResource.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }

  @override
  Future<String> save({
    String? id,
    required String targetId,
    required String title,
    required LearnerResourceKind kind,
    String? url,
    ExternalAccess? access,
  }) async {
    final res = await _client.rpc(
      'save_learner_external_resource',
      params: {
        'p_target_id': targetId,
        'p_title': title,
        'p_kind': kind.wire,
        'p_url': url,
        'p_access': access?.wire,
        'p_resource_id': id,
      },
    );
    return '$res';
  }

  @override
  Future<void> setObjectives(String resourceId, Set<String> keys) => _client.rpc(
    'set_learner_resource_objectives',
    params: {'p_resource_id': resourceId, 'p_objective_keys': keys.toList()},
  );

  @override
  Future<void> setStudied(String resourceId, String key, bool studied) => _client.rpc(
    'set_learner_resource_objective_studied',
    params: {'p_resource_id': resourceId, 'p_objective_key': key, 'p_studied': studied},
  );

  @override
  Future<void> setSections(String resourceId, List<ResourceSection> sections) => _client.rpc(
    'set_learner_resource_sections',
    params: {
      'p_resource_id': resourceId,
      'p_sections': [for (final s in sections) s.toRpcJson()],
    },
  );

  @override
  Future<void> delete(String resourceId) =>
      _client.rpc('delete_learner_external_resource', params: {'p_resource_id': resourceId});
}

/// Guest storage: one JSON list on this device, never sent anywhere.
class LocalLearnerResourceStore implements LearnerResourceStore {
  static const storageKey = 'learner_resources_v1';
  static const maxResources = 100;
  static final _random = Random();

  Future<List<LearnerResource>> _all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null) return [];
    try {
      return [
        for (final r in jsonDecode(raw) as List)
          if (r is Map) LearnerResource.fromJson(Map<String, dynamic>.from(r)),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<LearnerResource> all) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode([for (final r in all) r.toJson()]));
  }

  Future<void> _update(String id, LearnerResource Function(LearnerResource) change) async {
    final all = await _all();
    final i = all.indexWhere((r) => r.id == id);
    if (i < 0) throw StateError('resource_not_found');
    all[i] = change(all[i]);
    await _write(all);
  }

  /// Every resource on this device, for moving them into an account.
  Future<List<LearnerResource>> listAll() => _all();

  @override
  Future<List<LearnerResource>> list(String targetId) async =>
      (await _all()).where((r) => r.targetId == targetId).toList();

  @override
  Future<String> save({
    String? id,
    required String targetId,
    required String title,
    required LearnerResourceKind kind,
    String? url,
    ExternalAccess? access,
  }) async {
    final clean = title.trim();
    if (clean.isEmpty || clean.length > LearnerResource.maxTitleLength) {
      throw ArgumentError('title');
    }
    if (id != null) {
      await _update(id, (r) => r.copyWith(title: clean, kind: kind, url: () => url, access: () => access));
      return id;
    }
    final all = await _all();
    if (all.length >= maxResources) throw StateError('resource_limit');
    // The clock alone can repeat within one tick, so add random bits. The
    // bound is a literal: `1 << 32` is 0 when compiled for the web.
    final newId = 'local-${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(0x7fffffff)}';
    all.add(LearnerResource(id: newId, targetId: targetId, title: clean, kind: kind, url: url, access: access));
    await _write(all);
    return newId;
  }

  @override
  Future<void> setObjectives(String resourceId, Set<String> keys) => _update(
    resourceId,
    (r) => r.copyWith(objectives: {for (final k in keys) k: r.objectives[k]}),
  );

  @override
  Future<void> setStudied(String resourceId, String key, bool studied) => _update(resourceId, (r) {
    if (!r.objectives.containsKey(key)) throw StateError('objective_not_covered');
    return r.copyWith(
      objectives: {...r.objectives, key: studied ? (r.objectives[key] ?? DateTime.now().toUtc()) : null},
    );
  });

  @override
  Future<void> setSections(String resourceId, List<ResourceSection> sections) async {
    if (sections.length > ResourceSection.maxSections) throw StateError('too_many_sections');
    final clean = [
      for (final s in sections)
        ResourceSection(title: s.title.trim(), objectiveKeys: s.objectiveKeys, source: s.source),
    ];
    if (clean.any((s) => s.title.isEmpty || s.title.length > ResourceSection.maxTitleLength)) {
      throw ArgumentError('title');
    }
    await _update(
      resourceId,
      (r) => r.copyWith(
        sections: clean,
        objectives: {
          for (final s in clean)
            for (final k in s.objectiveKeys) k: null,
          ...r.objectives,
        },
      ),
    );
  }

  @override
  Future<void> delete(String resourceId) async {
    final all = await _all();
    all.removeWhere((r) => r.id == resourceId);
    await _write(all);
  }
}

/// Copies this device's guest resources into [account], then removes each
/// one from the device once it is saved. Returns how many moved. A failure
/// part-way leaves the rest on the device, so nothing is lost.
Future<int> moveLocalResourcesToAccount(LocalLearnerResourceStore local, LearnerResourceStore account) async {
  var moved = 0;
  for (final r in await local.listAll()) {
    final id = await account.save(
      targetId: r.targetId,
      title: r.title,
      kind: r.kind,
      url: r.url,
      access: r.access,
    );
    if (r.objectives.isNotEmpty) {
      await account.setObjectives(id, r.objectives.keys.toSet());
      for (final e in r.objectives.entries) {
        if (e.value != null) await account.setStudied(id, e.key, true);
      }
    }
    if (r.sections.isNotEmpty) await account.setSections(id, r.sections);
    await local.delete(r.id);
    moved++;
  }
  return moved;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/data_sync_service.dart';
import 'package:learning_pwa/services/hive_service.dart';
import 'package:learning_pwa/models/lesson_progress.dart';

class _FakeTable {
  Future<_FakeTable> select() async => this;
  _FakeTable order(String _, {bool ascending = true}) => this;
  _FakeTable eq(String _, dynamic __) => this;
  Future<List<Map<String, dynamic>>> call() async => [];
  Future<List<Map<String, dynamic>>> then(dynamic _) async => [];
  Future<List<Map<String, dynamic>>> toList() async => [];
  Future<List<Map<String, dynamic>>> get() async => [];
  Future<void> upsert(dynamic _) async {}
  Future<void> insert(dynamic _) async {}
  Future<void> delete() async {}
}

class _FakeSupabaseClient {
  _FakeTable from(String _) => _FakeTable();
}

class _FakeHiveService implements HiveService {
  @override
  noSuchMethod(Invocation invocation) => null;

  Future<void> cacheLessons(List<dynamic> _) async {}
  Future<void> cacheConcepts(List<dynamic> _) async {}
  Future<void> cacheMcqs(List<dynamic> _) async {}
  Future<List<UserProgress>> getUnsyncedProgress() async => [];
  Future<void> markProgressAsSynced(List<dynamic> _) async {}
  Future<void> cacheProgress(dynamic _) async {}
}

void main() {
  group('DataSyncService', () {
    test('syncAllData completes with empty sources', () async {
      final service = DataSyncService(
        supabase: _FakeSupabaseClient() as dynamic,
        hiveService: _FakeHiveService(),
        userId: 'user-123',
      );

      await expectLater(service.syncAllData(), completes);
    });
  });
}


import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:learning_pwa/services/data_sync_service.dart';
import 'package:learning_pwa/services/hive_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data_sync_service_mockito_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<SupabaseClient>(unsupportedMembers: {#from}),
  MockSpec<HiveService>(),
])
void main() {
  group('DataSyncService Logic Tests', () {
    late MockSupabaseClient mockSupabase;
    late MockHiveService mockHiveService;
    late DataSyncService service;

    setUp(() {
      mockSupabase = MockSupabaseClient();
      mockHiveService = MockHiveService();
      
      // Stub HiveService methods
      when(mockHiveService.cacheLessons(argThat(anything))).thenAnswer((_) async {});
      when(mockHiveService.cacheConcepts(argThat(anything))).thenAnswer((_) async {});
      when(mockHiveService.cacheMcqs(argThat(anything))).thenAnswer((_) async {});
      when(mockHiveService.getUnsyncedProgress()).thenAnswer((_) async => []);
      
      service = DataSyncService(
        supabase: mockSupabase,
        hiveService: mockHiveService,
        userId: 'test_user_001',
      );
    });

    test('should initialize service', () {
      expect(service, isNotNull);
    });

    test('can create service instance', () {
      expect(service, isA<DataSyncService>());
    });
  });
}
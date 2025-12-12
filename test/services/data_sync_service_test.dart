import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:learning_pwa/services/data_sync_service.dart';
import 'package:learning_pwa/services/hive_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data_sync_service_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<SupabaseClient>(unsupportedMembers: {#from}),
  MockSpec<HiveService>(),
])
void main() {
  group('DataSyncService', () {
    test('can be instantiated', () {
      final mockSupabase = MockSupabaseClient();
      final mockHiveService = MockHiveService();
      
      final service = DataSyncService(
        supabase: mockSupabase,
        hiveService: mockHiveService,
        userId: 'user-123',
      );

      expect(service, isA<DataSyncService>());
    });
  });
}
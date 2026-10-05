import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/governance/version_governance_service.dart';

void main() {
  group('Phase G: VersionGovernanceService fail-closed tests', () {
    late VersionGovernanceService service;

    setUp(() {
      service = VersionGovernanceService(supabaseClient: null);
    });

    test('evaluateMigration fails closed when no client is available', () async {
      expect(
        service.evaluateMigration(
          userId: 'test-user-id',
          fromVersionId: 'v-sy0-601',
          toVersionId: 'v-sy0-701',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('migrateUserContext fails closed when no client is available', () async {
      expect(
        service.migrateUserContext(
          userId: 'test-user-id',
          contextId: 'test-context-id',
          toVersionId: 'v-sy0-701',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('auditTargetVersionReadiness fails closed when no client is available', () async {
      expect(
        service.auditTargetVersionReadiness('v-sy0-701'),
        throwsA(isA<StateError>()),
      );
    });

    test('stageReview fails closed when no client is available', () async {
      expect(
        service.stageReview('v-sy0-701'),
        throwsA(isA<StateError>()),
      );
    });

    test('publishVersion fails closed when no client is available', () async {
      expect(
        service.publishVersion('v-sy0-701', retirePrevious: true),
        throwsA(isA<StateError>()),
      );
    });

    test('retireVersion fails closed when no client is available', () async {
      expect(
        service.retireVersion('v-sy0-601'),
        throwsA(isA<StateError>()),
      );
    });

    test('getContextVersionUpdate fails closed when no client is available', () async {
      expect(
        service.getContextVersionUpdate('ctx-none'),
        throwsA(isA<StateError>()),
      );
    });

    test('getStagedTargetVersions fails closed when no client is available', () async {
      expect(
        service.getStagedTargetVersions(),
        throwsA(isA<StateError>()),
      );
    });
  });
}

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';
import '../../tool/self_host_bootstrap.dart';

void main() {
  group('Turnkey Self-Hosting Infrastructure Verification', () {
    test('docker-compose.yml defines all required microservices and schema mappings', () {
      final composeFile = File('deploy/self-host/docker-compose.yml');
      expect(composeFile.existsSync(), isTrue, reason: 'docker-compose.yml must exist');

      final content = composeFile.readAsStringSync();
      final doc = loadYaml(content) as YamlMap;

      expect(doc['services'], isNotNull);
      final services = doc['services'] as YamlMap;

      // Essential Supabase microservices
      expect(services.containsKey('kong'), isTrue);
      expect(services.containsKey('auth'), isTrue);
      expect(services.containsKey('rest'), isTrue);
      expect(services.containsKey('storage'), isTrue);
      expect(services.containsKey('db'), isTrue);

      // PostgREST must serve both public and api schemas
      final restEnv = services['rest']['environment'];
      final schemasString = restEnv is YamlMap
          ? restEnv['PGRST_DB_SCHEMAS'].toString()
          : content;
      expect(schemasString, contains('public,api'),
          reason: 'PostgREST must expose both public and versioned api schemas');

      // Database healthcheck
      final dbService = services['db'] as YamlMap;
      expect(dbService['healthcheck'], isNotNull);
    });

    test('kong.yml routes API calls to auth, rest, and storage endpoints', () {
      final kongFile = File('deploy/self-host/kong.yml');
      expect(kongFile.existsSync(), isTrue, reason: 'kong.yml must exist');

      final content = kongFile.readAsStringSync();
      final doc = loadYaml(content) as YamlMap;

      final services = doc['services'] as YamlList;
      final serviceNames = services.map((s) => s['name'].toString()).toSet();

      expect(serviceNames, contains('auth-v1'));
      expect(serviceNames, contains('rest-v1'));
      expect(serviceNames, contains('storage-v1'));
    });

    test('.env.example defines all mandatory secret keys and gateway parameters', () {
      final envFile = File('deploy/self-host/.env.example');
      expect(envFile.existsSync(), isTrue);

      final content = envFile.readAsStringSync();
      expect(content, contains('POSTGRES_PASSWORD='));
      expect(content, contains('JWT_SECRET='));
      expect(content, contains('ANON_KEY='));
      expect(content, contains('SERVICE_ROLE_KEY='));
      expect(content, contains('KONG_HTTP_PORT='));
    });

    test('00-initial-schema.sql and 01-full-schema.sql exist and contain valid DDL', () {
      final init00 = File('deploy/self-host/init-scripts/00-initial-schema.sql');
      final init01 = File('deploy/self-host/init-scripts/01-full-schema.sql');

      expect(init00.existsSync(), isTrue);
      expect(init01.existsSync(), isTrue);

      final ddl00 = init00.readAsStringSync();
      expect(ddl00, contains('CREATE SCHEMA IF NOT EXISTS api;'));
      expect(ddl00, contains('CREATE TABLE IF NOT EXISTS supabase_migrations.schema_migrations'));

      final ddl01 = init01.readAsStringSync();
      expect(ddl01, contains('BEGIN;'));
      expect(ddl01, contains('COMMIT;'));
      expect(ddl01, contains('20241228000000_legacy_base_tables.sql'));
      expect(ddl01, contains('20261106010000_arch_03_versioned_api_schema_and_scope_resolver.sql'));
      expect(ddl01, contains('20261110200000_software_learning_excel_attempt_issuance.sql'));
      expect(ddl01, contains('107 immutable migrations'));
      expect(ddl01, contains('20261110230000_software_learning_excel_brokered_upload_seal.sql'));
      expect(ddl01, contains('20261108140000_clep_simulation_bank_and_item_privacy.sql'));
      expect(ddl01, contains('20261108000000_assessment_item_server_grading.sql'));
      expect(ddl01, contains('20261110210000_software_learning_excel_private_upload_gate.sql'));
      expect(ddl01, contains('20261110220000_software_learning_excel_processing_lease.sql'));
      expect(ddl01, contains('20261110190000_ana_001b_canonical_learner_progress.sql'));
    });

    test('SelfHostBootstrap.scanAndValidate verifies every migration sequentially', () {
      final scanResult = SelfHostBootstrap.scanAndValidate('supabase/migrations');

      expect(scanResult.isValid, isTrue, reason: 'Errors: ${scanResult.errors}');
      expect(scanResult.errors, isEmpty);
      // Keep this assertion forward-compatible as append-only migrations land in PRs.
      final migrationFileCount = Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.sql'))
          .length;
      expect(scanResult.migrations.length, equals(migrationFileCount));
      expect(scanResult.migrations.first.version, equals('20241228000000'));
      // Compare the scan against the checked-in migration filenames rather than
      // pinning the latest version, which would reject every additive migration.
      final expectedVersions = Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.sql'))
          .map((file) => file.uri.pathSegments.last.split('_').first)
          .toList()
        ..sort();
      expect(
        scanResult.migrations.map((migration) => migration.version).toList(),
        orderedEquals(expectedVersions),
      );

      final bundle = SelfHostBootstrap.generateBundleSql(scanResult.migrations);
      expect(bundle, contains('BEGIN;'));
      expect(bundle, contains('COMMIT;'));
      expect(bundle, contains('20241228000000_legacy_base_tables.sql'));
      expect(bundle, contains('20261106010000_arch_03_versioned_api_schema_and_scope_resolver.sql'));
      expect(bundle, contains('20261106030000_catalog_pathway_evidence_provenance.sql'));
      expect(bundle, contains('20261107025537_short_answer_grading_persistence.sql'));
      expect(bundle, contains('20261107041341_restore_manifest_ingestion_with_short_answer_grading.sql'));
      expect(bundle, contains('20261107050000_arch_04_learning_events_strict_rules.sql'));
      expect(bundle, contains('20261107060000_performance_library_search_trigram_indexes.sql'));
      expect(bundle, contains('20261108000000_assessment_item_server_grading.sql'));
      expect(bundle, contains('20261108140000_clep_simulation_bank_and_item_privacy.sql'));
      expect(bundle, contains('20261110150000_clep_simulation_domain_code_projection.sql'));
      expect(bundle, contains('20261110170000_clep_simulation_attempt_recovery_and_eligibility.sql'));
      expect(bundle, contains('20261110180000_clep_simulation_domain_quota_and_metadata_validation.sql'));
      expect(bundle, contains('20261110190000_ana_001b_canonical_learner_progress.sql'));
      expect(bundle, contains('20261110200000_software_learning_excel_attempt_issuance.sql'));
      expect(bundle, contains('20261110210000_software_learning_excel_private_upload_gate.sql'));
      expect(bundle, contains('20261110220000_software_learning_excel_processing_lease.sql'));
      expect(bundle, contains('20261110230000_software_learning_excel_brokered_upload_seal.sql'));
    });
  });
}

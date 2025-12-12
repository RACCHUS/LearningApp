# Failing and Skipped Tests Summary (as of 2025-12-11)

## Failing Tests (Current Priorities)

1. **HandsFreeSettingsProvider Tests**
   - File: test/providers/hands_free_settings_provider_test.dart
   - Issues: Initialization and mock setup errors (see error messages above)
   - Plan: Ensure all required fields/providers are initialized, mocks return correct types, and review test setup for async/stream handling.

2. **DataSyncService Tests**
   - Files: test/services/data_sync_service_mockito_test.dart, test/services/data_sync_service_test.dart
   - Issues: Missing stubs for mocked methods, incorrect mock types
   - Plan: Add proper stubs for all mocked methods using Mockito's `when` API, ensure correct mock types and generated mocks are used.

3. **GlobalVoiceService Tests**
   - Files: test/services/global_voice_service_mockito_test.dart, test/services/global_voice_service_test.dart
   - Issues: Incorrect stream/mocks, type errors
   - Plan: Ensure mocks return correct types and streams, review stub setup for proper usage and types.

4. **ImportExportService Tests**
   - File: test/services/import_export_service_test.dart
   - Issue: createBackup returns incorrect content
   - Plan: Check backup creation logic and test data for correctness.

---

## Skipped Tests

- Review all skipped tests in the codebase. If a test is skipped because it is flaky, obsolete, or not relevant, consider deleting it. If it is still relevant, plan to fix and re-enable it.
- To find skipped tests, search for `skip:` or `testWidgets(..., skip:` in the test files.
- If you want a detailed list of skipped tests, let me know and I can generate it for you.

---

**Next Steps:**
- Address the above failures in order of simplicity and impact (see also the project todo list).
- Review skipped tests and decide whether to fix or remove them.
- Update this file and the plan as progress is made.

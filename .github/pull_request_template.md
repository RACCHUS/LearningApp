## Summary
- 

## Validation
- [ ] `flutter analyze` (or equivalent) passed
- [ ] Relevant tests passed

## Test Quality ([policy](docs/testing/TEST_QUALITY_POLICY.md))
- [ ] Changed behavior is covered by a test that **fails on the old implementation**
- [ ] Risk-area evidence from policy §3 is included (assessment, auth/RLS, feature controls, import, migrations, UI/a11y, sync, privacy)
- [ ] No test was skipped, loosened, deleted, renamed or moved out of discovery without a stated replacement; any new skip is registered (§4)
- [ ] No new nondeterminism, real network calls, secrets, shared mutable state or sleeps in tests

## UI / Design Checklist
- [ ] New UI color usage prefers theme tokens (`colorScheme` / `SemanticColors`) over hardcoded `Colors.*`
- [ ] Any new custom palette mappings are centralized (no duplicated color maps)
- [ ] Contrast is readable for colored chips/badges/status surfaces

## Notes
-

## Feature Control / Capability Preservation (FLAG-010 / FLAG-016)
- [ ] If this PR adds or exposes a significant capability, register its stable key in `SiteFeatureKeys` and the reviewed database registry; default risky features OFF.
- [ ] Show the exact UI route and server-side admission/authorization checks. A hidden button is **not** a kill switch; unwired registry rows must be labeled planned.
- [ ] Include an OFF-path test proving no optional SDK initialization, external requests, paid usage, background jobs, or unauthorized writes; provide a graceful disabled route.
- [ ] Explain how user data and existing learning paths are preserved when OFF, and document an owner-approved re-enable checklist.
- [ ] If removing legacy code, document verified replacement parity or explicit owner approval of obsolescence, and test migrations, exports, accessibility, offline and rollback.
- [ ] If touching BYOK, honor its independent hard-OFF latch until verified fixes and owner sign-off; keep TEL Fast available and flag unverified claims Experimental.


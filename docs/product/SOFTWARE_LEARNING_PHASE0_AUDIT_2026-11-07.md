# Software Learning — Phase 0 Repository Audit (in progress)

**Date:** 2026-11-07  
**Baseline:** `main` at `126c4e15a819cd2e9e50e58d0b621035b05387cc`  
**Feature branch:** `feature/software-learning-excel-mvp-20261107`  
**Plan:** [SOFTWARE_LEARNING_PLAN.md](../../SOFTWARE_LEARNING_PLAN.md) (v1.2)  
**Status:** **Partially audited. NOT a release or architecture sign-off.**

## Verified repository facts

1. **Navigation is locked:** `UI_ARCHITECTURE_LOCKED.md` specifies Learn, Library, Progress and a learner-controlled context. No new top-level Software tab is permitted. Use Library for discovery and Learn for active study. A product/software goal must fit the existing goals model or require an explicitly approved architecture amendment.
2. **Reuse curriculum infrastructure:** `content/schema/curriculum_manifest.schema.json`, `content/*.yaml`, `tool/lint_manifest.dart`, and `tool/ingest_curriculum.dart` already support content manifests, lesson blocks and assessments. The pilot uses `content/excel_fundamentals.yaml` rather than a new learning engine. Ingestion remains draft/review/publish gated; this branch has not published anything.
3. **No new skill scale:** `lib/models/skill.dart` models `Skill` by shared slug; `UserSkillStats.level` is **0–100**, with an `isVerified` flag. `supabase/migrations/20261101200000_eco_06_port_legacy_skills_and_missing_schema.sql` creates `skills`, `course_skills`, `user_skill_stats` and related tables. The v1.2 illustrative 0–5 labels must **not** be added as a parallel database scale. Existing shared concept slugs may be transferable; existing skill-slug collisions still require review before writing any skill records.
4. **Ledger corrective work is merged in source:** PR [#169](https://github.com/RACCHUS/LearningApp/pull/169), merged 2026-11-07, added `supabase/migrations/20261107050000_arch_04_learning_events_strict_rules.sql` and `supabase/tests/learning_events_strict_rules_test.sql`. The migration tightens `public.record_events` idempotency, canonical digests and the server-owned `user_concept_state` projection. **Production migration deployment, support for this workbook-assessment event type, and the trust of skill-stat updates are not established.** A merged ledger PR by itself does not authorize verified workbook skill awards.
5. **Simulation evidence is not implemented:** PR [#187](https://github.com/RACCHUS/LearningApp/pull/187) is a draft opt-in simulation preview with in-memory completion only, **no scoring or persisted evidence**. Do not create a competing evidence system. Propose one shared contract for both source types before implementation.
6. **File ingress is unresolved:** Repository search found existing taxonomy XLSX ingestion utilities, but no confirmed isolated learner-workbook ingestion worker or user-submission policy. Those developer utilities are **not** evidence of safe handling of arbitrary learner uploads. No upload endpoint is enabled in this branch.
7. **Testing and migration governance exist:** `.github/workflows/flutter-ci.yml` runs curriculum linting, dry-run ingestion, Flutter tests, schema checks, and other validations. `AGENTS.md` requires append-only migrations and guarded deployment. This branch introduces **no database migrations or production deployment**.

## Keep / extend / build decisions

| Capability | Decision | Specific repo surface | Current action |
|---|---|---|---|
| Library discovery and Learn context | **Keep** | `lib/screens/library/library_screen.dart`, `lib/screens/learn/learn_screen.dart`, `UI_ARCHITECTURE_LOCKED.md` | Do not add navigation |
| Curriculum, lesson blocks, provenance | **Extend** | `content/`, `tool/lint_manifest.dart`, `tool/ingest_curriculum.dart` | Draft one Excel course |
| Skills and competency | **Keep/extend after review** | `lib/models/skill.dart`, `public.skills`, `public.user_skill_stats` | No new skill scale or award |
| Shared evidence | **Extend after contract audit** | `public.learning_events`, `public.record_events`, PR #169; draft PR #187 | Contract proposal below; no event writes |
| Excel checker | **Build narrowly** | `tool/software_learning/excel_budget_total.py` | Pure deterministic core and tests only |
| Uploaded XLSX isolation | **Build after threat review** | no suitable learner-upload worker established | **Blocking** |
| User file retention and deletion | **Design and test before uploads** | storage and privacy architecture to verify | **Blocking** |
| Microsoft/Google OAuth | **Defer** | provider approvals and scopes not evaluated | Not part of Excel pilot |

## Proposed shared evidence envelope (not an API yet)

The software checker and eventual simulation runtime should both emit the **same server-validated evidence envelope**, not their own skill counters:

```json
{
  "schema_version": "proposal-1",
  "attempt_id": "server-issued-uuid",
  "learner_id": "authenticated-user-id",
  "activity_id": "excel-budget-total-v1",
  "activity_version": 1,
  "source_kind": "file_assessment",
  "software_context": "microsoft-excel",
  "skill_slug": "spreadsheet-range-summation",
  "assistance_mode": "independent",
  "result": "pass",
  "trust": "server_verified",
  "checker_version": 1,
  "artifact_digest": "sha256-of-approved-artifact",
  "recorded_at": "server-timestamp"
}
```

For a simulation, `source_kind` would change to `simulation`, while identifiers, outcome, assistance, provenance and trust policy remain consistent. **This JSON is illustrative only.** Reconcile with the actual `record_events` 13-field canonical payload, allowable `event_type` values and existing evidence projections before designing a migration or RPC.

The checked-in pure Excel checker currently returns `unverified_checker_only`, even for a passing formula. That is deliberate: it does not accept raw files, authorize the learner, issue attempts, write events, or award skills.

## Excel pilot security boundary

**Already drafted, not released:** a proprietary-software-free curriculum, synthetic CSV starter data, a versioned declarative criterion description, and a bounded formula checker that checks one `Budget!C10` sum.

**Must be added before a file upload route:**

- An isolated parser worker with no privileges or outbound internet; use ephemeral storage and strict time/resource limits.
- Signed, authenticated, single-user and single-attempt upload authorization.
- Enforce 10 MiB maximum *before* ingestion; allow only genuine .xlsx with file signatures and ZIP structure validation.
- Reject .xlsm, embedded macros/objects, formulas with external references, external workbook relationships, suspicious archive structures, decompression bombs, encrypted files and unsupported features.
- Never execute uploaded formulas or trust their cached results; only validate supported expression classes against a server-issued synthetic dataset.
- Define retention and deletion by policy, storage region, accessible user controls, and response to account erasure.
- Require clear opt-in before transmitting submitted files or extracted content to any AI service. Initial deterministic grading must **not** send data to AI.
- Include malformed/hostile fixture tests, retry/idempotency tests, cross-tenant checks, user deletion tests, and privacy disclosures.

**Integrity limitation:** The static CSV starter and public checker code demonstrate correctness of a workbook, **not proof of which person authored it**. To support high-level independent competency, use versioned server-issued attempt data and additional independent evidence safeguards; do not claim anti-cheating guarantees from a formula check alone.

## Audit exit checklist

- [x] Dated source audit with concrete files, merged PR #169 and open draft PR #187 identified.
- [x] Initial keep/extend/build map and no-new-navigation decision.
- [x] Existing `Skill` and 0–100 `UserSkillStats` model documented.
- [x] Ledger source status recorded; deployment and new assessment event eligibility explicitly unverified.
- [x] Reusable target evidence envelope **proposed**, not finalized.
- [ ] Verify existing transferable skill slugs and complete concept/skill mapping (no duplication).
- [ ] Reconcile proposed evidence envelope with `record_events` and simulation PR #187.
- [ ] Review and approve isolated parser, storage, cost, and lifecycle proposal.
- [ ] Complete Excel checker threat model, synthetic attempt issuance and acceptance matrix.
- [ ] Confirm locked-UI compliance in an actual desktop/mobile Flutter flow.
- [ ] Assign and approve implementation tickets and independent owners/reviewers.
- [ ] Receive owner sign-off on Phase 0 exit.

Until the open items are completed, the branch is **implementation work in progress**, **not deployable**, and must not be merged as a released Excel feature.

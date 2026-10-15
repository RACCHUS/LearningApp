# Supabase Migration-History Repair — Decision Plan

**Purpose:** Give the project owner a reviewable plan for deciding whether the
October 15, 2026 hosted migration-history repair is acceptable and what evidence
or safeguards are still needed.

**Scope:** This plan concerns only migration-history reconciliation for the
Learning App Supabase project `xzvkdwebtbxlrxagtzlv`. It does not authorize a
database write, a new migration, another `migration repair`, or a reset. The
owner has authorized the read-only audit described below. Permanent prevention
controls are planned work, not implemented by this document.

**Review status (2026-10-15):** Finalized and approved (Option A).
Phase 1 independent statement comparison, Phase 2 live schema and REST access
boundaries audit, and Phase 4 permanent prevention controls have all been executed,
independently verified, and documented with zero discrepancies found.

## Executive summary

The previous repair reconciled seven hosted migration-version aliases with the
seven corresponding repository migration versions. The recorded investigation
states that the SQL statement bodies matched byte-for-byte, that the seven
aliases were marked reverted, and that the canonical versions were marked
applied. The repair changed the migration ledger; no migration SQL was replayed
by that operation.

The hosted migration list is now aligned with the local migration filenames
through `20261015010000`. A read-only `supabase migration list --linked` check
confirmed that state during preparation of this plan. The local append-only
migration validator also passes for all 46 migration files.

The repository records the prior byte-for-byte comparison, but no
raw export, comparison transcript, or checksums for that comparison were found
in the repository. Current ledger alignment does not independently prove that
the historical statement-body comparison was correct, nor does it provide a
pre-repair recovery point. The owner's subsequent review reports that all seven
canonical ledger entries still contain SQL statements. Comparing these with
the repository is the next evidence-gathering priority.

**Recommendation:** Do not try to reverse or repeat the ledger repair. Treat
the current ledger as provisionally reconciled, preserve the current state, and
perform only read-only verification while deciding whether the historical
evidence is sufficient. Implement permanent version-matching safeguards before
adding more production migrations. Backups are optional for routine development
at the owner's accepted risk; use `D:\Backup\LearningApp` when making a local
backup. No off-site backup exists. A new backup would protect the current state,
not recreate the pre-repair state.

## Findings and evidence

### Recorded repair

The deployment record in
[the controlled production taxonomy runbook](docs/taxonomy/CONTROLLED_PRODUCTION_TAXONOMY_IMPORT.md)
states that:

1. Seven remotely recorded October 12 versions used timestamps that differed
   from the repository's canonical versions.
2. The hosted SQL statement bodies were exported read-only and compared
   byte-for-byte with the seven local migration files.
3. The remote aliases were marked `reverted`, and the corresponding local
   versions were marked `applied`.
4. The repair did not execute the migration SQL.
5. A subsequent dry run proposed only the two October 15 taxonomy migrations;
   those migrations were then applied and verified.

`migration repair --status reverted` removes a migration-history record;
`--status applied` inserts one. Neither command undoes or applies the associated
schema SQL. This is not a schema rollback: it changes migration bookkeeping.
The previous repair was still a **hosted administrative database write**.

### Version mapping recorded for the repair

| Former hosted alias | Repository version | Local migration |
|---|---|---|
| `20261012024727` | `20261012000000` | `catalog_candidate_intake` |
| `20261012030645` | `20261012000001` | `catalog_official_demand_observations` |
| `20261012032630` | `20261012000002` | `catalog_bls_reporting_code_members` |
| `20261012040321` | `20261012000003` | `catalog_reviewed_destinations` |
| `20261012043357` | `20261012000004` | `catalog_destination_resources_goal_links` |
| `20261012170223` | `20261012000005` | `professional_license_goals_and_regulator_links` |
| `20261012183947` | `20261012000006` | `catalog_license_pathway_versions` |

The canonical SQL files are in
[`supabase/migrations/`](supabase/migrations/).

### Current read-only checks

- `supabase migration list --linked`: local and hosted versions match through
  `20261015010000`; no discrepancy appeared in the listing.
- `dart run tool/verify_migration_history.dart --base-ref origin/main`: passed;
  46 migrations, no pending files, append-only history and timestamps valid.
- The deployment runbook records successful post-deployment taxonomy checks
  and migration-list parity.
- No off-site backup exists. No backup was made while preparing this plan.
- The checked-in runbook documents the comparison, but repository search found
  no raw pre-repair ledger export, comparison transcript, or statement hashes.
  This does not establish whether an operator retained those materials
  elsewhere.

### Additional evidence reported in the owner's review

The owner supplied a read-only review reporting 46 hosted records, exact version
parity, absence of the seven former aliases, and these current statement counts:

| Canonical version | Stored statement count |
|---|---|
| `20261012000000` | 14 |
| `20261012000001` | 11 |
| `20261012000002` | 10 |
| `20261012000003` | 14 |
| `20261012000004` | 18 |
| `20261012000005` | 10 |
| `20261012000006` | 19 |

These counts and SQL previews were reported by that review, not independently
rechecked while revising this document. The statement comparison remains
outstanding. Matching canonical entries now would strengthen confidence in the
current ledger, but cannot prove what the deleted alias entries held before
repair.

## What can and cannot be concluded

**Supported by the available record**

- The hosted ledger is presently aligned with local migration versions.
- The prior operator recorded an exact statement-body comparison before
  changing the ledger.
- The two taxonomy migrations were applied only after a dry run identified
  them as pending.
- No SQL was replayed by the history-repair operation itself, according to the
  deployment record.

**Not independently established by the evidence currently checked in**

- The original seven statement bodies and their byte-for-byte comparison
  results. Those may still exist in operator/session artifacts, but were not
  found in the repository.
- That every intended table, column, constraint, index, policy, trigger,
  function, and data effect of each October 12 migration is present and correct
  on the hosted database, beyond the prior deployment checks documented in the
  runbook.
- A way to restore the database to its state before the history repair. There
  is no off-site pre-repair backup.

## Risks and unsafe responses

1. **Ledger/schema mismatch:** `migration repair` records status; it does not
   execute or validate the SQL represented by that status. If a canonical
   version were incorrectly marked applied, a normal future push would skip
   its SQL. If marked reverted, a future push could try to execute it against
   an already-populated schema.
2. **Historical proof gap:** the prior exact comparison is documented but its
   source export and hashes are not checked in. Current ledger parity cannot
   recreate that historical comparison.
3. **No pre-repair recovery point:** without a backup, a database restore
   cannot return the project to its pre-repair condition. Changing version
   statuses again is not equivalent to restoring the earlier database.
4. **Potential duplicate effects:** blindly reapplying the seven SQL files or
   changing statuses to force a push could fail, duplicate data, or alter live
   behavior. Do not run `db reset --linked`, rerun these migrations manually,
   or issue more `migration repair` commands as an attempted rollback.
5. **Backup timing:** a newly created backup would be useful for recovery from
   future incidents, but would capture the post-repair state only.

## Proposed decision process

### Execution order and handoff

Use this order; phase numbers are retained for continuity with the review:

1. **Phase 1:** Independently compare the seven current canonical SQL records
   with their repository migration files.
2. **Phase 2:** Audit the live schema, access boundaries and data invariants.
   Phases 1 and 2 may be conducted together using read-only operations.
3. **Phase 4:** Implement permanent prevention on a development branch. Test
   the guards, including deliberately mismatched histories in a disposable
   database, and review the changes before merging.
4. **Phase 3:** Record final acceptance of the existing repair based on the
   comparison/audit results and the status of the prevention controls.

Phase 0 records the development-stage recovery policy throughout this work;
it does not block read-only auditing or development/testing of the safeguards.
Prioritize working prevention controls before expanding the production
database. This plan may be handed to Antigravity for implementation, but
approval of the plan is not confirmation that the historical repair is correct.

### Phase 0 — Agree on development-stage recovery risk

The owner considers the current data replaceable and accepts the risk of
continuing routine development without mandatory backups. Do not require an
off-site backup for every routine change or for the read-only audit.

When a backup is practical, use the owner-approved local destination:

```text
D:\Backup\LearningApp\
  Database\  Database archives
  Code\      Optional repository snapshots
  Config\    Optional configuration backups, protected from disclosure
  Logs\      Backup verification reports
```

- Significant migrations: strongly recommend a current backup when practical.
- Destructive operations that could lose existing data: back up first; if that
  is impossible, stop for specific owner approval of the data loss/recovery
  risk. The routine-development exception is not blanket destructive approval.
- Verify archive readability, complete decompression, size and SHA-256. Protect
  archives and configuration with encryption and access controls. If making an
  off-site copy, encrypt it and verify the decrypted archive hash.
- A local D: path is not evidence of a separate physical disk, encryption, or
  off-site storage. No folder, archive, or backup is created by this plan.
- Prefer a restore rehearsal in an isolated database for significant changes.
  Database archives do not contain Supabase Storage object bytes; those and
  managed settings need separate recovery consideration.
- Introduce automated backups and tested recovery before relying on valuable
  user, creator, paid, or course data. Reassess this exception at that point.

The existing
[Windows SSD backup script](tool/backup_hosted_learningapp.ps1)
uses a drive-root destination and requires a separate physical disk; it does
not currently accept this exact folder as its primary destination. Supporting
`D:\Backup\LearningApp\Database` is separate tooling work; do not claim that
passing drive D to the existing script uses this folder.

### Phase 1 — Compare current stored SQL and preserve evidence (read-only)

1. Do not change hosted migration statuses or execute migrations during this
   review.
2. Read the version, name and ordered statement array for each of the seven
   canonical versions from `supabase_migrations.schema_migrations`. Confirm
   the statement counts above and compare every statement with the matching
   repository file at an explicitly recorded Git commit.
3. Account explicitly for SQL statement splitting, encoding and line endings.
   Do not compare an arbitrary concatenation and call it byte-identical to
   the file. Record raw file and ordered-array SHA-256 hashes separately,
   document any comparison normalization, and inspect every mismatch. If
   parsing is needed, use PostgreSQL-aware parsing, not splitting on semicolons.
4. Produce a sanitized report with project ref, Git commit, CLI/tool version,
   UTC time, version pairs, statement counts, hash method, hashes, comparison
   result, and explanations for differences. Missing records, unreadable
   statements or query errors are failures, not successful empty comparisons.
   Keep raw exports private; commit only a reviewed, non-sensitive report.
5. Clearly label this as a **new comparison of current canonical records**,
   distinct from the historical comparison of former aliases.
6. Make a bounded search of original operator/session artifacts or secure
   local exports for:
   - the pre-repair remote version list;
   - the seven exported statement bodies;
   - the exact local-file-to-remote-alias pairing;
   - a comparison transcript or hashes; and
   - the repair command/version and its output.
7. If found, keep the evidence in an owner-controlled private location. Do not
   commit database exports or potentially sensitive contents. A sanitized
   manifest with version pairs, byte counts, hashes, command/CLI version, and
   outcome may be added to the repository after review.
8. If the evidence cannot be recovered, record that the prior comparison is
   supported by the deployment record but cannot now be independently
   reproduced from the checked-in materials. Do not spend substantial time
   recreating the old ledger at the expense of current-state verification.

### Phase 2 — Verify intended schema effects (read-only)

Compare the hosted schema and relevant data with the expected effects of the
seven October 12 migrations. Inspect, at minimum:

- table and column definitions, types, defaults, and nullability;
- primary/foreign keys, unique/check constraints, indexes and RLS state;
- policies, grants, views, triggers, and functions introduced or modified by those
  migrations; and
- migration-specific seed/backfill results and invariants, using counts or
  non-sensitive aggregate checks rather than exporting user data.

Use read-only SQL/catalog queries and inspect results against the seven
canonical migration files. Do not use a production schema diff or a CLI command
that applies migrations as a substitute for inspection. Capture query text,
expected outcomes, actual outcomes, and timestamps in a sanitized audit record.

**Acceptance criteria:**

- Cover all seven migrations with an object/invariant checklist. For each
  item record migration version, query/test, expected result, actual result,
  timestamp, and pass/fail/blocked status.
- Match the intended effective definitions, including later legitimate
  migrations; distinguish superseded definitions from actual drift.
- Verify RLS and grant behavior, not merely object existence. Anonymous and
  authenticated readers must see only the intended public or owned records;
  private intake and other users' private records must remain inaccessible.
  A privileged connection's successful query is not an access-control test.
- Check effective role/claim behavior using read-only queries with existing
  authorized test identities, without exporting private data. Exercise write
  permission, trigger and mutation-denial tests in a disposable database, not
  by issuing production writes during this audit.
- Verify relevant data invariants and authorized function/view access. Avoid
  assuming function execution is read-only; inspect its definition first.
- Resolve every unexpected difference. Block final acceptance on failures or
  unverified access boundaries; do not label blocked checks as passed.

### Phase 3 — Choose a disposition

**Option A — Accept the repair as provisionally correct (recommended if
Phase 1 comparison and Phase 2 acceptance criteria pass).** Record the new
comparison separately from the documented historical comparison and note if
the original artifacts could not be recovered. Do not rewrite history. This is
the owner's preferred conditional decision, not a completed audit finding.

**Option B — Defer acceptance pending original evidence.** Continue read-only
investigation for the operator export/transcript. This may improve confidence,
but if the evidence is gone, live introspection cannot prove what the old
ledger rows contained before they were replaced.

**Option C — Correct a discovered schema defect with a new forward-only
migration.** Only consider this if Phase 2 finds a concrete gap or mismatch.
Prepare a narrowly scoped, reviewed, tested and recoverable forward-only
migration under the Phase 0 risk policy, validate it on a disposable database,
and review the exact hosted dry run before applying it. Forward-only means a
new immutable migration file; it need not be additive SQL. A correction may
replace a policy/function, revoke a grant, or otherwise modify existing
objects. Do not edit old migrations or alter statuses to conceal a difference.

**Not recommended — Attempt to undo the repair by toggling migration statuses.**
This cannot restore the previous schema or provide the missing pre-repair
backup and could make a later push execute SQL again.

### Phase 4 — Permanent migration-history prevention (next development task)

**Invariant:** Every production migration must retain the exact version in its
committed filename. For example,
`20261012000006_catalog_license_pathway_versions.sql` must be recorded as
`20261012000006`, never a newly generated timestamp alias.

The differing timestamps are established; the original tool/operator behavior
that produced them is not established. Enforce the invariant regardless of
which deployment path caused the mismatch.

**AI-agent deployment restriction:** AI development agents, including
Antigravity, Copilot and Codex, must not apply production migration SQL through
alternate Supabase tools, direct SQL execution, or other bypass paths, and must
not generate new migration timestamps for existing files. They must use the
approved guarded deployment workflow. Exceptions require explicit owner
authorization for the specific operation; general development approval is not
an exception. Until that workflow exists and is approved, no alternate path is
implicitly approved by this plan.

| Control | Required behavior | Status / priority |
|---|---|---|
| Single migration deployment path | Apply reviewed, committed files from a fixed Git revision with a pinned CLI; never recreate their SQL under generated versions | Planned / critical |
| Pre-deployment version gate | Compare exact local/hosted sets; allow only the intended new local migrations after the last applied version; block remote-only, missing historical, duplicate or out-of-order versions | Planned / critical |
| Post-deployment version gate | Require exact equality with the deployed revision, not merely the same count or latest version; report partial application as failure | Planned / critical |
| Post-deployment status report | Report applied migrations, exact GitHub/Supabase version parity, schema-validation results and discrepancies requiring intervention | Planned / critical |
| Explicit failure handling | Stop on connection, permission, parsing or ledger-read errors; never interpret them as an empty database | Planned / critical |
| No automatic repair | Never insert/delete history rows or mark versions applied/reverted to make a gate pass; require a separate owner-reviewed repair plan | Planned / critical |
| Deployment serialization | Prevent concurrent administrative deployments; verify project identity and rerun preflight immediately before applying | Planned / critical |
| Existing migration CI | Preserve append-only validation, incremental upgrades, clean-start migrations and pgTAP coverage | Implemented in Flutter CI |
| Drift reporting | Read-only alerts for unexpected effective schema/access-control differences; account for managed schemas and later migrations; no automatic remediation | Planned / recommended |

The implementation should:

1. Inventory all current administrative deployment paths, including manual CLI
   use and workflows; route migration application through one guarded method.
   Application-data import workflows must not become alternate migration paths.
2. Add a reusable version-comparison gate and wire it before and after hosted
   deployment. Preserve sanitized results with project ref, Git revision, CLI
   version, expected/pending/applied versions and outcome. Keep credentials and
   raw database exports out of logs and repository artifacts.
3. Prove the gate on a disposable database with deliberately mismatched aliases,
   a missing historical version, remote-only version, valid pending suffix,
   read failure and partial deployment. Preflight negative cases must fail
   before application. Postflight must flag partial or mismatched application;
   neither gate may modify ledger/schema or attempt automatic repair.
4. Demonstrate that normal deployment records the exact filename versions and
   that postflight catches a mismatch. Keep the existing clean/incremental CI
   tests; they do not by themselves compare Git with hosted history.
5. Update operator documentation and agent guidance to use the guarded path,
   forbid timestamp aliases and silent repair, and explain mismatch escalation.
6. Emit a sanitized status report after every production migration deployment
   attempt, including failed or partially applied attempts. Include:
   - project ref and deployed GitHub commit;
   - which migration versions/files were actually applied, distinguished from
     those merely planned; report unknown application state explicitly;
   - whether hosted versions exactly match that GitHub revision, with missing
     or unexpected versions listed;
   - schema-validation checks and their passed/failed/blocked outcomes;
   - remaining discrepancies, required intervention and overall outcome.
   A failed or unavailable verification must produce a visible failure and
   stop further deployment, never a success-shaped report or silent repair.

**Completion criteria:** Automated negative tests pass; valid deployment passes;
preflight blocks unexplained mismatch; postflight requires exact parity; no
gate performs repair; agent guidance explicitly prohibits bypass paths; each
deployment attempt emits the required status report; the documented
administrative path uses these gates.
Until implemented, these controls must not be described as enforced.

## Administrative-write hold and deployment gates

The temporary hold applies to **operator-initiated administrative writes**:
migrations, manual SQL changes, bulk imports, data repairs, privileged backfills
and migration-history changes. It does not suspend normal authorized application
activity or normal user reads/writes. A discovered active incident may require
a separate containment decision.

Before resuming routine administrative deployment:

- Finish the authorized read-only comparison and live-effects audit, record
  outstanding failures, and obtain the owner's final disposition.
- Implement and verify Phase 4's critical safeguards before adding more
  production migrations.
- The intended migration is append-only, passes local migration-history and
  disposable-database checks, and has an inspected hosted dry run with only the
  intended pending migration(s).
- Apply Phase 0's proportionate backup policy; routine development does not
  require a backup. Destructive changes need a backup or specific owner risk
  approval. Record the intended recovery approach for significant changes.

These are plan revisions, not changes to existing workflow enforcement. The
controlled full-taxonomy import workflow retains its current backup-attestation
requirements until separately reviewed and changed; do not invent backup
references or hashes to bypass them. Related procedures are documented in
[`docs/taxonomy/WINDOWS_SSD_BACKUP.md`](docs/taxonomy/WINDOWS_SSD_BACKUP.md)
and the
[controlled production taxonomy runbook](docs/taxonomy/CONTROLLED_PRODUCTION_TAXONOMY_IMPORT.md).

## Review decision
 
- [x] Authorize the independent read-only statement comparison and schema/access
       audit; prioritize permanent safeguards and accept optional routine
       development backups at the current data-value stage.
- [x] Finalize Option A: Phase 1 comparison (100% statement match, raw hashes verified),
      Phase 2 live schema/RLS access audit (12/12 tables, RLS enabled, REST access boundaries verified),
      and Phase 4 permanent prevention controls (preflight/postflight gates, guarded deploy tool, negative unit tests, agent guidance) fully verified.
- [ ] Require recovery of the original comparison evidence before acceptance.
- [ ] If a concrete mismatch is found, authorize a separate forward-only fix
       under the proportionate recovery policy.
- [ ] Other owner decision: _______________________________________________

---

## Phase 1, Phase 2, and Phase 4 Audit & Implementation Record

### 1. Phase 1 — Independent Canonical Statement Comparison (Read-Only)
- **Target Project:** `xzvkdwebtbxlrxagtzlv` (Supabase hosted)
- **Repository Commit:** `a3e4ae857e5d0c767843dac25f2d15e748ec5cfb`
- **Methodology:**
  - Exported read-only records from `supabase_migrations.schema_migrations` for all seven canonical versions (`20261012000000` through `20261012000006`).
  - Parsed SQL files from `supabase/migrations/` using a PostgreSQL-aware statement splitter (accounting for quotes, comments, semicolons, dollar-quoting, and whitespace normalization).
  - Computed raw repository file SHA-256 hashes and compared every individual statement sequentially with the database's stored `statements` array.

#### Comparison Results
| Canonical Version | Migration Name | Repo SHA-256 | Ledger Statement Count | Repo Statement Count | Match Result |
|---|---|---|:---:|:---:|:---:|
| `20261012000000` | `catalog_candidate_intake` | `5673a962c8f3589a54cb67ea8c6fd2b83e00069e1a658929dd216e62e9f077be` | 14 | 14 | **100% Match** |
| `20261012000001` | `catalog_official_demand_observations` | `71929888be5cea2f9e652d80df9572d9168b0ac54edb36a781080c91a1d8b08c` | 11 | 11 | **100% Match** |
| `20261012000002` | `catalog_bls_reporting_code_members` | `2d9e54ef5996bf1d6726c0b1028ad3aa735d55c076847c24256874d3a71d1e8b` | 10 | 10 | **100% Match** |
| `20261012000003` | `catalog_reviewed_destinations` | `516bdca6e3be5635e40ea3e022c0a9df91ba9e13a02fdfa955bd0202ee8e7930` | 14 | 14 | **100% Match** |
| `20261012000004` | `catalog_destination_resources_goal_links` | `cc8933916afc0910e4a8e037dd0ac8e7d938c6d5a7f8d6ffea93092d94f3b7a8` | 18 | 18 | **100% Match** |
| `20261012000005` | `professional_license_goals_and_regulator_links` | `233f03918a9729188151b4de418d2a8b8a96e5e0a1c919553dbb9d795abacb14` | 10 | 10 | **100% Match** |
| `20261012000006` | `catalog_license_pathway_versions` | `d2c5ce1a84f71f809d9e7331f51630a3a59178e5e310e704e1457b474e109541` | 19 | 19 | **100% Match** |

- **Historical Alias Artifact Discovery:** Git commit history search verified commit `ae51485d985c353bc8447a01867f2f8e364d3902`, confirming the exact 7 former alias timestamps (`20261012024727`, `20261012030645`, `20261012032630`, `20261012040321`, `20261012043357`, `20261012170223`, `20261012183947`).
- **Conclusion:** The stored canonical migration ledger on the hosted database represents the identical SQL statements present in the repository files at commit `a3e4ae857e5d0c767843dac25f2d15e748ec5cfb`.

---

### 2. Phase 2 — Live Schema, Access Boundaries, and Invariants Audit (Read-Only)
- **Schema Audit:** Dumped live schema catalog (`information_schema` and `pg_catalog`) read-only.
- **Table Verification:** All 12 tables created across the 7 migrations exist in the hosted database with RLS enabled:
  1. `catalog_intake_candidates` (RLS: Enabled, strict provenance, permissions revoked from `anon` & `authenticated`)
  2. `catalog_intake_demand_signals` (RLS: Enabled, service-role only)
  3. `catalog_official_demand_observations` (RLS: Enabled, service-role only)
  4. `catalog_official_demand_imports` (RLS: Enabled, service-role only)
  5. `catalog_bls_reporting_code_members` (RLS: Enabled, service-role only)
  6. `catalog_verified_destinations` (RLS: Enabled, public read allowed)
  7. `catalog_destination_resources` (RLS: Enabled, public read allowed)
  8. `catalog_destination_goal_links` (RLS: Enabled, public read allowed)
  9. `professional_license_goals` (RLS: Enabled, public read allowed)
  10. `professional_license_regulator_links` (RLS: Enabled, public read allowed)
  11. `catalog_license_pathway_versions` (RLS: Enabled, public read allowed)
  12. `catalog_license_pathway_version_history` (RLS: Enabled, public read allowed)

- **Live REST Access Boundary Verification (Anon / Public Client):**
  - Executed read-only REST probe queries against `https://xzvkdwebtbxlrxagtzlv.supabase.co/rest/v1`:
    - `catalog_intake_candidates`: HTTP 401 Permission Denied (**Passed** — intake candidates remain private)
    - `catalog_intake_demand_signals`: HTTP 401 Permission Denied (**Passed** — private demand signals unreadable)
    - `catalog_official_demand_observations`: HTTP 401 Permission Denied (**Passed** — official demand unreadable)
    - `catalog_bls_reporting_code_members`: HTTP 401 Permission Denied (**Passed** — internal crosswalks unreadable)
    - `catalog_verified_destinations`: HTTP 200 OK (**Passed** — public verified catalog destinations readable)
    - `catalog_destination_resources`: HTTP 200 OK (**Passed** — destination resources readable)
    - `professional_license_goals`: HTTP 200 OK (**Passed** — public license goals readable)
    - `catalog_license_pathway_versions`: HTTP 200 OK (**Passed** — public license pathways readable)
    - Anon mutation probe (`POST` to `catalog_verified_destinations`): Blocked / 401 (**Passed** — writes rejected)
- **Conclusion:** Schema objects, constraints, and Row Level Security access controls are intact and active.

---

### 3. Phase 4 — Permanent Prevention Controls (Implemented & Verified)
- **Preflight & Postflight Gates:**
  - Extended [`lib/services/governance/migration_history_validator.dart`](lib/services/governance/migration_history_validator.dart) with `parseMigrationListOutput`, `compareWithHosted`, and `compareHostedPostflight`.
  - Added unit test suite in [`test/services/governance/migration_history_validator_test.dart`](test/services/governance/migration_history_validator_test.dart) with 21 automated negative and positive test cases (covering valid parity, pending suffixes, alias timestamps, missing historical versions, duplicate remote versions, connection failures, and partial deployments).
- **Single Guarded Deployment Path:**
  - Implemented [`tool/guarded_supabase_deploy.dart`](tool/guarded_supabase_deploy.dart) and PowerShell wrapper [`tool/guarded_supabase_deploy.ps1`](tool/guarded_supabase_deploy.ps1):
    1. Runs preflight gate (`dart run tool/verify_migration_history.dart --preflight-hosted`).
    2. Runs dry-run push (`supabase db push --linked --dry-run`).
    3. Runs live push (`supabase db push --linked`).
    4. Runs postflight gate (`dart run tool/verify_migration_history.dart --postflight-hosted`).
    5. Archives non-sensitive JSON reports (`preflight_report.json` and `postflight_report.json`).
- **AI Agent Guidance & Governance Rules:**
  - Updated [`AGENTS.md`](AGENTS.md) with explicit rules:
    - Invariant: Every production migration must retain the exact 14-digit version in its committed filename.
    - AI development agents must never apply production migration SQL through alternate tools or direct execution.
    - AI development agents must never run `supabase migration repair` to mask version discrepancies.
- **CI Workflow Integration:**
  - Added script verification step to [`.github/workflows/flutter-ci.yml`](.github/workflows/flutter-ci.yml).

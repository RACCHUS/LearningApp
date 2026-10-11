# Production Official Taxonomy Import — Controlled Operator Runbook

**Environment:** Learning App, hosted Supabase project `xzvkdwebtbxlrxagtzlv` (not the bookkeeping project).  
**Status:** Workflow prepared; **NO live import has been run**.  
**Date:** 2026-10-11  
**Workflow:** `.github/workflows/controlled-official-taxonomy-import.yml` (manual `workflow_dispatch` only)  
**Previous audit:** [Hosted Catalog Baseline](HOSTED_CATALOG_BASELINE_2026-10-11.md)

## Why this is gated

The hosted Free-plan database currently has 48 two-digit CIP series only, sample-scale SOC/O*NET records and 17 learning targets. The repository's importer supports the complete pinned NCES CIP 2020 / BLS SOC 2018 / O*NET 31.0 bundle and has been validated in disposable Supabase CI, but that is NOT a hosted import.

The Supabase organization is on the **Free** plan. Daily automatic recoverable backups are not included. Before any live write, an operator must make and verify an **external, recoverable database backup**. Neither a GitHub CI run nor a copy of the seed files is such a backup. Do not store unencrypted backups or passwords in a public repository or GitHub issue.

## Phase 1 — Verify disposable staging (no production writes)

1. Check `main` is green for **Flutter CI** and **Official Taxonomy Data** and that the disposable importer ran successfully, including `taxonomy_coverage.dart --strict`.
2. Ensure `20261009000005_learning_target_catalog_provenance` is recorded as applied on hosted Supabase. It was verified on 2026-10-11.
3. Confirm official source integrity in the same code revision:
   ```bash
   dart run tool/ingest_official_taxonomies.dart --validate --refresh
   ```
   This validates pinned source checksums before any database write.
4. Review [Official Taxonomy Ingestion](OFFICIAL_DATA_INGESTION.md) and validate O*NET attribution. The pinned source versions are *not* silently upgraded.

## Phase 2 — Make an off-site backup of the **real** hosted database

From an authorized, trusted computer, use a Postgres client matching or newer than the server version (currently PostgreSQL 17). Obtain a direct/session-pooler database connection string from **Supabase Dashboard → Project → Connect**. Keep it out of chat, source control, screenshots and command history wherever possible.

For example, in **PowerShell** with a securely supplied environment variable:

```powershell
# Provide the real connection string privately in this process's environment:
# $env:LEARNINGAPP_DB_URL is set by the operator (do not commit it).

$backup = "learningapp-pre-taxonomy-$(Get-Date -Format 'yyyyMMdd-HHmmss').dump"
pg_dump --dbname="$env:LEARNINGAPP_DB_URL" --format=custom --no-owner --no-acl --file="$backup"
if ($LASTEXITCODE -ne 0) { throw "Backup failed; do not import" }

pg_restore --list "$backup" | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Backup archive unreadable; do not import" }

Get-FileHash -Algorithm SHA256 "$backup"
```

Use this as **backup verification, not full restoration proof**. Copy the resulting dump to an encrypted/off-site location controlled by the account owner and verify its size and SHA-256 there. Store the backup's external location/reference and its 64-character SHA-256 digest. A test restore into an isolated PostgreSQL environment is highly recommended. Be aware that managed-system role data, external Storage object bytes and some managed settings may require separate backup/recovery plans.

For a CLI alternative, consult [Supabase's current Database Backups guidance](https://supabase.com/docs/guides/platform/backups). Beware: `supabase db dump` **defaults to a schema-only dump** and excludes managed auth/storage schemas; `--data-only` is a separate step. A schema-only export is **not** sufficient protection for this operation.

## Phase 3 — Configure secured GitHub Actions secrets

In the `RACCHUS/LearningApp` GitHub repository, configure Actions secrets (never put secret values into workflow inputs):

- `SUPABASE_URL`: the Learning App hosted REST API root (`https://xzvkdwebtbxlrxagtzlv.supabase.co`).
- `SUPABASE_SERVICE_ROLE_KEY`: the hosted Supabase service-role secret available only to approved maintainers. It bypasses RLS: keep it off the client.

Strongly restrict repository write access, workflow dispatch, secrets access and who can modify `main`. If using GitHub Environments with manual approvals, enforce a production review rule before import.

## Phase 4 — Read-only preflight

1. Open **GitHub → LearningApp → Actions → Controlled Official Taxonomy Import → Run workflow**.
2. Select **branch `main`**.
3. Choose `operation = preflight`.
4. Set `project_ref = xzvkdwebtbxlrxagtzlv`.
5. Leave backup fields empty and run.
6. Confirm validation succeeded and inspect the downloadable aggregate `taxonomy-counts-<run ID>` JSON artifact. The before-count report should reflect an incomplete seeded hosted database until the import happens. Never interpret an HTTP/credential error as zero records.

This step downloads **pinned source files** to the isolated runner and validates the source checksums, then uses read-only requests to the hosted database. It does **not** write to production.

## Phase 5 — Execute a controlled, backup-gated live import

Proceed **only** after the backup exists off-site, is readable, and a recent disposable CI run is fully green. In the same manual workflow:

1. Select `operation = import`, on `main`, as repository owner **RACCHUS**.
2. Enter the exact project ref `xzvkdwebtbxlrxagtzlv`.
3. Set `external_backup_reference` to the precise off-site backup file/location identifier, *not* a password or signed access URL.
4. Set `external_backup_sha256` to the 64-character digest measured before the run.
5. Submit. The workflow enforces the correct target URL/ref and validates backup fields **but cannot independently prove that a backup exists or can be restored**.
6. The importer performs source verification, writes to `stg_taxonomy_*`, then invokes its atomic `finalize_official_taxonomy_import` RPC. Afterward, `taxonomy_coverage.dart --strict` verifies each pinned structural level.

The job is **never** triggered by push, PR, schedule or default deploy, and is restricted to the owner's manual dispatch from `main`.

## Phase 6 — Post-import checks and safe rollback

Compare `before.json` and `after.json` artifacts, ensure no import validation or hardcoded reference count failed, then independently re-run the Supabase read-only SQL inventory. Check that:

- full CIP series/program hierarchy, SOC 2018 (23/98/459/867 per level), and O*NET 31.0 (1,016 extensions) have been populated;
- source artifact records contain original URLs, SHA-256 and size;
- *existing* `learning_targets`, target versions, curated lessons, and user progress remain present;
- no unintended official status/approval/visibility changes occurred;
- the UI's Career and Academic discovery surfaces show expanded classification results; remember that more **classification codes** does NOT create more published courses or verified licensure pathways.

**If any check fails:** stop new runs and investigate; keep backup safe. Avoid `supabase db reset --linked`, schema rewrites, deleting current rows, or blindly re-running imports until root cause is understood. Recovery may require restoring your off-site logical backup to a separate database and carefully reconciling affected records with newer user changes, not automatically replacing the entire live project.

## Open operational limits

- This workflow cannot be triggered or have its secrets configured by this document.
- The backup attestation fields validate format only; the operator must actually create and verify a backup.
- A Free-plan Supabase project has no managed daily database backup to fall back on.
- The importer is **not** an exam/credential/license/degree/course catalog. Phase H2/H3 relationship/source work remains.

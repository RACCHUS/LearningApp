# Phase H1 — Catalog Inventory & Source Access Runbook

**Status:** Operator tooling committed; direct read-only hosted verification completed 2026-10-11 (see [verified baseline](HOSTED_CATALOG_BASELINE_2026-10-11.md)). Manual GitHub Actions repeat-audit remains available if credentials are configured.  
**Date:** 2026-10-11  
**Related:** [Phase H catalog plan](CATALOG_POPULATION_AND_COVERAGE_PLAN.md), [Official taxonomy ingestion](OFFICIAL_DATA_INGESTION.md), [Hosted migration rollout](../HOSTED_MIGRATION_ROLLOUT.md)

## 1. Two deliberately different baselines

**Local/disposable CI:** The existing `flutter-ci.yml` runs the pinned CIP 2020, SOC 2018, O*NET 31.0 production importer into a **disposable local Supabase** and now runs `tool/taxonomy_coverage.dart --strict` against it. Passing demonstrates this exact checked-in importer + migration set yields the expected pinned structural counts in the test environment. It says **nothing** about hosted Supabase or source licensing for new catalogs.

**Hosted Supabase:** `.github/workflows/hosted-catalog-coverage-audit.yml` is a **manual-only**, read-only audit of the deployed project. It cannot run without explicit `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` GitHub Actions secrets. It never writes to the database, downloads private learner rows, or records credentials. It emits aggregate counts as a JSON artifact retained for 14 days. A service-role report is needed because anonymous access is RLS-scoped and can misleadingly undercount.

**Do not confuse** `tool/taxonomy_status.dart` sample smoke-test thresholds with full catalog coverage. The local and hosted tools do not claim that thousands of **learning targets** or verified jurisdictional requirements already exist.

## 2. Before a hosted audit

1. Confirm the correct Supabase project, owners, and change-control window.
2. Run `supabase migration list --linked` from an authorized operator computer to compare hosted migration records. Do **not** run `supabase db reset`, `db push`, or `migration repair` as part of this audit.
3. Confirm hosted `20261009000005_learning_target_catalog_provenance.sql` is applied by inspecting the migration list and the `review_status` column with secure access. The read-only count CLI will report an error if this column does not exist; that is not evidence that a table has zero rows.
4. Configure the repository Actions secrets `SUPABASE_URL` (hosted REST endpoint) and `SUPABASE_SERVICE_ROLE_KEY` (read-only usage in this workflow; the key still has **full privileged capability** elsewhere). Restrict who can edit workflows, dispatch audits, and view artifacts. Rotate/revoke on suspected exposure.
5. Trigger **Actions → Hosted Catalog Coverage Audit → Run workflow** on a reviewed `main` commit. Leave `strict_release_counts` enabled initially. It compares data only, even if mismatches cause failure.
6. Open the generated `hosted-taxonomy-coverage.json` artifact. Record its generated timestamp, scope, commit SHA, exact database identity (internally), source-release matches, target type counts, published versions and course/lesson counts.
7. Store the report only in an **access-controlled** operational location and log any discrepancy. Never commit service-role keys, learner-level data, or private catalog records to this repository.

### CLI fallback (authorized machine only)

```bash
dart run tool/taxonomy_coverage.dart --registry-only
dart run tool/verify_taxonomy_source_review.dart

# This requires environment variables in a protected operator session.
dart run tool/taxonomy_coverage.dart --json --strict > hosted-taxonomy-coverage.json
```

The output is aggregate-only but includes counts of private rows visible to service role. Anon-key queries are useful only for measuring public browseability, not total inventory.

## 3. How to interpret the report

| Signal | Interpretation | Follow-up |
| --- | --- | --- |
| CIP/SOC/O*NET pinned release mismatch | Source release incomplete or materially different | Check release version, importer job, associated staging/data logs; do not infer missing taxonomy equals missing course |
| All pinned release counts pass, small target counts | Classification coverage exists but learner-facing destination content remains sparse | Prioritize linking real destinations, not creating thousands of placeholder lessons |
| `review_status` missing or API error | Hosted schema/migration/access incomplete; count **unknown** | Fix migration rollout through reviewed change control; rerun |
| More course/lesson records than expected | Not proof of published quality, coverage or ownership | Audit provenance, reviewed status and links |
| `curriculum_nodes` count small | Few authored/linked curricula | Prioritize high-demand pilot pathways |
| Reviewed-community and official target counts | A raw count only; source trust cannot be inferred from numbers | Sample individual **public** records, version and source evidence with authorized reviews |

The initial CLI does not yet measure all credential and jurisdiction relationship completeness because the Phase H2 reference graph does not exist. Label these metrics `not_implemented`, never `0%`.

## 4. Source acquisition and rights decisions

Machine-readable queue: [`data/taxonomy/source_access_review.json`](../../data/taxonomy/source_access_review.json). Every registry source has a priority, access mode, **pending permission/publication review**, responsible workstream and documentation URL. It is a **decision queue**, not legal clearance. Verify it with:

```bash
dart run tool/verify_taxonomy_source_review.dart
```

- **P0**: Existing NCES CIP, BLS SOC and O*NET imports. Verify actual hosted population and O*NET attribution/third-party exceptions before claiming release success. No new edition is auto-adopted.
- **P1**: CareerOneStop, exam issuers (NCLEX, CompTIA and others), NCES IPEDS/College Scorecard. Token/terms/rights and currency checks, then publisher/regulator verification. Do not treat school directories as guaranteed enrollment or all occupation classifications as licensure rules.
- **P2**: Credential Engine needs a separate developer agreement/permission for external product use. CASE content needs per-issuer rights. Leave bulk distribution blocked while pending.
- **P3**: ISCED/ESCO are separate international namespaces with their own versions, rights and jurisdiction interpretation.

**Useful official documentation:** [CareerOneStop API](https://api.careeronestop.org/api-explorer/), [CareerOneStop occupational-licensing limitations](https://cloudfront.careeronestop.org/Developers/Data/occupational-licenses.aspx), [Credential Engine Developer APIs](https://credentialengine.org/develop-solutions/apis/), [Credential Engine Terms](https://credentialengine.org/terms-of-use/), [O*NET license and exclusions](https://www.onetonline.org/help/license).

**Approval gate before any new bulk adapter:** approved rights/terms, stable source identifiers and terms of use, dataset freshness, content-level attribution, a provider/regulator sample check, idempotent dry run, staged QA, diff/rollback, and security review. This repository does **not** currently approve new sources for production ingestion.

## 5. Pilot gap sampling — tasks, not invented facts

These are six high-value *sample destinations* to test coverage of different product types. Their verified pathway **status is unknown until separately audited**; the fact that a seed or learning target exists does not supply a legal requirement.

| Pilot destination | Checks to perform before publication | Responsible workstream |
| --- | --- | --- |
| Florida electrician / electrical contractor | Separate job from license class, licensing authority and municipality, initial vs advanced routes, experience, exams, reciprocity, apprenticeship providers | Jurisdiction & provider data |
| Florida registered nurse | State board requirements, approved programs, NCLEX edition, alternate jurisdiction/endorsement routes, continuing education | Jurisdiction & assessments |
| BS Computer Science | CIP classification vs institution-specific offered degree, accreditation status, tuition and admissions provenance, actual program links | Institutions |
| CompTIA Security+ | Credential edition, exams/objectives, issuer prerequisites, expiration/renewal, approved resources | Credential issuers |
| SAT Math | Official current test edition/format, legitimate publicly viewable sample resources, original practice items | Assessment sources |
| Self-created hobby goal | Personal-draft visibility, search isolation, community review workflow; no official badges without moderation | Trust and community |

For each pilot, capture `source_uri`, `issuer_or_regulator`, `jurisdiction`, `source_edition`, `effective_date` (if applicable), `verified_at`, `reviewer`, `review_decision`, `unknowns`, and `upstream_change_watch`. Do not collect learner PII in coverage or issue-tracker evidence.

## 6. H1 exit gates and what remains

- [x] Phase H0 merged with full CI passing.
- [x] Full pinned taxonomy counts now checked in disposable Supabase CI using the coverage CLI.
- [x] Manual secret-backed hosted audit workflow authored (execution depends on configured secrets and dispatch).
- [x] Versioned source-access/rights decision queue created and validated by code.
- [x] Confirm hosted migration record alignment and capture direct, read-only aggregate counts (2026-10-11; see verified baseline).
- [ ] Review actual external-source rights, access, and refresh cadence with appropriate owners. No third-party rights approvals are assumed.
- [ ] Sample each pilot destination against published sources and record evidence plus explicit unknowns.
- [ ] Approve the H2 catalog entity/relationship/RLS contract before adding migrations.

The final three items need access and review outside the repository. A green CI run alone must never close them.

## 7. Verified observation (2026-10-11)

Read-only Supabase integration confirmed 48 top-level CIP series, just 24 SOC/O*NET occupation nodes, 17 published learning targets, 7 public lessons, zero courses, zero assessment items and zero taxonomy source artifacts. The catalog-provenance migration was recorded as applied. See [hosted baseline snapshot](HOSTED_CATALOG_BASELINE_2026-10-11.md) for release-specific gaps and a Supabase advisor warning. This observed snapshot replaces earlier *unknown* hosted-count assumptions, without granting rights to bulk ingest.

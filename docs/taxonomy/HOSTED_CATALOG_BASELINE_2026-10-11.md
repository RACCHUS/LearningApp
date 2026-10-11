# Verified Hosted Catalog Baseline — 2026-10-11

**Environment:** Learning App hosted Supabase project (US East).  
**Evidence:** Read-only queries through the connected Supabase tool on 2026-10-11. These are **database-wide SQL counts**; they are not demo fixture expectations.  
**No mutations:** This audit did not apply migrations, import data, or change user records.

## 1. Migration deployment and source provenance

- The recorded hosted migration history includes **`20261009000005_learning_target_catalog_provenance`** (the latest repository migration at this audit). The catalog trust migration is therefore listed as applied. Its application is not proof that every web client or downstream query behaves correctly.
- All inspected `public` tables reported RLS enabled; this does **not** imply that every grant/policy/view is safe (see Security).
- Three source release **metadata** rows exist: BLS SOC 2018, NCES CIP 2020, O*NET 31.0.
- `taxonomy_source_artifacts` has **0** rows. There is no record of official artifact downloads/complete ingestion in the hosted database; source release metadata alone does not prove complete ingestion.

## 2. Exact hosted row counts

| Entity | Exact rows | Interpretation |
| --- | ---: | --- |
| `catalog_clusters` | 12 | Seed display clusters present |
| `fields` | 48 | Seed top-level fields present |
| `external_classification_nodes` | 48 | **Only** CIP 2020 two-digit series; no 4/6-digit children |
| `occupation_nodes` | 24 | Sample-scale SOC + O*NET occupation nodes |
| `external_classification_occupation_mappings` | 9 | Example CIP-to-SOC mappings |
| `taxonomy_source_artifacts` | 0 | Full official ingest not reflected in artifact log |
| `learning_targets` | 17 | Published target count, not national coverage |
| `target_versions` | 17 | All status = `published` |
| `curriculum_nodes` | 22 | Seed/sample curriculum nodes |
| `knowledge_concepts` | 32 | Small sample concept set |
| `curriculum_node_lessons` | 6 | Curriculum-to-lesson bindings |
| `lessons` | 7 | All reported `visibility=public` |
| `courses` | 0 | No records in `courses` |
| `assessment_items` | 0 | No canonical diagnostic/mock items |
| `lesson_blocks` | 0 | No v2 rich blocks |
| `content_source_mappings` | 0 | No curriculum source citation links |

**Caution:** Some Supabase table catalog estimates reported 0 lessons; the explicit `SELECT COUNT(*)` query returned **7**. Prefer exact SQL counts over catalog estimates.

### Release-specific completeness (hosted vs pinned importer expectations)

| Release level | Hosted | Expected | Gap |
| --- | ---: | ---: | ---: |
| CIP 2020 two-digit series | 48 | 48 | 0 |
| SOC 2018 major groups | 7 | 23 | 16 |
| SOC 2018 minor groups | 1 | 98 | 97 |
| SOC 2018 broad occupations | 1 | 459 | 458 |
| SOC 2018 detailed occupations | 11 | 867 | 856 |
| O*NET 31.0 extensions | 4 | 1,016 | 1,012 |

The **48/48** top-level CIP series must not be misrepresented as a fully ingested CIP code hierarchy.

### Learner-facing target counts

| Target type | Hosted count |
| --- | ---: |
| Career | 4 |
| Academic program | 4 |
| Certification | 4 |
| Licensure exam | 1 |
| Standardized exam | 4 |
| Curriculum standard | 0 |
| **Total** | **17** |

All 17 target rows are published/public with `review_status=approved` in this database; **only 1** has `is_official=true`. A review flag or source seed is not proof of issuer verification. Do not automatically relabel all sample targets as authoritative based on this aggregate.

## 3. What this means

1. **Highest priority:** ingest and verify the already implemented, pinned official NCES CIP 2020, BLS SOC 2018 and O*NET 31.0 dataset on **a disposable/staging Supabase environment first**, then assess safe hosted ingestion after migration/backups/rights review. The existing Flutter CI does this on a disposable local database; it does **not** populate production.
2. **Next:** build reviewed relationship data between careers, programs, licenses, exams, qualifications and jurisdictions. Sample taxonomy crosswalks do not validate licensing routes.
3. **Then:** expand discoverable programs/providers and seed source-backed target entries before generating large quantities of lessons. Current 7 lessons and zero `assessment_items` mean the teaching/evaluation catalog is very limited.
4. **Quality gate:** ensure `tool/taxonomy_coverage.dart --strict` reports the real hosted structural gaps and never reports missing data as 0 without a successful database query.

## 4. Security finding from Supabase advisor

The advisor flagged one **ERROR**: `public.v_field_relations_bidirectional` is a **security-definer view**, and a read-only privilege check shows both `anon` and `authenticated` roles have SELECT permission. The view's `reloptions` were null (no `security_invoker=true`). **This is a configuration warning, not proof of an actual unauthorized data disclosure**, but it warrants a separate targeted security review before production scale-up.

There were also **10 mutable function search-path warnings** in the advisor response. GraphQL object visibility notices should be evaluated based on intended public schema exposure; simply revoking all access may break the learning catalog.

Remediation guidance: https://supabase.com/docs/guides/database/database-linter?lint=0010_security_definer_view

No grants, views, RLS policies or functions were changed as part of this audit.

## 5. Release gates / next actions

- [x] Connected Supabase project identified and real live database queried read-only.
- [x] Catalog provenance migration `20261009000005` recorded in hosted history.
- [x] Exact pinned classification / source artifact / learning target / content baseline recorded.
- [ ] Review the reported security-definer view and appropriate `security_invoker` fix with regression tests.
- [ ] Plan safe hosted full federal dataset ingestion after backup/change control, with attribution and license checks.
- [ ] Audit full source rights and high-value Florida pilot regulatory paths independently.
- [ ] Repeat hosted audit **after** approved import; check counts and source artifact metadata; never assume CI implies production is updated.

**Important:** Counts here are an observed snapshot as of 2026-10-11 and will become stale after future imports or edits. See [the operational runbook](HOSTED_BASELINE_AND_SOURCE_REVIEW.md) for repeatable rechecks.

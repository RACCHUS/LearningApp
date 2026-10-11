# Official Taxonomy Data Ingestion

Phase F stores authoritative education and labor taxonomies as versioned external
standards. The application repository intentionally does **not** vendor the full
federal source files. Instead, `tool/ingest_official_taxonomies.dart` downloads
the frozen releases from their publishers, validates them, records artifact
checksums, and then performs idempotent database upserts.

## Frozen production releases

| System | Release | Authoritative artifacts | Expected structural checks |
| --- | --- | --- | --- |
| NCES CIP | 2020 | `CIPCode2020.csv`, `Crosswalk2010to2020.csv`, `CIP2020_SOC2018_Crosswalk.xlsx` | 48 two-digit series; full 4/6-digit hierarchy; complete CIP-SOC references |
| BLS SOC | 2018 | `soc_structure_2018.xlsx`, `soc_2018_definitions.xlsx`, `soc_2010_to_2018_crosswalk.xlsx` | 23 major groups, 98 minor groups, 459 broad occupations, 867 detailed occupations |
| O*NET | 31.0 / O*NET-SOC 2019 | `Occupation Data.xlsx`, `Job Zones.xlsx` | 1,016 occupations; 923 Job Zone rows; every occupation resolves to a 2018 detailed SOC parent |

The source URLs are pinned in
`lib/services/taxonomy/official_taxonomy_sources.dart`. Do not replace them
with mirrors or scraped copies.

## Commands

Download and cache the official artifacts:

```bash
dart run tool/ingest_official_taxonomies.dart --download
```

Download (when necessary), parse, and validate without database writes:

```bash
dart run tool/ingest_official_taxonomies.dart --validate
```

Revalidate an already-downloaded bundle with the network disabled:

```bash
dart run tool/ingest_official_taxonomies.dart --validate --offline
```

Force fresh downloads:

```bash
dart run tool/ingest_official_taxonomies.dart --validate --refresh
```

Ingest only after validation succeeds:

```bash
SUPABASE_URL=... \
SUPABASE_SERVICE_ROLE_KEY=... \
dart run tool/ingest_official_taxonomies.dart --ingest-all
```

The default cache is `build/taxonomy-cache/`, which is gitignored. Override it
with `--source-dir <path>`.

## Safety model

The tool has a strict two-stage boundary:

1. **Source validation happens before any database write.** Truncated or
   structurally inconsistent datasets fail closed.
2. **Database writes require the service-role key.** Download and validation
   never require Supabase credentials.

Existing database IDs are preserved. Earlier migrations seeded representative
CIP/SOC/O*NET rows that may already be referenced by fields, targets, or
crosswalks. The official importer therefore upserts by natural source keys
(`system/version/code`) instead of replacing those primary keys.

CIP and SOC hierarchy ingestion is two-pass: rows are first upserted, the
actual database IDs are read back, then parent foreign keys are resolved using
those IDs. O*NET nodes are attached to their actual 2018 detailed-SOC parents.

## Provenance

Every downloaded file is recorded in `taxonomy_source_artifacts` with:

- source release
- authoritative source URL
- exact SHA-256 of the downloaded bytes
- file size
- retrieval timestamp

The source releases are recorded in `taxonomy_source_releases`.

NCES CIP and BLS SOC material are U.S. federal-government sources. O*NET 31.0
Database content is licensed under CC BY 4.0. The release record stores the
required O*NET attribution and license URL.

## Why `seed_taxonomy.dart` still exists

`tool/seed_taxonomy.dart` is retained as a small developer/reference fixture.
It is useful for local examples and parser work, but it is **not** the
production taxonomy population mechanism and must not be used as evidence that
Phase F contains the complete official datasets.

The production path is `tool/ingest_official_taxonomies.dart`.

## Updating releases

Do not silently point the existing release at newer agency data. A new
CIP/SOC/O*NET edition should be treated as a new source release:

1. add the new source/version metadata,
2. pin its official artifacts,
3. update structural expectations,
4. ingest as a distinct version,
5. build explicit lineage from the previous version,
6. run the complete validation and database verification before exposing it.

This keeps historical targets reproducible and prevents a current federal
download from changing the meaning of previously published learning content.

## Population and release coverage follow-up

The official importer above solves a **pinned US classification import**, not the full learning destination catalog. The additional [Catalog Population and Coverage Plan](CATALOG_POPULATION_AND_COVERAGE_PLAN.md) defines credential, exam, licensure, provider, standards and geographic acquisition, with rights/verification gates. The proposed inventory lives in [`data/taxonomy/source_registry.json`](../../data/taxonomy/source_registry.json).

The release-scoped read-only count tool is:

```bash
dart run tool/taxonomy_coverage.dart --registry-only
SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... dart run tool/taxonomy_coverage.dart --json
SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... dart run tool/taxonomy_coverage.dart --strict
```

Use a service-role key only in a secure operator environment; an anonymous key measures what RLS permits, not the complete stored dataset. The older `tool/taxonomy_status.dart` checks seed examples and one hierarchy path only, so its sample-scale thresholds are **not a production coverage gate**.

## Production import on hosted Free plan

For live hosted Supabase, use the **manual-only**, owner-gated [Controlled Production Taxonomy Import runbook](CONTROLLED_PRODUCTION_TAXONOMY_IMPORT.md). It requires an independently created, verified, off-site logical backup, pinned source validation, exact project-ref and URL checks, and post-import release/count verification. On the Free plan there is no automatic downloadable daily backup. Do **not** run the importer on production just because disposable CI is green; do not run `supabase db reset --linked`.

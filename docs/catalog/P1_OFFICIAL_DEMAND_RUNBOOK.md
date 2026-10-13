# Phase P1 — Official Demand Evidence Import

**Purpose:** Private national statistics linked to academic CIP and occupational SOC codes. These do not certify the popularity, legal requirements or issuance of a specific professional license or certification.

## Verified source and coverage

BLS publishes 2025–2035 occupational projections in its official [occupation.xlsx](https://www.bls.gov/emp/ind-occ-matrix/occupation.xlsx), sheet "Table 1.2". A GitHub Actions probe downloaded 413,398 bytes, SHA-256 `a7d060f0576f7d4f5b829b9a0bb4a6c11a12766d159ebb0e07aab5bd2e7583c5`, and the release parser found **831 unique detailed Line-item SOC records** with nonnegative annual openings. Summary rows are excluded to avoid double counting. The values are **average annual thousands of jobs**, rounded as published; a value of 10.5 is approximately 10,500 openings per year, not precisely measured job vacancies.

NCES's [IPEDS download directory](https://nces.ed.gov/ipeds/datacenter/DataFiles.aspx?fromIpeds=true&gotoReportId=7) lists 2025 provisional C2025_A completions by six-digit CIP and award level, for July 2024–June 2025. A trial at the historical direct ZIP URL returned **HTTP 404**. The exact official source ZIP must be obtained through the current Data Center release interface. No IPEDS numbers should be invented or loaded from an unverified mirror. The importer supports an **operator-supplied official ZIP** but does not use the broken guessed URL.

## Code and verification

- Migration: `supabase/migrations/20261012000001_catalog_official_demand_observations.sql` adds RLS-private official demand evidence and release manifests.
- Parser/uploader: `tool/catalog_official_demand.py`, using Python and the pinned openpyxl 3.1.5.
- Source verification command: `python tool/catalog_official_demand.py bls --validate`. This makes no database changes.
- Source-pinned import command: `python tool/catalog_official_demand.py bls --import --confirm-project xzvkdwebtbxlrxagtzlv`. Requires the Learning App URL and a modern `sb_secret_` key in private environment variables. Never use a public client key.
- One-time GitHub Actions integration: `.github/workflows/catalog-p1-import-bls-once.yml`. Only its exact reviewed merge marker triggers the hosted import.
- Unit and database tests: `tool/tests/test_catalog_official_demand.py` and `supabase/tests/catalog_official_demand_test.sql`.

The live imported rows remain invisible to learners and have a source SHA, source URL, release, metric period, unit, geography and taxonomy code. The P1 importer must not mutate existing learning targets, user accounts or courses. Idempotent repeat runs skip duplicate identities, and a different source checksum cannot silently overwrite an existing official release.

## IPEDS next step (blocked on verified source acquisition)

Get the real 2025 provisional C2025_A ZIP and its data dictionary from NCES, record its exact retrieval URL and release status, then run:

~~~bash
python tool/catalog_official_demand.py ipeds --file /path/C2025_A.zip --source-url https://the-official-nces-download-URL --validate
~~~

Validate observed exact 6-digit CIP, AWLEVEL and CTOTALT fields, exclusions of special/missing values, release date and aggregation. Only then run with `--import --confirm-project xzvkdwebtbxlrxagtzlv`. Awards conferred are **not** unique students, institutional course enrollment, seats or licensing demand.

## What this does not justify

- BLS projected job openings **do not** establish demand for a particular paid certificate or legal requirement.
- One dataset is not sufficient to assign trustworthy credential popularity scores; demand remains unranked until independent relevant measures are collected.
- Issuer certification exam volumes, credential awards, approved provider catalogs and community usage still need separately verified rights and sourcing.

## P1 BLS code reconciliation (2026-10-11)

The five nonmatching rows have been verified as **combined BLS reporting categories** rather than absent SOC 2018 classifications. The [BLS reporting-code reconciliation](P1_BLS_REPORTING_CODE_RECONCILIATION.md) defines all 13 source-backed component relationships and a private one-row-per-original-observation view. The acceptance target after deployment is **826 exact matches, 5 combined reporting codes, 0 unexplained, and 831 total**. These are explanatory links, not an allocation of 50.5k openings or other combined totals among the components.

An exploratory GitHub Actions runner requesting the live NCES Complete Data Files page encountered a redirect loop; the guessed historical C2025_A direct ZIP still returns 404. This is an access issue, **not** evidence the officially listed provisional dataset is absent. Keep IPEDS import blocked until the exact official ZIP and dictionary are acquired and validated.


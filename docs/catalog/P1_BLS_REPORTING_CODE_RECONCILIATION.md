# BLS 2025–2035 reporting-code reconciliation

**Date:** 2026-10-11. **Status:** reconciled by official BLS source, pending production deployment.

## Why five BLS rows did not join to SOC 2018

The official BLS [2025–2035 Employment Projections Table 1.2](https://www.bls.gov/emp/tables/occupational-projections-and-characteristics.htm) contains 831 detailed *line items*. A hosted comparison to our complete 2018 SOC release matched 826 rows exactly. The remaining five are combined BLS reporting codes that are **not 2018 SOC detailed occupations**. The BLS [Occupational Employment and Wage Statistics FAQ](https://www.bls.gov/oes/oes_ques.htm) explicitly documents the combined code membership.

| BLS reporting code | BLS combined reporting category | 2018 SOC component codes | Source |
|---|---|---|---|
| 21-1018 | Substance abuse, behavioral disorder and mental health counselors | 21-1011, 21-1014 | BLS OEWS FAQ |
| 25-2052 | Special education teachers, kindergarten and elementary | 25-2055, 25-2056 | BLS OEWS FAQ |
| 25-9045 | Teaching assistants, except postsecondary | 25-9042, 25-9043, 25-9049 | BLS OEWS FAQ |
| 51-2028 | Electrical, electronic and electromechanical assemblers | 51-2022, 51-2023 | BLS OEWS FAQ |
| 53-1047 | First-line supervisors of transportation and material-moving workers (except aircraft cargo handling) | 53-1042, 53-1043, 53-1044, 53-1049 | BLS OEWS FAQ |

**Critical statistical limitation:** This is source-defined membership of a combined reporting category. It is not evidence for how to *distribute* the original annual-opening number across component occupations. Do not divide the combined total evenly, duplicate the total for each component, or sum the composite and components together. That would overstate labor demand. Keep the original one BLS observation in `catalog_official_demand_observations`; use the membership relation strictly to explain its coverage.

## Implemented structures

- Append-only SQL migration `20261012000002_catalog_bls_reporting_code_members.sql` adds 13 explicitly documented member relationships, all tagged with official BLS FAQ URL and **not_allocated**.
- Private `v_catalog_bls_observation_coverage` classifies each unchanged BLS source observation as `exact_soc_2018`, `combined_reporting_code`, or `unmapped`. It always returns **one row per original BLS observation**, regardless of how many SOC occupations it includes.
- Explicit RLS and denied anonymous/authenticated access on membership and view; only service-role reads. UI pages must not show these as five new SOC official occupations.
- Disposable-database pgTAP verifies all 13 documented relations, no raw-data exposure, and a combined code's single-row classification.

## Production acceptance gate

Run independent read-only SQL:

~~~sql
select coverage_status, count(*)::integer
from public.v_catalog_bls_observation_coverage
group by coverage_status order by coverage_status;
~~~

Expected against the pinned 2025–2035 BLS import:

- 826 `exact_soc_2018`
- 5 `combined_reporting_code`
- 0 `unmapped`
- total 831; still only one BLS numeric record per reporting code.
- 13 component references all match valid active SOC 2018 nodes.

If new files or future years introduce new hybrids, fail closed and review the new official crosswalk rather than attempting similarity-based matching.

# P2g — Florida Contractor Licensure Pathways (DBPR CILB CGC & CBC)

**Source review:** 2026-10-13. **Scope:** selected examination-route steps for Florida Certified General Contractor (CGC) and Certified Building Contractor (CBC) licenses. **Not** an exhaustive legal eligibility determination.

## Product distinctions

1. **State License vs. Exam**: A Florida contractor license (issued by the Florida Department of Business and Professional Regulation, Construction Industry Licensing Board) confers legal authorization to contract throughout the state. The 3-part Florida state contractor exam (Business & Finance, Contract Administration, Project Management) is an examination hurdle, not the license.
2. **Partial Pathway Scope**: In line with the verified issuer directory, `requirements_status='not_verified'` remains recorded for complete personal background audits, financial disclosure resolutions, business entity registrations, and local municipal registrations.
3. **Statutory Combination Matrix**: Florida Statutes § 489.111(2)(c) establishes a multi-track 4-year combination matrix of field experience and accredited college education (or military service equivalency). Learning App explicitly models this as an `any` group rather than a single mandatory schooling requirement.
4. **No License Issuance**: Neither Learning App nor any platform instructor can issue a contractor license, grant local permitting rights, or guarantee eligibility.

## Regulatory Sources

- [Florida DBPR — Certified General Contractor Application Center](https://www.myfloridalicense.com/intentions2.asp?boardid=06&chBoard=true&professionid=0605), reviewed 2026-10-13.
- [Florida DBPR — Certified Building Contractor Application Center](https://www.myfloridalicense.com/intentions2.asp?boardid=06&chBoard=true&professionid=0602), reviewed 2026-10-13.
- [Florida DBPR CILB 5-A General Contractor Individual Checklist](https://www.myfloridalicense.com/CheckListDetail.asp?XACT_DEFN_ID=3077&clientCode=0605&xactCode=1030).
- [Florida DBPR CILB 5-B Building Contractor Individual Checklist](https://www.myfloridalicense.com/CheckListDetail.asp?XACT_DEFN_ID=2995&clientCode=0602&xactCode=1030).

## Technical Implementation

- **Data Manifest**: `data/catalog/florida_contractors_p2g_pathways_2026_10.json` models 2 versioned partial pathways, revision 1:
  - `dbpr_fl` / `certified-general-contractor`: 6 experience/education alternative branches (4 yrs field, 3+1, 2+2, 1+3, 4-yr college degree + 1 yr foreman, military credit) followed by 3-part exam, financial responsibility / credit score 660+, liability/workers' comp insurance, electronic fingerprinting, CILB 5-A application, and board authorization.
  - `dbpr_fl` / `certified-building-contractor`: 6 experience/education alternatives up to three stories followed by 3-part exam, financial responsibility, insurance, fingerprinting, CILB 5-B application, and board authorization.
- **Validation Engine**: `tool/catalog_p2g_contractor_pathways.py validate` checks fixed identities, schema version 1, exact DBPR URLs, and operator tree validity.
- **SQL Generator**: `tool/catalog_p2g_contractor_pathways.py render-sql` emits guarded, transactional, idempotent SQL with fail-closed checks against `catalog_verified_destinations`.
- **Test Suite**: `tool/tests/test_catalog_p2g_contractor_pathways.py` tests all invariants and negative edge cases.

## Production Deployment Gates

1. Validate manifest and tests:
   ```bash
   python tool/catalog_p2g_contractor_pathways.py validate
   python -m unittest tool/tests/test_catalog_p2g_contractor_pathways.py -v
   ```
2. Render deployment SQL:
   ```bash
   python tool/catalog_p2g_contractor_pathways.py render-sql > deploy_p2g.sql
   ```
3. Apply to Supabase production project `xzvkdwebtbxlrxagtzlv` with `service_role`.
4. Verify published pathway count increases to **6** (Nursing RN/LPN + Insurance 2-20 & 2-15 + Contractors CGC & CBC).
5. Verify anonymous session sees all 6 approved pathways through RLS.

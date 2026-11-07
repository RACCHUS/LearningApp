# P2k — Florida DBPR Community Association Manager (CAM) Licensure Pathway

**Revision 1 source review:** 2026-11-07.  
**Regulator:** Florida Department of Business and Professional Regulation (DBPR) — Regulatory Council of Community Association Managers (RCCAM).  
**Scope:** Selected regulator-sourced steps for Florida Community Association Manager (CAM) licensure; not a formal legal determination of eligibility.

---

## 1. Regulatory Authorities and Source Grounding

- **Statutory Authority**: Florida Statutes Chapter 468, Part VIII (Community Association Management), specifically:
  - [F.S. § 468.432](https://www.flsenate.gov/Laws/Statutes/2026/468.432) (*Licensure of community association managers*).
  - [F.S. § 468.433](https://www.flsenate.gov/Laws/Statutes/2026/468.433) (*Licensure by examination; endorsement*).
  - [F.S. § 468.4336](https://www.flsenate.gov/Laws/Statutes/2026/468.4336) (*Continuing education*).
- **Administrative Rules**: Florida Administrative Code (F.A.C.) Chapters 61-20 (*Regulatory Council of Community Association Managers*) and 61E14 (*Standards of Professional Conduct*).
- **Regulator Application / Checklist**: [DBPR Intentions / Application Center](https://www.myfloridalicense.com/intentions2.asp?boardid=38&chBoard=true&professionid=3801) and [Form DBPR CAM 1 Application / Candidate Checklist](https://www.myfloridalicense.com/CheckListDetail.asp?XACT_DEFN_ID=5042&clientCode=3801&xactCode=1010).

---

## 2. Structured Qualification Alternatives

Under F.S. § 468.433 and F.A.C. Rule 61-20.5011, initial qualification offers two pathways:

1. **Standard Pre-Licensing Education Route**:
   - Complete at least 16 hours of department-approved pre-licensure education within 12 months prior to passing the examination.
   - Course curriculum covers Florida community association law, budgets and reserves, financial reporting, insurance, meeting notice and quorum, election procedures, and recordkeeping.
2. **Endorsement Alternative Route**:
   - Applicants holding an active, valid license to practice community association management in another state or jurisdiction with substantially equivalent standards may qualify via endorsement under F.S. § 468.433(4).
   - Requires submission of official state license verification and Form DBPR CAM 1-A.

---

## 3. Mandatory Steps Across All Routes

- **Basic Eligibility**: Must be at least 18 years of age and of good moral character (F.S. § 468.433(2)(b)-(c)).
- **Electronic Fingerprinting**: Must submit electronic fingerprints through an FDLE-approved Livescan service vendor. Use the exact Regulatory Council of Community Association Managers Originating Agency Identifier (ORI) `FL921932Z`. (Do not use Real Estate ORI `FL920010Z` or Contractor ORI `FL920250Z`).
- **Application to DBPR**: Complete and submit Form DBPR CAM 1 (Application for Community Association Manager Initial License By Examination) with required state licensing and application fees.
- **State Examination (Pearson VUE)**:
   - Pass the 100-question Florida Community Association Manager Examination with a score of 75% or higher.
   - Examination covers legal operations, budgets and reserves, insurance, maintenance, meetings, elections, and property management duties.
   - Examination passing scores remain valid for 12 months.
- **Continuing Education for Biennial Renewal**:
   - Licensees must complete 20 hours of approved continuing education each biennium (including 4 hours of legal updates, 4 hours of insurance/financial management, 4 hours of operation/maintenance, and 8 hours of electives) per F.S. § 468.4336.

---

## 4. Operational Safety and Immutability

- **Destination Promotion**: Promotes candidate `("dbpr_fl", "community-association-manager")` from `catalog_intake_candidates` with approved review status and rights into `public.catalog_verified_destinations` at editorial order 28.
- **Resource Link**: Adds `dbpr-cam1-checklist` to `public.catalog_destination_resources` at sort order 28.
- **Pathway Version**: Inserts Revision 1 into `public.catalog_license_pathway_versions` with explicit evidence provenance (`source_retrieved_at`, `review_note`, `uncertainty_status = 'conditional'`).

---

## 5. Local Validation Commands

```bash
python3 tool/catalog_p2k_cam_pathways.py validate
python3 -m unittest tool/tests/test_catalog_p2k_cam_pathways.py -v
python3 tool/catalog_p2k_cam_pathways.py sql
```


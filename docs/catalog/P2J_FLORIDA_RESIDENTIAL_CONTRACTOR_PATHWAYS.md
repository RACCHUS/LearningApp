# P2j — Florida DBPR Certified Residential Contractor Licensure Pathway

**Revision 1 source review:** 2026-11-07.  
**Regulator:** Florida Department of Business and Professional Regulation (DBPR) — Construction Industry Licensing Board (CILB).  
**Scope:** Selected regulator-sourced steps for Florida Certified Residential Contractor licensure; not a formal legal determination of eligibility.

---

## 1. Regulatory Authorities and Source Grounding

- **Statutory Authority**: Florida Statutes Chapter 489, Part I (Contracting), specifically [F.S. § 489.111](https://www.flsenate.gov/Laws/Statutes/2026/489.111) (*Licensure by examination*).
  - Scope restriction: F.S. § 489.105(3)(c) defines residential contractor scope as construction, remodeling, repair, or improvement of one-family, two-family, or townhome residences not exceeding three stories in height.
- **Administrative Rules**: Florida Administrative Code (F.A.C.) Rule 61G4 (*Construction Industry Licensing Board*).
- **Regulator Application / Checklist**: [DBPR Intentions / Application Center](https://www.myfloridalicense.com/intentions2.asp?boardid=06&chBoard=true&professionid=0601) and [Form DBPR CILB 5-C Application / Candidate Checklist](https://www.myfloridalicense.com/CheckListDetail.asp?XACT_DEFN_ID=2996&clientCode=0601&xactCode=1030).

---

## 2. Structured Prerequisites & Alternatives

### Practical Experience / Education Matrix (F.S. § 489.111(2)(c))
1. **Accredited Degree Route**: Four-year engineering, architecture, or building construction degree from an accredited college plus one year of proven residential construction experience.
2. **Foreman + 3 Years College**: One year as a foreman plus at least 3 years (90 semester hours) of accredited college credits.
3. **Worker + Foreman + 2 Years College**: One year as a skilled worker, one year as a foreman, and at least 2 years (60 semester hours) of college credits.
4. **Worker + Foreman + 1 Year College**: Two years as a skilled worker, one year as a foreman, and at least 1 year (30 semester hours) of college credits.
5. **Practical Experience Route**: Four years of active experience as a skilled worker or foreman, with at least one year as a foreman in residential contracting.
6. **Military Veteran Routes**:
   - 3 years military service + 1 year foreman experience.
   - 2 years military service + 1 year foreman + 1 year worker/foreman.
   - 1 year military service + 1 year foreman + 2 years worker/foreman.

### Trade Experience Scope
- Must document experience in at least 4 of the residential construction experience areas listed on Form CILB 5-C.
- Work must strictly involve one-family, two-family, or townhome residential structures not exceeding three stories in height.

---

## 3. Mandatory Steps Across All Routes

- **Electronic Fingerprinting**: Submit electronic fingerprints through an FDLE-approved Livescan service vendor using DBPR Construction Industry Licensing Board ORI `FL920250Z`.
- **Financial Responsibility & Credit Rating**:
  - Personal FICO credit score $\ge 660$ from a Board-approved reporting agency.
  - If FICO $< 660$, complete a Board-approved 14-hour financial responsibility course.
- **State Licensure Examination (Pearson VUE)**:
  - Pass the Florida State Construction Examination: Business & Finance Examination and Residential Trade Knowledge Examination. Scores are valid for 4 years from the test date.
- **Application to DBPR**: Complete and submit Form DBPR CILB 5-C with required state application fees.
- **Insurance for Active Licensure**: Must provide proof of public liability and property damage insurance ($100,000 public liability / $25,000 property damage) and workers' compensation coverage (or valid state exemption).

---

## 4. Operational Safety and Immutability

- **Destination Promotion**: Promotes `("dbpr_fl", "certified-residential-contractor")` with matching approved review metadata into `public.catalog_verified_destinations`.
- **Resource Link**: Adds `cilb-5c-checklist` to `public.catalog_destination_resources`.
- **Pathway Version**: Inserts Revision 1 into `public.catalog_license_pathway_versions` with explicit evidence provenance (`source_retrieved_at`, `review_note`, `uncertainty_status = 'conditional'`).

---

## 5. Local Validation Commands

```bash
python3 tool/catalog_p2j_contractor_pathways.py validate
python3 -m unittest tool/tests/test_catalog_p2j_contractor_pathways.py -v
python3 tool/catalog_p2j_contractor_pathways.py sql
```


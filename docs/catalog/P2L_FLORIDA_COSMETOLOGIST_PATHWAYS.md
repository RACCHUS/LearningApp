# P2l — Florida DBPR Cosmetologist Licensure Pathway

**Revision 1 source review:** 2026-11-07.  
**Regulator:** Florida Department of Business and Professional Regulation (DBPR) — Board of Cosmetology.  
**Scope:** Selected regulator-sourced steps for Florida Cosmetologist licensure; not a formal legal determination of eligibility.

---

## 1. Regulatory Authorities and Source Grounding

- **Statutory Authority**: Florida Statutes Chapter 477 (Cosmetology Act), specifically:
  - [F.S. § 477.019](https://www.flsenate.gov/Laws/Statutes/2026/477.019) (*Cosmetologists; qualifications; licensure; supervised practice; license renewal*).
  - [F.S. § 477.0201](https://www.flsenate.gov/Laws/Statutes/2026/477.0201) (*Specialty registration*).
- **Administrative Rules**: Florida Administrative Code (F.A.C.) Chapter 61G5 (*Board of Cosmetology*).
- **Regulator Application / Checklist**: [DBPR Intentions / Application Center](https://www.myfloridalicense.com/intentions2.asp?boardid=05&chBoard=true&professionid=0501) and [Form DBPR COSMO 1 Application / Candidate Checklist](https://www.myfloridalicense.com/CheckListDetail.asp?clientCode=0501&xactCode=1010).

---

## 2. Structured Qualification Alternatives

Under F.S. § 477.019 and F.A.C. Chapter 61G5, initial qualification offers two alternatives:

1. **Licensed Cosmetology School Training Route**:
   - Complete at least 1,200 hours of Board-approved cosmetology training at a licensed Florida cosmetology school.
   - Curriculum covers hair styling, haircutting, hair coloring, chemical services, skin care (facials), nail care (manicures/pedicures), sanitation, sterilization, and Florida laws/rules.
   - School submits electronic completion verification directly to DBPR.
2. **Endorsement Alternative Route**:
   - Applicants holding an active, valid cosmetologist license from another state or country whose qualification requirements were substantially equivalent or who documented 1,000+ hours plus active practice may qualify via endorsement under F.S. § 477.019(5).
   - Requires submission of certified license history and Form DBPR COSMO 2.

---

## 3. Mandatory Steps Across All Routes

- **Basic Eligibility**: Must be at least 16 years of age or hold a high school diploma or equivalent (F.S. § 477.019(2)).
- **HIV/AIDS Continuing Education**: Must complete a Board-approved 4-hour HIV/AIDS education course within two years prior to application.
- **Electronic Fingerprinting**: Must submit electronic fingerprints through an FDLE-approved Livescan service vendor. Use the exact Board of Cosmetology Originating Agency Identifier (ORI) `FL924780Z`.
- **Application to DBPR**: Complete and submit Form DBPR COSMO 1 (Application for Cosmetologist License by Examination) with required state licensing fees.
- **Two-Part State Examination (Pearson VUE)**:
   - Candidates must pass both sections of the Florida Cosmetology Licensure Examination administered by Pearson VUE:
     1. **Written Theory Examination**: Covers sanitation, safety, sterilization, chemicals, laws, and rules.
     2. **Written Clinical Examination**: Covers client consultation, hair/scalp analysis, color formulation, haircutting, and chemical processing.
   - Passing scaled score of 75 or higher required on each section.
- **Continuing Education for Biennial Renewal**:
   - Licensees must complete 10 hours of Board-approved continuing education each biennium (including 1 hr HIV/AIDS, 3 hrs sanitation/sterilization, 1 hr OSHA/safety, 2 hrs laws/rules, 1 hr workers' compensation, 2 hrs electives) per F.S. § 477.019(7).

---

## 4. Operational Safety and Immutability

- **Destination Promotion**: Promotes candidate `("dbpr_fl", "cosmetologist")` from `catalog_intake_candidates` with approved review status and rights into `public.catalog_verified_destinations` at editorial order 29.
- **Resource Link**: Adds `dbpr-cosmo1-checklist` to `public.catalog_destination_resources` at sort order 29.
- **Pathway Version**: Inserts Revision 1 into `public.catalog_license_pathway_versions` with explicit evidence provenance (`source_retrieved_at`, `review_note`, `uncertainty_status = 'conditional'`).

---

## 5. Local Validation Commands

```bash
python3 tool/catalog_p2l_cosmetologist_pathways.py validate
python3 -m unittest tool/tests/test_catalog_p2l_cosmetologist_pathways.py -v
python3 tool/catalog_p2l_cosmetologist_pathways.py sql
```


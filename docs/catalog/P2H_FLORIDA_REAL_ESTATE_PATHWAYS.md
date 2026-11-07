# P2h — Florida DBPR Real Estate Sales Associate Licensure Pathway

**Revision 1 source review:** 2026-11-07.  
**Regulator:** Florida Department of Business and Professional Regulation (DBPR) — Florida Real Estate Commission (FREC).  
**Scope:** Selected regulator-sourced steps for Florida Real Estate Sales Associate licensure; not a formal legal determination of eligibility.

---

## 1. Regulatory Authorities and Source Grounding

- **Statutory Authority**: Florida Statutes Chapter 475, Part I (Real Estate License Law), specifically [F.S. § 475.17](https://www.flsenate.gov/Laws/Statutes/2026/475.17) (*Qualifications for practice*).
- **Administrative Rules**: Florida Administrative Code (F.A.C.) Rule 61J2-3 (*Education and Examination Requirements*).
- **Regulator Application / Checklist**: [DBPR Intentions / Application Center](https://www.myfloridalicense.com/intentions2.asp?boardid=25&chBoard=true&div=Real+Estate) and [Form DBPR RE 1 Application / Candidate Checklist](https://www.myfloridalicense.com/CheckListDetail.asp?XACT_DEFN_ID=750&clientCode=2501&xactCode=1010).

---

## 2. Structured Qualification Alternatives

Under F.S. § 475.17 and Rule 61J2-3.008, qualification for examination and licensure offers four mutually exclusive alternatives:

1. **Standard Course Route**:
   - Satisfactorily complete a FREC-approved 63-classroom-hour pre-licensing Course I for sales associates.
   - Pass the end-of-course examination with a grade of 70% or higher.
   - Certificate remains valid for two years from the course examination date.
2. **Accredited Real Estate Degree Exemption**:
   - Individuals holding an accredited four-year college degree or higher with a major in real estate are exempt from the 63-hour pre-licensing education (F.S. § 475.17(2)). State examination is still required.
3. **Active Florida Bar Member Exemption**:
   - Active members in good standing of The Florida Bar are exempt from the 63-hour pre-licensing course (F.S. § 475.17(2)). State examination is still required.
4. **Mutual Recognition Agreement Route**:
   - Non-Florida residents holding a current, valid, active real estate license in a state with a qualifying mutual recognition agreement (Alabama, Arkansas, Connecticut, Georgia, Illinois, Kentucky, Mississippi, Nebraska, Rhode Island, or West Virginia) are exempt from pre-licensing education and the general principles exam section. They must take the 40-question Florida Real Estate Law exam.

---

## 3. Mandatory Steps Across All Routes

- **Basic Eligibility**: Must be at least 18 years of age and hold a high school diploma or equivalent (GED). A United States Social Security number is required under F.S. § 455.213.
- **Electronic Fingerprinting**: Must submit electronic fingerprints via an FDLE-approved Livescan service vendor using DBPR Originating Agency Identifier (ORI) `FL920010Z`.
- **Application to DBPR**: Complete and submit Form DBPR RE 1 (online or paper) with required state application fees.
- **State Examination (Pearson VUE)**:
  - Standard candidates: Pass the 100-question comprehensive state examination with a scaled score of 75 or higher.
  - Mutual recognition candidates: Pass the 40-question Florida Real Estate Law exam with a score of 30 or higher (75%).
- **Activation / Broker Affiliation**: Initial license is issued in inactive status. To practice, the sales associate must be registered under an active Florida licensed real estate broker or owner-developer via DBPR Form RE 11.
- **First Renewal Post-Licensing Requirement**: Must complete a 45-hour FREC-approved post-licensing course prior to the initial expiration date. Under F.S. § 475.17(3), failure to complete this requirement causes the license to become null and void automatically without grace period or extension.

---

## 4. Operational Safety and Immutability

- **Identity**: `("dbpr_fl", "real-estate-sales-associate")`. Matches the existing reviewed destination in `public.catalog_verified_destinations`.
- **Revision 1**: Stored as an immutable revision in `public.catalog_license_pathway_versions`.
- **Evidence Provenance**: Compliant with `20261106030000_catalog_pathway_evidence_provenance.sql`:
  - `source_retrieved_at`: Explicitly recorded timestamp.
  - `review_note`: Complete statutory rationale and scope boundaries ($\ge 40$ chars).
  - `uncertainty_status`: `'conditional'` (selected regulator steps, not comprehensive legal determination).
  - `pathway_kind`: `'initial_licensure'`.

---

## 5. Local Validation Commands

```bash
python3 tool/catalog_p2h_real_estate_pathways.py validate
python3 -m unittest tool/tests/test_catalog_p2h_real_estate_pathways.py -v
python3 tool/catalog_p2h_real_estate_pathways.py sql
```


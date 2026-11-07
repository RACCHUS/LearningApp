# P2i — Florida DBPR Real Estate Broker Licensure Pathway

**Revision 1 source review:** 2026-11-07.  
**Regulator:** Florida Department of Business and Professional Regulation (DBPR) — Florida Real Estate Commission (FREC).  
**Scope:** Selected regulator-sourced steps for Florida Real Estate Broker licensure; not a formal legal determination of eligibility.

---

## 1. Regulatory Authorities and Source Grounding

- **Statutory Authority**: Florida Statutes Chapter 475, Part I (Real Estate License Law), specifically [F.S. § 475.17](https://www.flsenate.gov/Laws/Statutes/2026/475.17) (*Qualifications for practice*).
  - F.S. § 475.17(2)(b): 24-month sales associate experience prerequisite in prior 5 years under an active broker.
  - F.S. § 475.17(2): Four-year degree in real estate education exemption.
  - F.S. § 475.17(3): Mandatory 60-hour post-licensing education prior to first renewal.
- **Administrative Rules**: Florida Administrative Code (F.A.C.) Rule 61J2-3 (*Education and Examination Requirements*).
- **Regulator Application / Checklist**: [DBPR Intentions / Application Center](https://www.myfloridalicense.com/intentions2.asp?boardid=25&chBoard=true&div=Real+Estate) and [Form DBPR RE 2 Application / Candidate Checklist](https://www.myfloridalicense.com/CheckListDetail.asp?XACT_DEFN_ID=752&clientCode=2501&xactCode=1010).

---

## 2. Structured Prerequisites & Alternatives

### Experience Prerequisite (F.S. § 475.17(2)(b))
1. **Florida Sales Associate Experience**: Hold an active Florida real estate sales associate license for at least 24 months during the preceding 5 years under an active broker.
2. **Out-of-State / Jurisdictional Experience**: Document at least 24 months of active licensed real estate experience in another state or jurisdiction in the preceding 5 years.
3. **Mutual Recognition Reciprocity**: Qualify under mutual recognition as an active licensed broker in a recognized reciprocal state (AL, AR, CT, GA, IL, KY, MS, NE, RI, WV).

### Pre-Licensing Education (Rule 61J2-3.008)
1. **Standard Course Route**: Complete a FREC-approved 72-classroom-hour pre-licensing Course II for brokers and pass the course end exam with $\ge 70\%$. Certificate valid for 2 years.
2. **Real Estate Degree Exemption**: Individuals holding an accredited four-year college degree or higher with a major in real estate are exempt from Course II (F.S. § 475.17(2)).
3. **Mutual Recognition Exemption**: Non-Florida residents qualifying under mutual recognition are exempt from Course II.
*(Note: Unlike sales associates, active Florida Bar members are NOT exempt from the 72-hour broker pre-licensing course unless they hold an accredited four-year real estate degree).*

---

## 3. Mandatory Steps Across All Routes

- **Electronic Fingerprinting**: Submit electronic fingerprints through an FDLE-approved Livescan service vendor using DBPR ORI `FL920010Z`.
- **Application to DBPR**: Complete and submit Form DBPR RE 2 with required state application fees.
- **State Examination (Pearson VUE)**:
  - Standard candidates: Pass the 100-question comprehensive broker examination with a scaled score of 75 or higher.
  - Mutual recognition candidates: Pass the 40-question Florida Real Estate Law exam with a score of 30 or higher (75%).
- **Activation / Brokerage Entity Registration**: Activate license as a sole proprietor broker, qualifying broker for a corporation/LLC, or broker associate using Form DBPR RE 13.
- **First Renewal Post-Licensing Requirement**: Complete 60 hours of FREC-approved broker post-licensing education prior to initial expiration (F.S. § 475.17(3); failure causes license to become null and void).

---

## 4. Operational Safety and Immutability

- **Destination Promotion**: Promotes `("dbpr_fl", "real-estate-broker")` from candidate intake seed into `public.catalog_verified_destinations` with matching approved review metadata.
- **Resource Link**: Adds `dbpr-re2-broker-checklist` to `public.catalog_destination_resources`.
- **Pathway Version**: Inserts Revision 1 into `public.catalog_license_pathway_versions` with explicit evidence provenance (`source_retrieved_at`, `review_note`, `uncertainty_status = 'conditional'`).

---

## 5. Local Validation Commands

```bash
python3 tool/catalog_p2i_broker_pathways.py validate
python3 -m unittest tool/tests/test_catalog_p2i_broker_pathways.py -v
python3 tool/catalog_p2i_broker_pathways.py sql
```


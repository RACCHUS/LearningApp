# P2e — Florida Regulator Pathway Evidence Audit and Revision 2

**Review date:** 2026-11-06. **Scope:** six existing Florida RN, LPN, DFS 2-20, DFS 2-15, CGC and CBC pathway records. Revision 2 is prepared as an immutable successor to revision 1. This is selected regulator-sourced guidance, not legal advice or an individual eligibility determination.

## Publication safety

- Revision 1 records are never edited. The renderer retires revision 1 and inserts revision 2 with `supersedes_revision=1` in one transaction.
- This correction changes only source manifests, validators, tests and documentation. It does not run generated SQL against hosted Supabase or change live rows.
- Each new revision records its retrieval timestamp, review note, uncertainty state and pathway kind.
- The issuer directory's comprehensive requirements status remains unchanged.

## Florida Board of Nursing — RN and LPN

Official source: [Florida Board of Nursing — RN & LPN](https://floridasnursing.gov/nurse-rn-lpn/).

Revision 2 separates three initial Florida licensure routes within each existing RN/LPN destination: (1) first-time licensure by examination; (2) initial licensure after the applicant has already passed NCLEX, with verification of the existing passing result and no repeat exam; and (3) initial licensure through MOBILE endorsement. The MOBILE branch includes active unencumbered comparable license, national exam/certification, two years of active practice in the prior four years, NPDB and disciplinary-history conditions, verification, application and fingerprints. RN pre-licensure MSN/higher education remains RN-specific; Practical Nursing Equivalency remains LPN-specific. Re-examination and multistate upgrade are outside this selected pathway.

## Florida DFS — General Lines 2-20

Official sources: [DFS resident 2-20 guide](https://www.myfloridacfo.com/docs-sf/insurance-agents-and-agency-services-libraries/agents-docs/licensure/agents-adjusters/2-20-resident-general-lines.pdf?sfvrsn=a4426e2d_14) and [DFS qualifications directory](https://www.myfloridacfo.com/division/agents/licensing/agents-and-adjusters/qualifications).

Revision 2 models six separate alternatives: 200-hour approved course; one year of full-time responsible duties across all listed property/casualty lines; one year as a licensed and appointed 4-40/20-44/0-55 representative plus 40-hour approved course; accredited insurance degree with 18 semester hours across property, casualty, health and commercial insurance; equivalent resident license held continuously one year with Florida application within 90 days of Florida residency; and CPCU designation. CIC is removed because the reviewed resident guide lists CPCU, not CIC. Exam exemptions and prior passing results are conditional. Appointment validity and 48-month unappointed expiration are retained.

## Florida DFS — Life, Health and Variable Annuity 2-15

Official sources: [DFS resident 2-15 guide](https://www.myfloridacfo.com/docs-sf/insurance-agents-and-agency-services-libraries/agents-docs/licensure/agents-adjusters/2-15-resident-health-life-agent-license.pdf) and [DFS qualifications directory](https://www.myfloridacfo.com/division/agents/licensing/agents-and-adjusters/qualifications).

Revision 2 models the 60-hour route; the combined route as (one of 30-hour life/annuity course, ChFC or FLMI) AND (one of 40-hour health course, CEBS, ChHC, HIA, REBC or RHU); the nine-credit-hour degree alternative; equivalent-license/90-day transfer exemption; reciprocal-state equivalent license within four years (prelicensing waiver, exam still required); and CLU exam exemption. Appointment validity and 48-month unappointed expiration are retained.

## Florida DBPR/CILB — Certified General Contractor 5-A

Official sources: [CILB 5-A individual CGC form](https://www2.myfloridalicense.com/pro/cilb/documents/CILB5A_Certified_Contractor_Individual_General.pdf) and [2026 Florida Statutes §489.111](https://www.flsenate.gov/Laws/Statutes/2026/489.111).

Revision 2 corrects the degree route to an accredited four-year construction-related degree plus one year of proven experience applicable to the category. It adds the exact worker/foreman/college-credit combinations, three military-veteran combinations, and CGC upgrade route for an active certified residential or building license held at least four years. It also adds the CGC-specific four-or-more experience areas and one year constructing structures at least four stories. Active-status financial responsibility is not a bond alternative: the form requires a FICO-derived report; a score of 660 or more plus no unsatisfied judgments/liens meets the stated standard, while below 660 requires a Board-approved 14-hour course. The form states $300,000 public liability and $50,000 property damage for general/building contractors; workers' compensation or exemption is required.

## Florida DBPR/CILB — Certified Building Contractor 5-B

Official sources: [CILB 5-B individual CBC form](https://www2.myfloridalicense.com/pro/cilb/documents/CILB5B_Certified_Contractor_Individual_Building.pdf) and [2026 Florida Statutes §489.111](https://www.flsenate.gov/Laws/Statutes/2026/489.111).

Revision 2 uses the same base degree/worker/foreman/college-credit and military alternatives, but preserves the class-specific upgrade route: active certified residential contractor held at least three years. The 5-B form requires experience in at least four of its six listed areas; it does not impose the CGC four-story requirement. Active-status financial and insurance conditions are separate from inactive status. The same 660/FICO and 14-hour course rule applies; no licensing-bond alternative is claimed.

## Explicit limits

- Contractor out-of-state certification by endorsement is not included in these examination-oriented records.
- Exam score thresholds, exam-part counts and fees are not inferred where the reviewed source forms do not establish them.
- All pathways remain `selected_steps_only`; the app must not claim complete eligibility or guarantee licensure.
- Generated SQL is an administrator-only artifact. This PR does not authorize production database publication.

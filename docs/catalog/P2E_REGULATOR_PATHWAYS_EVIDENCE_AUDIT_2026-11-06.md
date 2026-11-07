# P2e — Regulator Pathway Evidence Audit

**Review date:** 2026-11-06  
**Scope:** Source audit of the six Florida pathway records already introduced by P2e/P2f/P2g. This is not a legal opinion and does not determine individual eligibility.

## Finding

The versioned pathway foundation already exists: the database stores immutable revisions, nested all/any expressions, jurisdiction, source URL, source-check/review dates, reviewer, effective dates, supersession, and publication status. RLS exposes only approved, current, linked professional-license pathways, with a 180-day source-freshness limit.

The original model did not separately retain the source retrieval timestamp, reviewer rationale on the database row, an explicit uncertainty state, or pathway category (initial license vs exam-only, prelicense training, CE, appointment, authorization, renewal, endorsement, or reciprocity). Migration 20261106030000_catalog_pathway_evidence_provenance.sql adds these fields and requires them for any newly published revision. Existing published rows are not silently rewritten.

## Official source review

### Florida DFS — General Lines 2-20

The official resident 2-20 PDF presents distinct OR alternatives:
- A 200-hour approved property/casualty course, with the state exam.
- One year in the prior four years of responsible full-time insurance duties across all listed lines, with the state exam.
- One year in the prior four years as a licensed and appointed 4-40, 20-44, or 0-55 representative plus a 40-hour approved course, with the state exam.
- An accredited insurance degree with at least 18 semester hours across property, casualty, health, and commercial insurance; exam-exempt.
- Equivalent resident license held continuously for at least one year and Florida application within 90 days of becoming a Florida resident; exam-exempt.
- CPCU designation; exam-exempt.

The current P2f tree does not accurately express all these branches and includes a CIC alternative not established by this source. The 2-20 PDF itself confirms that the license requires an appointment to be valid and expires if unappointed for 48 months (Section 626.431(3)); do not omit that source-supported rule. The PDF warns applicants to ensure they have the current version.

Source: https://www.myfloridacfo.com/docs-sf/insurance-agents-and-agency-services-libraries/agents-docs/licensure/agents-adjusters/2-20-resident-general-lines.pdf

### Florida DFS — Life & Health 2-15

The official resident 2-15 PDF documents:
- A 60-hour approved life/health/variable-annuity course, with the state exam.
- A combined alternative: a 30-hour life/annuity course or specified ChFC/FLMI designation AND one of several health-course/designation alternatives; exam required.
- An accredited degree with at least nine credit hours covering health, life, annuities, and variable contracts; exam-exempt.
- Equivalent out-of-state resident license routes with different timing and exam consequences.
- CLU designation; exam-exempt.

The existing P2f tree collapses these combinations and does not fully encode their AND/OR structure. The 2-15 PDF also confirms that the license requires an appointment to be valid and expires if unappointed for 48 months (Section 626.431(3)). Rebuild from the current PDF before issuing a new public revision.

Source: https://www.myfloridacfo.com/docs-sf/insurance-agents-and-agency-services-libraries/agents-docs/licensure/agents-adjusters/2-15-resident-health-life-agent-license.pdf

### Florida Board of Nursing — RN and LPN

The current Board page distinguishes initial licensure by examination, already-passed-NCLEX applications, re-examination, and MOBILE endorsement. It lists multiple education routes; the RN prelicensure MSN route is RN-specific, while Practical Nursing Equivalency (PNEQ) is an LPN-specific alternative for eligible applicants already enrolled in an RN program. It also describes electronic fingerprinting/Level 2 screening, application review, NCLEX eligibility, and state license issuance as separate steps.

The existing P2e tree captures several education alternatives but should distinguish the already-passed-NCLEX route and MOBILE endorsement from initial examination. NCLEX is an exam, not the state-issued license.

Source: https://floridasnursing.gov/nurse-rn-lpn/

### Florida DBPR/CILB — Certified General Contractor (5-A) and Certified Building Contractor (5-B)

The current DBPR individual application checklists confirm that certification exam, experience/education qualification, fingerprinting, financial responsibility, insurance, and application are separate requirements.

The July 2024 CILB 5-A and 5-B forms specify alternative qualification methods: construction-related degree plus experience; combinations of worker/foreman experience and accredited college credits; four years of qualifying work with foreman experience; military routes; and an upgrade route. Details differ by license: the general-contractor form requires experience across at least four experience areas and at least one year on structures four stories or higher; the building-contractor form requires experience across at least four listed areas and has a different upgrade route. The 5-A upgrade route refers to a certified residential or building contractor active for at least four years; the 5-B route refers to a certified residential contractor active for at least three years.

The existing P2g tree's blanket military/degree/experience claims and credit-score/bond description need reconciliation to the individual forms. The forms describe a Board-approved 14-hour financial responsibility course when the FICO-derived score is below 660; do not replace that with an assumed bond alternative. The DBPR checklist directs out-of-state applicants who have not passed Florida's certification exam to the separate Certification by Endorsement application.

Sources:
- CILB 5-A: https://www2.myfloridalicense.com/pro/cilb/documents/CILB5A_Certified_Contractor_Individual_General.pdf
- CILB 5-B: https://www2.myfloridalicense.com/pro/cilb/documents/CILB5B_Certified_Contractor_Individual_Building.pdf
- 5-A checklist: https://www.myfloridalicense.com/CheckListDetail.asp?XACT_DEFN_ID=3077&clientCode=0605&xactCode=1030
- 5-B checklist: https://www.myfloridalicense.com/CheckListDetail.asp?XACT_DEFN_ID=2995&clientCode=0602&xactCode=1030

## Safe next steps

1. Keep current published rows immutable; do not edit old revisions in place.
2. Prepare new revisions only after each path is rebuilt from exact current regulator forms/pages, with recorded retrieval timestamp, review note, uncertainty state, and pathway kind.
3. Model AND/OR subgroups faithfully. In particular, 2-15 combined life + health alternatives are nested AND/OR groups, not independent alternatives.
4. Split nursing examination, already-passed-NCLEX, and MOBILE endorsement pathways. Keep education, exam, background screening, application, state authorization, and appointment distinct.
5. Split contractor 5-A and 5-B qualification methods, including class-specific experience-area and upgrade rules. Treat endorsement as a separate route.
6. Link provider courses only when current offering and permission are established. No provider course is implied by a regulator requirement.
7. Do not add fees or popularity ranks from stale or incomparable evidence. Unknown is not zero.
8. Do not apply migrations to hosted Supabase or alter live rows in this workstream. Run clean/incremental local migration and pgTAP checks in CI.

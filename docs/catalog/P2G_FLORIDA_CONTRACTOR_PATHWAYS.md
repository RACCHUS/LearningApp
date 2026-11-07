# P2g — Florida Contractor Licensure Pathways (DBPR CILB CGC 5-A and CBC 5-B)

**Revision 2 source review:** 2026-11-06. **Scope:** selected individual certified-contractor qualification and licensure steps; not a complete eligibility determination.

## Certified General Contractor — CILB 5-A

Revision 2 models: four-year accredited engineering, architecture or building-construction degree plus one year of proven experience applicable to the category; one year foreman plus three years accredited college credits; one year worker, one year foreman plus two years college credits; two years worker, one year foreman plus one year college credits; four years worker/foreman including at least one year foreman; upgrade through an active current certified residential **or building** contractor license held at least four years; and three explicit military-veteran combinations. CGC applicants must document at least four experience areas and at least one year constructing structures four stories or higher.

## Certified Building Contractor — CILB 5-B

The same base degree/worker/foreman/college-credit and veteran combinations are represented, but the upgrade route is different: active current certified residential contractor license held at least three years. The 5-B form requires at least four of its six listed experience areas; it does not state the CGC four-story experience requirement.

## Shared active-status and application conditions

Both forms require electronic fingerprints. For active status, applicants submit a FICO-derived credit report. The form states that a score of at least 660 and no unsatisfied judgments or liens meets the financial-responsibility standard; if the score is below 660, the applicant must complete a Board-approved 14-hour financial responsibility course. The reviewed forms do not establish a licensing-bond alternative, so none is shown.

For active general/building contractor status, the forms state $300,000 public liability and $50,000 property damage coverage. Workers' compensation insurance or an exemption is required; the form allows an exemption within 30 days after license issuance. Inactive applicants do not complete the active-status financial and insurance sections.

The state certification examination must be passed before the initial licensure application. This pathway does not assert an exam score or three-part structure because the reviewed individual forms/checklists do not establish those details. Out-of-state certification by endorsement is outside these examination-oriented records.

## Versioning and safety

Revision 2 supersedes revision 1; revision 1 remains immutable. The manifest cites the specific 5-A or 5-B form at the relevant step and retains the DBPR application-center URL as canonical issuer URL. Fees, individual background determinations, business-entity qualification and local permitting are not fully covered. The generated SQL retires revision 1 and inserts revision 2 atomically; it is not executed against hosted Supabase in this PR.

## Validation

```bash
python3 tool/catalog_p2g_contractor_pathways.py validate
python3 -m unittest tool/tests/test_catalog_p2g_contractor_pathways.py -v
python3 tool/catalog_p2g_contractor_pathways.py render-sql
```

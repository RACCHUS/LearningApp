# P2 — Issuer-Verified Destination Directory Pilot

**Status:** P2 first implementation. **Date:** October 11, 2026.  
**Scope:** Ten authoritative issuer names and official outbound links, NOT a list of the most popular licenses.

## Why this separate directory exists

The complete CIP/SOC/O*NET taxonomy and all 31 private `catalog_intake_candidates` are already hosted. Existing `learning_targets` includes a different, heavily controlled official/community goal workflow. To avoid mislabeling a third-party certification as *issued by Learning App* or claiming that exam requirements have been verified, this pilot creates a **minimal public directory of factual issuer names and website links**.

Only the ten records listed in `data/catalog/issuer_verified_pilot_2026_10.json` are reviewed as to **issuer identity and the outbound link**. They do not imply that credential costs, application eligibility, exam editions, state laws, validity periods, learner outcomes, preparation courses or popularity rankings were verified.

## Source-reviewed initial entries

| Credential or exam | Issuer | Official source |
|---|---|---|
| AWS Certified Cloud Practitioner | Amazon Web Services | https://aws.amazon.com/certification/certified-cloud-practitioner/ |
| AWS Solutions Architect – Associate | Amazon Web Services | https://aws.amazon.com/certification/certified-solutions-architect-associate/ |
| Microsoft Azure Fundamentals | Microsoft | https://learn.microsoft.com/en-us/credentials/certifications/azure-fundamentals/ |
| Microsoft Azure Data Fundamentals | Microsoft | https://learn.microsoft.com/en-us/credentials/certifications/azure-data-fundamentals/ |
| Power BI Data Analyst Associate | Microsoft | https://learn.microsoft.com/en-us/credentials/certifications/data-analyst-associate/ |
| Project Management Professional (PMP) | PMI | https://www.pmi.org/certifications/project-management-pmp |
| Certified Associate in Project Management (CAPM) | PMI | https://www.pmi.org/certifications/certified-associate-capm |
| NCLEX-RN | NCSBN | https://www.nclex.com/test-plans.page |
| NCLEX-PN | NCSBN | https://www.nclex.com/test-plans.page |
| Florida Real Estate Sales Associate | Florida DBPR | https://www.myfloridalicense.com/intentions2.asp?boardid=25&chBoard=true&div=Real+Estate |

**Edition awareness:** PMI published a revised PMP exam in July 2026 and the NCSBN 2026 RN/PN test plans are effective April 2026–March 2029. These facts justify routine refreshes; they are **not** modeled as guaranteed learner eligibility or detailed rules in this phase.

## Technical contract

- Migration `supabase/migrations/20261012000003_catalog_reviewed_destinations.sql` adds `catalog_verified_destinations`, a slim public table with **RLS permitting select only on published records**, and service-role-only writes.
- Every public record has a matching approved and published private candidate with `source_rights='approved_for_display'`, a review timestamp, matching issuer name/type/jurisdiction and exactly the same official URL.
- Revocation or official URL change in the private candidate immediately retires the public record via a database trigger in the same transaction. This is tested by pgTAP; no periodic publication reconciliation job is relied on to remove revoked records.
- `requirements_status='not_verified'` and `popularity_status='not_measured'` are hard database constraints. Editorial display order is **not** a popularity ranking.
- `tool/catalog_verified_pilot.py validate` checks all reviewed manifest identities, HTTPS issuer-domain allowlist and claims. `render-sql` creates an idempotent *transactional admin SQL* review/approval script; this script must never be run as an anonymous client.
- Flutter taxonomy explorer has a fourth **Credentials & exams** tab and includes the approved links in its search. It deliberately does not query any private candidates, exam-question tables, demand evidence or admin source metadata.
- For portability with the current Flutter dependency graph, users can copy an official issuer URL from the listing; a direct outbound browser-opening dependency can be added in a separate review when the app's existing cross-platform URL strategy is confirmed.

## Release acceptance

1. Run all repository and Supabase disposable tests; review migration branch protections.
2. Apply additive migration to hosted **Learning App project** `xzvkdwebtbxlrxagtzlv`.
3. Promote only the ten specifically linked candidates with the reviewed script in one transaction. Verify every public row and issuer URL; remaining 21 stay pending/draft.
4. Verify `anon` has SELECT but no INSERT/UPDATE/DELETE access to public directory; has no SELECT on private intake, and has no access to source review notes beyond explicitly approved public field.
5. Verify 17 learning targets, 17 versions, 7 lessons, 13 user accounts and 831 sourced BLS observations are unchanged.

## Next phase

Expand issuer identification and exact links to other candidates after live verification, then build dated **separate** eligibility, fees, pathway and course-resource review records. Do not scrape exams or paid preparation content; use official outbound learning resources and separately licensed/original lessons. Only call something "popular" when actual exam participants, registrations or comparable measured demand exist.

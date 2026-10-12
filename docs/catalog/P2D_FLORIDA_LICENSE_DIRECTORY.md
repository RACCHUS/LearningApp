# P2d — Florida Professional License Directory Expansion

**Review date:** 2026-10-12. **Scope:** regulator identity, state jurisdiction and authoritative external links only.

## Reviewed and prepared

Six distinct Florida `professional_license` identities were checked against live state regulator websites:

| Identity | Regulator | Primary regulator source | Supporting checklist or guide |
|---|---|---|---|
| General Lines insurance agent (2-20) | Florida DFS | [DFS qualifications](https://www.myfloridacfo.com/division/agents/licensing/agents-and-adjusters/qualifications) | [2-20 resident requirements](https://myfloridacfo.com/docs-sf/insurance-agents-and-agency-services-libraries/agents-docs/licensure/agents-adjusters/2-20-resident-general-lines.pdf?sfvrsn=a4426e2d_8) |
| Health & Life (2-15) including annuities and variable contracts | Florida DFS | [DFS qualifications](https://www.myfloridacfo.com/division/agents/licensing/agents-and-adjusters/qualifications) | [2-15 resident requirements](https://www.myfloridacfo.com/docs-sf/insurance-agents-and-agency-services-libraries/agents-docs/licensure/agents-adjusters/2-15-resident-health-life-agent-license.pdf) |
| Certified General Contractor | Florida DBPR/CILB | [Contractor applications](https://www.myfloridalicense.com/intentions2.asp?boardid=06&chBoard=true&professionid=0605) | [CILB 5-A checklist](https://www.myfloridalicense.com/CheckListDetail.asp?XACT_DEFN_ID=3077&clientCode=0605&xactCode=1030) |
| Certified Building Contractor | Florida DBPR/CILB | [Contractor applications](https://www.myfloridalicense.com/intentions2.asp?boardid=06&chBoard=true&professionid=0602) | [CILB 5-B checklist](https://www.myfloridalicense.com/CheckListDetail.asp?XACT_DEFN_ID=2995&clientCode=0602&xactCode=1030) |
| Registered Nurse (RN) | Florida Board of Nursing | [Nursing licensure](https://floridasnursing.gov/nurse-rn-lpn/) | [2026 Fast-Track Guide](https://floridasnursing.gov/wp-content/uploads/2026/08/Fast-Track-Examination-Guide.pdf) |
| Licensed Practical Nurse (LPN) | Florida Board of Nursing | [Nursing licensure](https://floridasnursing.gov/nurse-rn-lpn/) | [2026 Fast-Track Guide](https://floridasnursing.gov/wp-content/uploads/2026/08/Fast-Track-Examination-Guide.pdf) |

A licensing authority issues a license. NCLEX, an insurer examination, or a contractor examination is not itself an issued state license. The Florida Board of Nursing distinguishes RN from LPN pathways, and DFS distinguishes the 2-15 and 2-20 classes.

Three entries existed already as private unreviewed records: DFS 2-20, DFS 2-15 and DBPR Certified General Contractor. Three new records are seeded: Certified Building Contractor, RN and LPN. The original 31-candidate import manifest remains unchanged.

## Data and security contract

- New manifest: `data/catalog/florida_license_p2d_2026_10.json` (6 records, 6 external resource links).
- Validator/renderer: `python3 tool/catalog_p2d_florida_licenses.py validate` and `python3 tool/catalog_p2d_florida_licenses.py render-sql`.
- Source namespaces and keys are stable; `jurisdiction = US-FL` and `destination_type = professional_license` are required.
- Issuer links and resource links are HTTPS and limited to exact reviewed state-regulator domains.
- The SQL renders a transaction, begins by asserting unchanged source identity and safe review state, performs at most three additive private intake INSERTs, reviews all six entries, inserts six public issuer-only directory records and six published resource links, and checks each result. Repeat runs are idempotent, and any mismatch aborts the full transaction.
- No new schema, migration, license award, fees, verified course prerequisite claims, popularity scores, user goals, lessons or paid content are introduced.
- Database RLS continues protecting private intake and owner-only goal associations. Public reads remain limited to published entries.
- All source checks are dated. A linked regulator PDF may be replaced, so sources need periodic refresh.

## Execution and validation

1. Run the P2d Python validator and unit tests through Flutter CI.
2. Review rendered SQL before executing against hosted Supabase project `xzvkdwebtbxlrxagtzlv`. Avoid duplicate application if a parallel catalog deployment has changed the six candidate identities.
3. Before and after, record `catalog_intake_candidates`, `catalog_verified_destinations`, `catalog_destination_resources`, `learning_targets`, `lessons`, `catalog_official_demand_observations` and `auth.users` counts.
4. Expected *if applied to the P2c baseline*: 34 private candidates, 16 published destinations, 15 public external resources. Original 17 learning targets, 7 lessons, 831 BLS observations and 13 auth users remain unchanged.
5. Verify 6 rows are published, source/issuer/license class/jurisdiction exact, resources retrievable under RLS, and unrelated private candidate records remain invisible.
6. Separately test learner login: create a source-linked Florida license goal, inspect owner-only source panel, and confirm a different session cannot see another learner's association.
7. Hosted PWA deployment remains a separate host-level verification, not implied by GitHub build success.

## Future pathway work

The existing public directory deliberately hard-codes `requirements_status=not_verified`. Before publishing separately verified legal conditions, build a versioned requirements/pathway model that supports alternate prerequisites (AND/OR), effective dates, evidence links, supersession, legal exceptions, and state/issuer separation. Add official exam outlines and independently authored lessons separately, without copying proprietary questions or treating course completion as automatic licensure. Maintain backup and rollback readiness before substantial live-data growth.

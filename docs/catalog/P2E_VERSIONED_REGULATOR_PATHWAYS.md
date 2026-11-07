# P2e — Versioned Florida nursing regulator pathways

**Revision 2 source review:** 2026-11-06. **Scope:** selected initial Florida RN and LPN routes, not a complete legal eligibility determination.

Each existing destination now has three alternative initial Florida licensure routes: examination for applicants who have not passed NCLEX; application after an applicant has already passed NCLEX, with verification rather than a repeat exam; and MOBILE endorsement for qualifying applicants with an active unencumbered out-of-state license. The RN tree retains the pre-licensure MSN/higher education alternative only for RN applicants. The LPN tree retains Practical Nursing Equivalency only for eligible applicants already enrolled in an RN program. MOBILE conditions include national exam/certification, two years of active practice in the prior four years, NPDB and disciplinary-history restrictions, license verification, application and fingerprints.

Re-examination and multistate upgrade remain outside this selected pathway. The issuer directory's comprehensive requirements status remains unchanged.

## Versioning and safety

- Revision 1 remains immutable and is retired only by the generated revision-2 promotion transaction.
- Revision 2 records `supersedes_revision=1`, retrieval timestamp, review note, uncertainty state and `pathway_kind=initial_licensure`.
- `route_kind=other` is used because each single destination record groups multiple initial-licensure routes; the tree keeps each route separate.
- All steps link to the Florida Board of Nursing: https://floridasnursing.gov/nurse-rn-lpn/
- No individual eligibility determination or license issuance is represented.

## Validation

```bash
python3 tool/catalog_p2e_pathways.py validate
python3 -m unittest tool/tests/test_catalog_p2e_pathways.py -v
python3 tool/catalog_p2e_pathways.py render-sql
```

The renderer retires revision 1 and inserts revision 2 atomically. It is an administrator-only artifact and is not executed against hosted Supabase in this PR.

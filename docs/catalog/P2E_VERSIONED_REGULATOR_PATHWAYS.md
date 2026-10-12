# P2e — Versioned regulator-sourced licensing pathways (pilot)

**Source review:** 2026-10-12. **Scope:** selected examination-route steps for Florida RN and LPN, **not** an exhaustive legal eligibility determination.

## Product distinctions

1. A **Florida professional license** is state-issued permission to practice; a licensure **exam**, schooling, training course or Learning App goal is not itself a license.
2. The verified issuer directory still records `requirements_status='not_verified'`, correctly indicating that **complete** prerequisites, alternative waivers, fees and personalized licensing determinations have not been audited.
3. A P2e pathway adds only **selected factual steps directly supported by a dated regulator source**, with nested all-of/any-of groups, conditional wording and source links.
4. None of these records automatically grant an award, recommend a paid school, mirror third-party courses, establish exam popularity, or guarantee eligibility.

## Source

[Florida Board of Nursing — RN & LPN examination application and licensing guidance](https://floridasnursing.gov/nurse-rn-lpn/), reviewed 2026-10-12. The official Board page describes alternative qualifying education pathways, RN-specific pre-licensure graduate education, LPN Practical Nursing Equivalency (PNEQ) with additional proof, Level 2 fingerprints, application, NCLEX authorization/testing, and eventual license issuance as distinct stages.

The official page includes other conditions and separate paths such as examination-already-passed or endorsement. Those are **not exhaustively represented** in this first pilot. Applicants with nonstandard education, criminal/disciplinary records, prior licensure, or other exceptions must consult the Board directly.

## Technical implementation

- Additive migration: `supabase/migrations/20261012000006_catalog_license_pathway_versions.sql`.
- New source-linked `public.catalog_license_pathway_versions` with append-only revision identity, reviewed source timestamp, review stage, effective-date envelope, optional superseded revision, and an `all` / `any` / `step` JSON expression tree. `coverage` is fixed to `selected_steps_only`.
- A reviewed `step` has exact `label`, `stage`, `source_url`, and optional `condition`, not user-generated eligibility inference.
- Database guard blocks publication until exact regulator jurisdiction/type matches, parent issuer destination is currently published, review metadata exists and is current (180-day maximum), and the evidence tree passes the schema validator.
- RLS exposes only approved, published, unexpired/current source-reviewed pathways with a still-published `professional_license` parent. No client writes. The table has no public client access to pending drafts.
- Once published, only retirement is permitted, **never in-place content editing**; superseding content requires a new revision. Revoking an issuer destination retires its published pathways in the same transaction. A stale checked-source timestamp hides a pathway from anonymous and signed-in users.
- Existing `learning_targets`, `lessons`, course and account tables are untouched. No full licensing requirements flag or license issuance state is created.
- Flutter `verified_destinations_provider.dart` adds typed reviewed-pathway reads; the Credentials & exams directory offers a **Regulator steps** sheet for professional licenses, with source-review date, nested alternatives/conditions, and links to the official page. For other licenses it states that no reviewed pathway exists yet.

## Reviewed first records

`data/catalog/florida_nursing_p2e_pathways_2026_10.json` contains two source-linked partial pathways for Florida RN and Florida LPN, revision 1. The education choices are nested under `any`, and applicable application, background-screening, NCLEX and licensure steps under `all`, with additional conditional notes. Both records cite the Board URL at each fact.

`tool/catalog_p2e_pathways.py validate` checks schema, fixed identities, exact regulator URL, jurisdiction, no complete-eligibility claims, AND/OR and conditions, and absence of missing citation URLs. `render-sql` emits trusted-admin-only, transactional, guarded, idempotent SQL. It must not be called by anonymous or learner clients.

## Release gates

1. Validate manifest and unit tests: `python3 tool/catalog_p2e_pathways.py validate`; `python3 -m unittest discover -s tool/tests -p 'test_catalog_p2e_pathways.py' -v`.
2. Verify clean and incremental database migrations including pgTAP test `catalog_license_pathway_versions_test.sql`.
3. Verify Flutter analysis, tests and web release build in CI.
4. Confirm existing records in project `xzvkdwebtbxlrxagtzlv` and take appropriate backup before materially growing personal data. Apply only the additive migration. Verify public/anon RLS and `service_role` allowed.
5. Review rendered P2e pathway publication SQL before applying. Confirm exactly **2** public partial pathways, one RN and one LPN; existing 34 intake candidates, 16 public issuer destinations, 15 public resource links, 17 goals, 7 lessons, 831 BLS observations, 13 users unchanged.
6. Browser smoke test: credentials directory renders selected alternatives for RN/LPN only; other licenses show no reviewed pathway. Anonymous and owner/nonowner view access tested, including source revocation and date staleness. Hosted build parity separately tracked by GitHub issue #39.

## Next work

- Capture additional DFS 2-20 and 2-15 education and experience alternatives directly from current detailed DFS requirements and legal citations, not a generic 200-hour course mandate.
- Model contractor classifications and CILB 5-A/5-B alternative experience/college/endorsement branches, not a conflated construction license.
- Support distinct nursing endorsement, previous NCLEX passes, renewals, exemptions and conditional background review with more specialized editorial review.
- Add first-party or permissioned creator course preparation content as separate pathways, never as an automatic substitute for statutory qualification.
- Build a reviewer-facing promotion and supersession workflow with a real reviewer identity and audit log before declaring **complete** eligibility guidance.


## Source-availability safeguard for taxonomy CI

The historical BLS 2010→2018 SOC crosswalk is a federally published public-domain resource. The original Internet Archive retrieval path intermittently returned HTTP 500/503 in GitHub Actions. An **immutable** public GitHub mirror is now available at [theis188/us-jobs-data commit c8d6ade](https://github.com/theis188/us-jobs-data/blob/c8d6ade6f007f5b3d546d6b4857b160fdd0405ce/soc_2010_to_2018_crosswalk.xlsx). The file was independently compared byte-for-byte via pinned SHA-256: `f3a847561562d3e5a30eb848f2902a5f7b02e9c48b3d7f2cc8879899fbc242a7`, exactly 46,630 bytes, matching the previously approved BLS release.

The taxonomy ingestor always prefers the original retrieval URL and only tries the pinned fallback on network/download failure. It cryptographically validates **before writing** either result to disk; a successful-but-mismatched primary file fails closed instead of quietly using the mirror. The effective retrieval URL is recorded in a sidecar and carried into import artifact provenance, while the original BLS publisher URL remains canonical. GitHub Actions caches only successful validated bundles keyed by the source-spec code hash. The taxonomy content, source edition and downstream import counts remain unchanged.

Issue #43 documents the incident and long-term reliability rationale; the fallback test preserves checksum and exact immutable commit URL. A production/hosted re-import of the federal taxonomy is **not** required for this change.

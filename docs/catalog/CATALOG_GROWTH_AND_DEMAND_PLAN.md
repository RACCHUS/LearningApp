# Learning App — Catalog Growth and Demand Roadmap

**Active catalog plan** — replaces the Phase H taxonomy population roadmap.  
**Date:** October 11, 2026. **Owner:** Catalog, credentialing and curriculum.

## 1. Close the completed taxonomy phase

Hosted Supabase has been verified to contain the complete pinned official classification releases:

| Existing reference graph | Verified rows |
|---|---:|
| NCES CIP 2020 nodes | 2,809 |
| BLS SOC 2018 nodes | 1,447 |
| O*NET 31.0 occupation extensions | 1,016 |
| NCES CIP–SOC mappings | 5,723 |
| CIP/SOC historical lineage | 2,699 / 900 |
| Tracked source artifacts with hashes | 8 |

The classification-import work is **done**, but it is not a license, certification, provider program or course catalog. The old roadmap is now historical; its outstanding catalog-growth requirements move here. The existing 17 learning targets, 17 published versions, 7 lessons and user accounts must be preserved.

### Internal field hierarchy (deployed, October 2026)

Importing CIP nodes did **not** initially create the matching internal subject hierarchy. Migration `20261015000000_cip_internal_field_bootstrap.sql` adds the service-role `bootstrap_cip_internal_fields('2020')` backfill (466 subfields + 2,295 program fields, reusing the 48 curated broad-field IDs and cluster memberships) and the read-only `taxonomy_internal_coverage()` report. It was deployed on 2026-10-15; strict hosted verification reports 48/48 series, 466/466 groups and 2,295/2,295 programs, with all hierarchy checks at zero. The explorer's **Disciplines** tab loads each level lazily by parent. The full deployment and backup exception are documented in the [controlled import runbook](../taxonomy/CONTROLLED_PRODUCTION_TAXONOMY_IMPORT.md#deployment-record-2026-10-15). A complete CIP-backed hierarchy is still not native-field, concept, K–12 or curriculum coverage.

### LearningApp-native literacy and life-skills fields (deployed, October 2026)

Migration `20261015010000_native_literacy_life_skills_fields.sql` adds a distinct, LearningApp-authored tree grounded in current app surfaces: **Foundational Literacy** (phonics/decoding, supported reading, oral language and adult basic-education reading), **Civic and Community Literacy** (civics/naturalization and driver readiness), and **Practical Life Skills** (cash/ATM, health/first aid, food safety and workplace safety). It restores the `cluster_life_milestones` database row that previously existed only in the Flutter fallback and connects the three roots to that catalog cluster. The taxonomy service's offline fallback exposes the same roots and children.

This is a product-navigation ontology, not an external classification, K–12 standard, credential, legal/medical requirement, or claim that its practice screens constitute formal instruction. It creates no courses, tests, credential requirements, standards, or new concept placements. The six shipped sample programming concepts are linked through `concept_fields` to their already-assigned field only. The migration was deployed on 2026-10-15. Hosted verification confirms 13 active native fields, and all three roots are linked to the restored life-milestones cluster. The owner proceeded without an off-site backup; this exception is recorded in the [production import runbook](../taxonomy/CONTROLLED_PRODUCTION_TAXONOMY_IMPORT.md#deployment-record-2026-10-15).

## 2. Product outcome

People find a real learning destination: a professional license, certification, licensure or standardized exam, degree/program field, creator-created course, or personally defined goal. They can compare issuers, jurisdictions, verified requirements, paths and reputable preparation options.

Always distinguish **occupation**, **academic classification**, **institutional offering**, **credential**, **exam**, **license**, **study course**, and **personal goal**. Do not turn CIP–SOC correlations into invented legal prerequisites. A learning course is not a credential merely because it prepares a learner for one.

## 3. P0 — Build a safe intake and demand foundation (in progress)

- Private Supabase tables catalog_intake_candidates and catalog_intake_demand_signals. RLS blocks anon and authenticated users; trusted administrative workflows only.
- Durable identity by source namespace and source key; include type, issuer, source URL, jurisdiction, version and review state. No deduplication solely by title.
- Source metadata-only candidate state is **pending + draft** by default, not platform-official. Publishing requires explicit approval, verified timestamp and rights approval.
- Initial 31 candidates from issuer or official category directories across CompTIA, AWS, Microsoft, PMI, NCLEX, Florida DBPR/DFS licensing, SAT/GED/GRE/ACT/ASVAB and NCES CIP program categories.
- Importer must not reset, delete, replace previously approved reviews or publish any record. It should fail closed on wrong project or unsupported credential type.
- Measured popularity requires real evidence from multiple independent signal categories; no data = **unranked**, never zero demand. Separately distinguish editorial shortlist order.

**P0 exit:** feature-branch CI, clean/incremental Supabase migration tests, private review queue verified on hosted, no user-content changes. This creates staged candidates, not 31 public qualifications.

## 4. P1 — Obtain and import comparable popularity signals

**IPEDS completions:** prioritize the current 2025 C2025_A release, which measures awards by six-digit CIP and degree/certificate award level during July 2024–June 2025. Parse the official data dictionary, ignore suppressed/missing figures, retain CIP edition, institution UNITID, geography, award level and release. Do not equate completions with enrollments or available course seats.

**BLS employment projections:** use the currently listed 2025–2035 Occupational Projections dataset (not stale 2024–2034 tables), with SOC-based annual openings, employment and publication period. Recheck the BLS release when imported; pin and record its exact download version. SOC opportunities do not establish a required credential. Store the original source and observation period.

**O*NET labor signals:** job posting and technical-skill demand only where reuse rights permit, distinguished from the existing occupational classification graph.

**Issuer evidence:** exam participation counts or credentials awarded only when the issuing body publishes an auditable number and reuse is permitted. **Search/community signals** become meaningful after launch; never substitute manually assigned popularity scores for observations.

**Provisional ranking algorithm:**
- Employment/labor demand 35%, educational completions or exam participation 25%, search trends 20%, community searches/saves 20%.
- Compare metrics only to observations with the same metric, geography and period, normalize within cohorts.
- Require at least two source categories and at least two comparable observations per cohort before ranking; display weighting coverage and source dates.
- Missing evidence is not zero and not proof of low demand. Add confidence and recency controls before deploying public recommendations.

**P1 exit:** pinned, reproducible IPEDS and BLS adapters and evidence rows with national aggregates plus clear source, unit and time window, not hypothetical rankings.

### P1 implementation evidence (2026-10-11)

The first official numerical source was independently read on an ephemeral GitHub runner: BLS Table 1.2, Employment Projections 2025–2035, with **831 detailed SOC line-item rows** and pinned source hash. The private schema and guarded uploader are in [P1 Official Demand Runbook](P1_OFFICIAL_DEMAND_RUNBOOK.md). These are occupation-opening estimates *in thousands*, not individual certification popularity, and no source-driven license ranking is published.

NCES lists the 2025 provisional C2025_A release, but the historical guessed direct ZIP link returned HTTP 404. The parser is implemented against the documented C2025_A data fields, but **no real IPEDS award counts have been imported** until the authentic current download and dictionary can be verified.

**Remaining:** independent hosted BLS import verification; acquisition of current official NCES ZIP; issuer-specific participation data or user usage for actual certification/license/course popularity.

## 5. P2 — Real credential, license and provider records

- **National issuer pilot:** verify each current certification, exam ID, syllabus edition, renewal, issuing body and fees on current issuer pages (CompTIA, AWS, Microsoft, PMI, NCSBN). Avoid copyrighted real exam questions.
- **Florida professional licensing pilot:** DBPR, DFS and Nursing Board; regulator is legal authority, CareerOneStop is a discovery aid. Capture current license class, regulator, statute/rule link, application conditions, fees and effective dates; model alternative paths as explicit AND/OR conditions.
- **CareerOneStop API:** request a developer token, approve agreement and rights before caching data; coverage varies by jurisdiction.
- **Credential Engine:** approved organization and API/developer agreement required for search; bulk/offline downloading requires explicit permission and regular refresh.
- **IPEDS/College Scorecard:** use stable school and CIP identifiers, distinguishing a field of study from an actual institution offering and class availability.
- **Course provider metadata:** link out to reputable external offerings where permitted. We produce our own lessons or accept authorized creator contributions; do not mirror paid courses or real proprietary test questions.

**P2 targets:** 250 individually reviewed destination pages, 50 validated pathways. These are future product milestones, not current live records.

### P2 first issuer-link pilot (October 2026)

The first P2 slice adds a narrow **issuer identity + official outbound URL** review for ten destinations: two AWS certifications, three Microsoft certifications, PMI PMP/CAPM, NCSBN NCLEX-RN/PN, and Florida real estate sales associate licensing. The public directory is separate from the `learning_targets` goal catalog, and is surfaced in the taxonomy explorer under **Credentials & exams**, including global search matches. This is a first verified directory, **not** a published course, learner pathway, comprehensive licensing requirements record, or measured popularity ranking.

The remaining 21 intake entries stay unpublished. Hard database gates require verified reviewer state; public records are immediately retired on source revocation. See [P2 reviewed issuer directory runbook](P2_ISSUER_VERIFIED_DIRECTORY.md). Next work is individual legal/exam requirement provenance, service/provider APIs under terms, real learning-target mappings, and original study content.

### P2 status reconciliation (2026-10-15, read-only hosted check)

The pilot has grown beyond the original ten records. Anonymous readers currently see **16 published destinations**: 7 certifications (AWS ×2, Microsoft ×3, PMI PMP/CAPM), 2 licensure exams (NCLEX-RN/PN) and 7 Florida professional licenses (real estate sales associate, RN, LPN, 2-20 general lines and 2-15 life/health/annuity insurance agents, certified general and certified building contractors). Only **2 versioned regulator pathways** are publicly visible (Florida RN and LPN examination-path steps). The P2f insurance and P2g contractor pathway work is in the repository but its pathways are not publicly visible on hosted; confirm deployment and review state before describing them as live. Progress against the P2 targets: 16 of 250 reviewed destination pages, 2 of 50 validated pathways.

## 6. P3 — Experience, community and content

- Search/filter by destination type, issuer, subject, jurisdiction, approval status and freshness. Unreviewed intake must not appear in public search.
- Each destination page has issuer/regulator, version, official link, last checked, known/unknown eligibility, legal qualifiers, linked program/career, and trusted preparation options.
- Community goals remain distinguishable from official records, with anti-spam moderation and promotion workflow.
- Capture aggregate saved-goal counts, searches, quality ratings and completed courses without exposing individuals or letting automated popularity overrides manipulate licensing rules.
- Build 20 original, quality-reviewed study tracks first, with creator marketplace content clearly separated from issuer awards.

## 7. Source acquisition gates

| Feed | Role | Requirement before broad import |
|---|---|---|
| NCES CIP, BLS SOC, O*NET 31.0 | Existing national classification graph | Already hosted; honor O*NET attribution and version releases |
| NCES IPEDS C2025_A | Popular degrees and certificate fields | Verify source dictionary, release and aggregation rights |
| BLS Employment Projections | Labor opportunity ranking | Match SOC and projection window, use actual statistics |
| CareerOneStop | State license discovery and training | Authenticated API, terms, state board verification |
| Credential Engine | Publisher credentials, courses, pathways | Approved organization, agreement, offline bulk approval |
| Individual issuers/regulators | Credential and license truth | Per-provider terms and human review |
| College Scorecard | Actual schools/program outcomes | Key/terms, separate from class catalog |
| 1EdTech CASE, UNESCO/ESCO | Standards/international | Per-issuer rights, jurisdiction and namespace |

Maintain source identity, license status, checksum where available, release date, publisher, API conditions, verified-by and review date. No blanket source-rights auto-approval.

## 8. Operational safeguards

- P0 imports only to private candidate tables, never to learning_targets, target_versions, courses, lessons, user records or paid products.
- Additive SQL migrations only. No production database reset or direct user permission changes.
- Modern Supabase sb_secret key only in backend Actions environments; no key in app or repository.
- Migration CI covers clean/incremental upgrade and pgTAP; source data/test validation is mandatory. Confirm live row counts after a deployment.
- Keep a recoverable backup per the Windows SSD/off-site backup guide before materially expanding live user data.
- If an unapproved record is loaded, correct it in private review; do not publish speculatively.

## 9. Delivery milestones

- [x] National CIP, SOC, O*NET and crosswalk graph imported to production.
- [x] Internal CIP 2020 field hierarchy (466 subfields, 2,295 program fields): bootstrap, coverage report and lazy browsing in repository; deployed and strictly verified hosted on 2026-10-15.
- [x] LearningApp-native literacy/life-skills field tree and life-milestones cluster: additive migration, offline fallback, UI, pgTAP and Flutter tests complete; deployed and verified hosted on 2026-10-15.
- [x] Taxonomy roadmap superseded by the catalog/demand roadmap.
- [x] Private candidate schema and strict reviewer/publication gates created in repository.
- [x] Initial 31-item evidence-linked candidate review seed (not popularity-ranked).
- [x] Validation, import, and measured-only ranking tooling with no fabricated scores.
- [ ] CI green, deploy P0 migration, import pending candidate records and verify public isolation.
- [ ] P1: source-verified IPEDS and BLS numerical evidence ingestion.
- [ ] P2: issuer/regulator reviews, promotions to target pages and verified pathways.
- [ ] P3: discovery UI, learner feedback and original study tracks.

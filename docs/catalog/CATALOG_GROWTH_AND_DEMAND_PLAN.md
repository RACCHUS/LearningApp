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

**BLS employment projections:** version a public-use Employment Projections dataset with SOC-based annual openings, employment and time period. SOC opportunities do not establish a required credential. Store the original source and observation period.

**O*NET labor signals:** job posting and technical-skill demand only where reuse rights permit, distinguished from the existing occupational classification graph.

**Issuer evidence:** exam participation counts or credentials awarded only when the issuing body publishes an auditable number and reuse is permitted. **Search/community signals** become meaningful after launch; never substitute manually assigned popularity scores for observations.

**Provisional ranking algorithm:**
- Employment/labor demand 35%, educational completions or exam participation 25%, search trends 20%, community searches/saves 20%.
- Compare metrics only to observations with the same metric, geography and period, normalize within cohorts.
- Require at least two source categories and at least two comparable observations per cohort before ranking; display weighting coverage and source dates.
- Missing evidence is not zero and not proof of low demand. Add confidence and recency controls before deploying public recommendations.

**P1 exit:** pinned, reproducible IPEDS and BLS adapters and evidence rows with national aggregates plus clear source, unit and time window, not hypothetical rankings.

## 5. P2 — Real credential, license and provider records

- **National issuer pilot:** verify each current certification, exam ID, syllabus edition, renewal, issuing body and fees on current issuer pages (CompTIA, AWS, Microsoft, PMI, NCSBN). Avoid copyrighted real exam questions.
- **Florida professional licensing pilot:** DBPR, DFS and Nursing Board; regulator is legal authority, CareerOneStop is a discovery aid. Capture current license class, regulator, statute/rule link, application conditions, fees and effective dates; model alternative paths as explicit AND/OR conditions.
- **CareerOneStop API:** request a developer token, approve agreement and rights before caching data; coverage varies by jurisdiction.
- **Credential Engine:** approved organization and API/developer agreement required for search; bulk/offline downloading requires explicit permission and regular refresh.
- **IPEDS/College Scorecard:** use stable school and CIP identifiers, distinguishing a field of study from an actual institution offering and class availability.
- **Course provider metadata:** link out to reputable external offerings where permitted. We produce our own lessons or accept authorized creator contributions; do not mirror paid courses or real proprietary test questions.

**P2 targets:** 250 individually reviewed destination pages, 50 validated pathways. These are future product milestones, not current live records.

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
- [x] Taxonomy roadmap superseded by the catalog/demand roadmap.
- [x] Private candidate schema and strict reviewer/publication gates created in repository.
- [x] Initial 31-item evidence-linked candidate review seed (not popularity-ranked).
- [x] Validation, import, and measured-only ranking tooling with no fabricated scores.
- [ ] CI green, deploy P0 migration, import pending candidate records and verify public isolation.
- [ ] P1: source-verified IPEDS and BLS numerical evidence ingestion.
- [ ] P2: issuer/regulator reviews, promotions to target pages and verified pathways.
- [ ] P3: discovery UI, learner feedback and original study tracks.
